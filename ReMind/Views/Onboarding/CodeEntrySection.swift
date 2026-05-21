import SwiftUI
import UIKit

struct CodeEntrySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var code: String
    let phoneNumber: String
    let onEditNumber: () -> Void
    let onResend: () -> Void

    var showTopBar: Bool = true
    var isInputActive: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            if showTopBar {
                topBar
            }

            VStack(alignment: .center, spacing: 10) {
                Text("Enter verification code")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                (Text("We sent a 6-digit code to ") +
                 Text(phoneNumber).foregroundColor(.figmaBlue))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            }

            codeBoxes

            Button("Resend code", action: onResend)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.figmaBlue)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(0.9)
                .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 44 : 32)
        }
        .padding(.top, showTopBar ? 4 : 0)
        .brainMailDynamicTypeRange()
    }

    private var topBar: some View {
        HStack {
            Button(action: onEditNumber) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(8)
            }
            Spacer()
        }
    }

    private var codeBoxes: some View {
        OneTimeCodeInputView(
            code: $code,
            isActive: isInputActive,
            usesAccessibilityLayout: dynamicTypeSize.brainMailUsesAccessibilityLayout
        )
        .frame(height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 74 : 64)
        .contentShape(Rectangle())
    }

}

private struct OneTimeCodeInputView: UIViewRepresentable {
    @Binding var code: String
    let isActive: Bool
    let usesAccessibilityLayout: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code)
    }

    func makeUIView(context: Context) -> OTPCodeInputUIView {
        let inputView = OTPCodeInputUIView()
        inputView.delegate = context.coordinator
        inputView.configure(usesAccessibilityLayout: usesAccessibilityLayout)
        inputView.applyExternalCode(code)
        inputView.setActive(isActive, reason: "makeUIView")
        context.coordinator.inputView = inputView
        return inputView
    }

    func updateUIView(_ inputView: OTPCodeInputUIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.inputView = inputView
        inputView.delegate = coordinator
        inputView.configure(usesAccessibilityLayout: usesAccessibilityLayout)
        inputView.applyExternalCode(code)
        inputView.setActive(isActive, reason: "updateUIView")
        if isActive {
            inputView.scheduleFocusIfNeeded(reason: "updateUIView")
        }
    }

    static func dismantleUIView(_ uiView: OTPCodeInputUIView, coordinator: Coordinator) {
        uiView.prepareForDismantle()
        uiView.delegate = nil
        coordinator.inputView = nil
    }

    final class Coordinator: NSObject, OTPCodeInputUIViewDelegate {
        @Binding private var code: String
        weak var inputView: OTPCodeInputUIView?

        init(code: Binding<String>) {
            _code = code
        }

        func otpCodeInputView(_ inputView: OTPCodeInputUIView, didUpdateCode newCode: String, source: String) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.code != newCode else {
                    return
                }

                #if DEBUG
                print("[OTP] binding update source=\(source) length=\(newCode.count)")
                #endif
                self.code = newCode
            }
        }
    }
}

private protocol OTPCodeInputUIViewDelegate: AnyObject {
    func otpCodeInputView(_ inputView: OTPCodeInputUIView, didUpdateCode newCode: String, source: String)
}

private final class OTPCodeInputUIView: UIView, UITextFieldDelegate {
    weak var delegate: OTPCodeInputUIViewDelegate?

    private let textField = UITextField()
    private let stackView = UIStackView()
    private let boxViews: [OTPDigitBoxView] = (0..<6).map { _ in OTPDigitBoxView() }
    private var usesAccessibilityLayout = false
    private var isActive = false
    private var isFocusScheduled = false
    private var isApplyingProgrammaticText = false

    private static let figmaBlue = UIColor(red: 59 / 255, green: 70 / 255, blue: 173 / 255, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        logLifecycle("created")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        logLifecycle("created from coder")
    }

    deinit {
        logLifecycle("deinit")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        #if DEBUG
        print("[OTP] didMoveToWindow view=\(debugID) textField=\(textFieldDebugID) window=\(window != nil) isFirstResponder=\(textField.isFirstResponder) frame=\(textField.frame)")
        #endif

        if window != nil {
            scheduleFocusIfNeeded(reason: "didMoveToWindow")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        textField.frame = bounds

        let metrics = codeBoxMetrics(for: bounds.width)
        stackView.spacing = metrics.spacing
        stackView.frame = CGRect(
            x: max(0, (bounds.width - metrics.totalWidth) / 2),
            y: max(0, (bounds.height - metrics.height) / 2),
            width: metrics.totalWidth,
            height: metrics.height
        )

        boxViews.forEach { boxView in
            boxView.layer.cornerRadius = 12
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else {
            return nil
        }
        return textField
    }

    func configure(usesAccessibilityLayout: Bool) {
        self.usesAccessibilityLayout = usesAccessibilityLayout
        textField.font = UIFontMetrics(forTextStyle: .title3).scaledFont(
            for: UIFont.monospacedDigitSystemFont(
                ofSize: usesAccessibilityLayout ? 23 : 22,
                weight: .semibold
            )
        )
        textField.adjustsFontForContentSizeCategory = true
        boxViews.forEach { $0.configureTypography(usesAccessibilityLayout: usesAccessibilityLayout) }
        setNeedsLayout()
        refreshBoxes()
    }

    func applyExternalCode(_ code: String) {
        let sanitized = sanitizedCode(from: code)
        guard textField.text != sanitized else {
            refreshBoxes()
            return
        }

        isApplyingProgrammaticText = true
        textField.text = sanitized
        moveCaretToEnd()
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingProgrammaticText = false
        }
        refreshBoxes()
    }

    func setActive(_ active: Bool, reason: String) {
        guard isActive != active else {
            return
        }

        isActive = active

        if active {
            scheduleFocusIfNeeded(reason: reason)
        } else {
            resignCodeFirstResponder(reason: reason)
        }
    }

    func scheduleFocusIfNeeded(reason: String) {
        guard isActive else {
            #if DEBUG
            print("[OTP] focus schedule skipped reason=\(reason) active=false view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return
        }

        guard window != nil else {
            #if DEBUG
            print("[OTP] focus schedule skipped reason=\(reason) window=false view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return
        }

        guard !textField.isFirstResponder else {
            #if DEBUG
            print("[OTP] focus schedule skipped reason=\(reason) alreadyFirstResponder=true view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return
        }

        guard !isFocusScheduled else {
            #if DEBUG
            print("[OTP] focus schedule skipped reason=\(reason) pending=true view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return
        }

        isFocusScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isFocusScheduled = false
            guard self.isActive else {
                #if DEBUG
                print("[OTP] becomeFirstResponder skipped reason=\(reason) active=false view=\(self.debugID) textField=\(self.textFieldDebugID)")
                #endif
                return
            }
            self.focusIfNeeded(reason: reason)
        }
    }

    @discardableResult
    private func focusIfNeeded(reason: String) -> Bool {
        guard window != nil else {
            #if DEBUG
            print("[OTP] becomeFirstResponder skipped reason=\(reason) window=false view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return false
        }

        if textField.isFirstResponder {
            #if DEBUG
            print("[OTP] becomeFirstResponder skipped reason=\(reason) alreadyFirstResponder=true view=\(debugID) textField=\(textFieldDebugID)")
            #endif
            return true
        }

        let result = textField.becomeFirstResponder()
        #if DEBUG
        print("[OTP] becomeFirstResponder reason=\(reason) result=\(result) isFirstResponder=\(textField.isFirstResponder) view=\(debugID) textField=\(textFieldDebugID) frame=\(textField.frame)")
        #endif
        return result
    }

    @discardableResult
    func resignCodeFirstResponder(reason: String) -> Bool {
        let wasFirstResponder = textField.isFirstResponder
        let result = textField.resignFirstResponder()
        #if DEBUG
        print("[OTP] resignFirstResponder reason=\(reason) result=\(result) wasFirstResponder=\(wasFirstResponder) isFirstResponder=\(textField.isFirstResponder) view=\(debugID) textField=\(textFieldDebugID)")
        #endif
        return result
    }

    func prepareForDismantle() {
        isActive = false
        isFocusScheduled = false
        isApplyingProgrammaticText = false
        resignCodeFirstResponder(reason: "dismantle")
        textField.delegate = nil
        textField.removeTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
    }

    private func setup() {
        isUserInteractionEnabled = true
        backgroundColor = .clear
        accessibilityLabel = "Verification code"

        textField.delegate = self
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartInsertDeleteType = .no
        textField.isEnabled = true
        textField.isUserInteractionEnabled = true
        textField.isHidden = false
        textField.alpha = 1
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .never
        textField.accessibilityLabel = "Verification code"
        textField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
        addSubview(textField)

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.isUserInteractionEnabled = false
        stackView.accessibilityElementsHidden = true
        addSubview(stackView)

        boxViews.forEach { boxView in
            boxView.isUserInteractionEnabled = false
            boxView.accessibilityElementsHidden = true
            stackView.addArrangedSubview(boxView)
        }
    }

    @objc private func editingChanged(_ textField: UITextField) {
        #if DEBUG
        print("[OTP] editingChanged isFirstResponder=\(textField.isFirstResponder) rawLength=\((textField.text ?? "").count) view=\(debugID) textField=\(textFieldDebugID) programmatic=\(isApplyingProgrammaticText)")
        #endif
        guard !isApplyingProgrammaticText else {
            return
        }
        updateCodeFromTextField(source: "editingChanged")
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        #if DEBUG
        print("[OTP] textFieldDidBeginEditing isFirstResponder=\(textField.isFirstResponder) view=\(debugID) textField=\(textFieldDebugID)")
        #endif
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        #if DEBUG
        print("[OTP] textFieldDidEndEditing active=\(isActive) window=\(window != nil) view=\(debugID) textField=\(textFieldDebugID)")
        #endif

        if isActive && window != nil {
            scheduleFocusIfNeeded(reason: "didEndEditing")
        }
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        #if DEBUG
        print("[OTP] textFieldDidChangeSelection isFirstResponder=\(textField.isFirstResponder) rawLength=\((textField.text ?? "").count) view=\(debugID) textField=\(textFieldDebugID) programmatic=\(isApplyingProgrammaticText)")
        #endif
        guard !isApplyingProgrammaticText else {
            return
        }
        updateCodeFromTextField(source: "selection")
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        true
    }

    private func updateCodeFromTextField(source: String) {
        let sanitized = sanitizedCode(from: textField.text ?? "")

        if textField.text != sanitized {
            isApplyingProgrammaticText = true
            textField.text = sanitized
            moveCaretToEnd()
            isApplyingProgrammaticText = false
        }

        refreshBoxes()
        delegate?.otpCodeInputView(self, didUpdateCode: sanitized, source: source)
    }

    private func refreshBoxes() {
        let digits = Array(sanitizedCode(from: textField.text ?? ""))

        for index in 0..<boxViews.count {
            boxViews[index].configure(
                digit: index < digits.count ? String(digits[index]) : "",
                isActive: index == digits.count && digits.count < boxViews.count,
                isFilled: index < digits.count,
                figmaBlue: Self.figmaBlue
            )
        }
    }

    private func sanitizedCode(from text: String) -> String {
        String(text.filter(\.isNumber).prefix(6))
    }

    private func moveCaretToEnd() {
        guard let end = textField.position(from: textField.beginningOfDocument, offset: textField.text?.count ?? 0) else {
            return
        }
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }

    private var debugID: String {
        String(describing: ObjectIdentifier(self))
    }

    private var textFieldDebugID: String {
        String(describing: ObjectIdentifier(textField))
    }

    private func logLifecycle(_ event: String) {
        #if DEBUG
        print("[OTP] UITextField lifecycle event=\(event) view=\(debugID) textField=\(textFieldDebugID) window=\(window != nil) isFirstResponder=\(textField.isFirstResponder) frame=\(textField.frame)")
        #endif
    }

    private func codeBoxMetrics(for availableWidth: CGFloat) -> (height: CGFloat, spacing: CGFloat, totalWidth: CGFloat) {
        let minimumWidth: CGFloat = usesAccessibilityLayout ? 30 : 34
        let maximumWidth: CGFloat = usesAccessibilityLayout ? 44 : 46
        let minimumSpacing: CGFloat = usesAccessibilityLayout ? 5 : 6
        let maximumSpacing: CGFloat = usesAccessibilityLayout ? 10 : 12
        let spacing = min(maximumSpacing, max(minimumSpacing, (availableWidth - minimumWidth * 6) / 5))
        let width = min(maximumWidth, max(minimumWidth, (availableWidth - spacing * 5) / 6))
        let height = max(48, width * 1.2)
        return (height, spacing, width * 6 + spacing * 5)
    }
}

private final class OTPDigitBoxView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configureTypography(usesAccessibilityLayout: Bool) {
        label.font = UIFontMetrics(forTextStyle: .title3).scaledFont(
            for: UIFont.systemFont(
                ofSize: usesAccessibilityLayout ? 23 : 22,
                weight: .semibold
            )
        )
        label.adjustsFontForContentSizeCategory = true
    }

    func configure(digit: String, isActive: Bool, isFilled: Bool, figmaBlue: UIColor) {
        label.text = digit
        label.alpha = isFilled ? 1 : 0.25
        layer.borderWidth = isActive ? 2 : 1

        if isActive {
            layer.borderColor = figmaBlue.cgColor
        } else if isFilled {
            layer.borderColor = figmaBlue.withAlphaComponent(0.45).cgColor
        } else {
            layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        }
    }

    private func setup() {
        backgroundColor = .white
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.withAlphaComponent(0.03).cgColor
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 1

        label.textAlignment = .center
        label.textColor = .label
        label.minimumScaleFactor = 0.68
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }
}
