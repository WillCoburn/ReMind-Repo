// ======================
// File: Views/Main/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor
    @ObservedObject private var revenueCat: RevenueCatManager = .shared
    var isPageActive: Bool = true

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSendNowSheet = false
    @State private var showInspirationSheet = false
    @State private var showHelpSheet = false
    @State private var showSuccessMessage = false
    @State private var pulseEditor = false
    @State private var isSubmitting = false
    @FocusState private var isEntryFieldFocused: Bool

    // Alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let goal: Int = 3

    var body: some View {
        // Observe RevenueCat updates so entitlement changes redraw instantly.
        let _ = revenueCat.entitlementActive
        let count = appVM.entries.count

        let inputIsEmpty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let buttonDisabled = isSubmitting || inputIsEmpty || !net.isConnected
        let isComposing = isEntryFieldFocused
        GeometryReader { proxy in
            let safeTop = max(proxy.safeAreaInsets.top, 16)
            let safeBottom = max(proxy.safeAreaInsets.bottom, 16)
            let viewportWidth = max(proxy.size.width, 1)
            let topContentWidth = constrainedTopContentWidth(for: viewportWidth)
            let entryInputHeight = entryInputHeight(for: proxy.size.height, isFocused: isComposing)

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: isComposing ? 14 : 18) {
                        VStack(spacing: isComposing ? 12 : 18) {
                            logoHeader
                                .scaleEffect(isComposing ? 0.78 : 1)
                                .opacity(isComposing ? 0.72 : 1)
                                .frame(height: isComposing ? 66 : 90)
                                .padding(.top, safeTop + (isComposing ? 4 : 12))
                                .id(HomeScrollTarget.top)

                            recentReminderSection(isComposing: isComposing)

                            EntryComposer(
                                text: $input,
                                isSubmitting: $isSubmitting,
                                isDisabled: buttonDisabled,
                                pulseEditor: pulseEditor,
                                inputHeight: entryInputHeight,
                                isEntryFieldFocused: _isEntryFieldFocused,
                                onSubmit: { await sendEntry() }
                            )
                            .id(HomeScrollTarget.entryComposer)

                            saveStatusView

                            HintBadge(count: count, goal: goal)
                                .padding(.top, isComposing ? 0 : 2)
                                .opacity(isComposing ? 0.45 : 1)
                                .scaleEffect(isComposing ? 0.98 : 1, anchor: .top)
                                .allowsHitTesting(!isComposing)
                        }
                        .frame(width: topContentWidth, alignment: .top)

                        actionIconRow(count: count, viewportWidth: viewportWidth)
                            .frame(width: viewportWidth)
                            .opacity(isComposing ? 0.32 : 1)
                            .scaleEffect(isComposing ? 0.96 : 1)
                            .offset(y: isComposing ? 28 : 0)
                            .padding(.top, isComposing ? 0 : 4)
                    }
                    .frame(width: viewportWidth, alignment: .top)
                    .padding(.bottom, safeBottom + (isComposing ? 56 : 24))
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard isEntryFieldFocused else { return }
                        isEntryFieldFocused = false
                        hideKeyboard()
                    },
                    including: .gesture
                )
                .onChange(of: isEntryFieldFocused) { focused in
                    withAnimation(.easeInOut(duration: 0.24)) {
                        scrollProxy.scrollTo(
                            focused ? HomeScrollTarget.entryComposer : HomeScrollTarget.top,
                            anchor: .top
                        )
                    }
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.88), value: isEntryFieldFocused)
            }
        }
        .background {
            OnboardingBackgroundView()
                .ignoresSafeArea()
        }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        isEntryFieldFocused = false
                        hideKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title3)
                    }
                    .accessibilityLabel("Dismiss keyboard")
                }
            }
            .sheet(isPresented: $showSendNowSheet) {
                NavigationStack {
                    SendNowSheet()
                }
            }
            .sheet(isPresented: $showExportSheet) {
                NavigationStack {
                    ExportSheet()
                }
            }
            .sheet(isPresented: $showInspirationSheet) {
                NavigationStack {
                    HomePlaceholderScreen(
                        title: "Inspiration Bank",
                        systemImage: "lightbulb.fill",
                        message: "Inspiration Bank coming soon"
                    )
                }
            }
            .sheet(isPresented: $showHelpSheet) {
                NavigationStack {
                    HomePlaceholderScreen(
                        title: "Help",
                        systemImage: "questionmark.circle.fill",
                        message: "Help guide coming soon"
                    )
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text(alertMessage) }
            .onChange(of: net.isConnected) { value in
                print("🔄 net.isConnected (MainView) ->", value)
            }
            .tint(.figmaBlue)
            .toolbar(.hidden, for: .navigationBar)
    }

    private var logoHeader: some View {
        VStack(spacing: 0) {
            Image("FullLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .frame(height: 58)
                .clipped()

            Image("AppTitle")
                .resizable()
                .scaledToFit()
                .frame(width: 230, height: 154)
                .frame(height: 30)
                .clipped()
        }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("ReMind")
    }

    private var saveStatusView: some View {
        ZStack {
            if showSuccessMessage {
                Text("Saved")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(height: 18)
        .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
    }

    @ViewBuilder
    private func recentReminderSection(isComposing: Bool) -> some View {
        if isComposing {
            recentReminderCard
                .opacity(0.38)
                .scaleEffect(0.97, anchor: .top)
                .frame(maxHeight: 72, alignment: .top)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            recentReminderCard
        }
    }

    private var recentReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most recent reminder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))

            if let reminder = mostRecentReceivedReminder {
                HStack(alignment: .bottom, spacing: 0) {
                    ReceivedMessageBubble(text: reminder.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "message")
                        .font(.subheadline.weight(.semibold))
                    Text("No received reminders yet")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.black.opacity(0.38))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.56))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mostRecentReceivedReminder: Entry? {
        appVM.entries.first { $0.sent }
    }

    private func actionIconRow(count: Int, viewportWidth: CGFloat) -> some View {
        let canUseGuardedActions = net.isConnected && count >= goal
        let sidePadding = actionRowSidePadding(for: viewportWidth)

        return ScrollViewReader { actionScrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    HStack(spacing: HomeLayout.actionIconSpacing) {
                        actionIconButton(
                            title: "Send One Now",
                            systemImage: "bolt.fill",
                            isEnabled: canUseGuardedActions,
                            action: handleSendNowTap
                        )

                        actionIconButton(
                            title: "Full PDF",
                            systemImage: "doc.fill",
                            isEnabled: canUseGuardedActions,
                            action: handleExportTap
                        )
                    }

                    Color.clear
                        .frame(width: HomeLayout.actionIconSpacing, height: 1)
                        .id(HomeActionScrollTarget.center)

                    HStack(spacing: HomeLayout.actionIconSpacing) {
                        actionIconButton(
                            title: "Inspiration Bank",
                            systemImage: "lightbulb.fill",
                            isEnabled: true,
                            action: { showInspirationSheet = true }
                        )

                        actionIconButton(
                            title: "Help",
                            systemImage: "questionmark.circle.fill",
                            isEnabled: true,
                            action: { showHelpSheet = true }
                        )
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                centerActionRow(using: actionScrollProxy, animated: false)
            }
            .onChange(of: isPageActive) { active in
                guard active else { return }
                centerActionRow(using: actionScrollProxy, animated: false)
            }
            .onChange(of: viewportWidth) { _ in
                guard isPageActive else { return }
                centerActionRow(using: actionScrollProxy, animated: false)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func actionIconButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.figmaBlue)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.figmaBlue.opacity(0.24), radius: 12, x: 0, y: 7)

                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: HomeLayout.actionIconButtonWidth, height: 104, alignment: .top)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func centerActionRow(using scrollProxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            let scrollAction = {
                scrollProxy.scrollTo(HomeActionScrollTarget.center, anchor: .center)
            }

            if animated {
                withAnimation(.easeOut(duration: 0.18), scrollAction)
            } else {
                scrollAction()
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func sendEntry() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        guard net.isConnected else {
            presentOfflineAlert()
            return
        }

        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        print("🧪 sendEntry → calling submit")
        
        await appVM.submit(text: text)
        print("🧪 sendEntry → submit returned")
        input = ""
        isEntryFieldFocused = false
        hideKeyboard()

        withAnimation(.easeInOut(duration: 0.5)) { pulseEditor = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) { pulseEditor = false }
        }

        withAnimation(.easeInOut(duration: 0.5)) { showSuccessMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) { showSuccessMessage = false }
        }
    }

    private func handleExportTap() {
        let count = appVM.entries.count
        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Export PDF"); return }
        Task {
            let freshOptOut = await appVM.reloadSmsOptOut()
            if freshOptOut { presentOptOutAlert(); return }
            showExportSheet = true
        }
    }

    private func handleSendNowTap() {
        let count = appVM.entries.count
        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Send One Now"); return }
        Task {
            let freshOptOut = await appVM.reloadSmsOptOut()
            if freshOptOut { presentOptOutAlert(); return }
            showSendNowSheet = true
        }
    }

    // MARK: - Alerts

    private func presentLockedAlert(feature: String) {
        alertTitle = "Keep going!"
        alertMessage = "You need at least \(goal) entries to use “\(feature)”. Add more entries to unlock this feature."
        showAlert = true
    }

    private func presentOptOutAlert() {
        alertTitle = "SMS Sending Is Blocked"
        alertMessage =
        """
        It looks like you’ve opted out of SMS for this number, so texts can’t be delivered.

        To re-enable messages, reply START or UNSTOP to the last ReMind text. After that, try again.
        """
        showAlert = true
    }

    private func presentOfflineAlert() {
        alertTitle = "No Internet Connection"
        alertMessage = "Please reconnect to the internet to use this feature."
        showAlert = true
    }

    private func constrainedTopContentWidth(for viewportWidth: CGFloat) -> CGFloat {
        max(viewportWidth - HomeLayout.horizontalPadding * 2, 1)
    }

    private func actionRowSidePadding(for viewportWidth: CGFloat) -> CGFloat {
        let buttonGroupWidth = HomeLayout.actionIconButtonWidth * 4
            + HomeLayout.actionIconSpacing * 3
        let centeredPadding = (viewportWidth - buttonGroupWidth) / 2
        return max(HomeLayout.horizontalPadding, centeredPadding)
    }

    private func entryInputHeight(for availableHeight: CGFloat, isFocused: Bool) -> CGFloat {
        guard isFocused else { return HomeLayout.collapsedEntryInputHeight }
        return min(max(availableHeight * 0.36, 210), 290)
    }
}

private enum HomeLayout {
    static let horizontalPadding: CGFloat = 24
    static let collapsedEntryInputHeight: CGFloat = 154
    static let actionIconButtonWidth: CGFloat = 86
    static let actionIconSpacing: CGFloat = 18
}

private enum HomeScrollTarget: Hashable {
    case top
    case entryComposer
}

private enum HomeActionScrollTarget: Hashable {
    case center
}

private struct ReceivedMessageBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.black.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ReceivedBubbleShape()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            .overlay {
                ReceivedBubbleShape()
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReceivedBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tailWidth = min(10, rect.width * 0.12)
        let tailHeight = min(16, rect.height * 0.38)
        let bubbleMinX = rect.minX + tailWidth
        let bubbleMaxX = rect.maxX
        let bubbleMinY = rect.minY
        let bubbleMaxY = rect.maxY
        let radius = min(18, rect.height / 2, (rect.width - tailWidth) / 2)

        var path = Path()

        path.move(to: CGPoint(x: bubbleMinX + radius, y: bubbleMinY))
        path.addLine(to: CGPoint(x: bubbleMaxX - radius, y: bubbleMinY))
        path.addQuadCurve(
            to: CGPoint(x: bubbleMaxX, y: bubbleMinY + radius),
            control: CGPoint(x: bubbleMaxX, y: bubbleMinY)
        )
        path.addLine(to: CGPoint(x: bubbleMaxX, y: bubbleMaxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: bubbleMaxX - radius, y: bubbleMaxY),
            control: CGPoint(x: bubbleMaxX, y: bubbleMaxY)
        )
        path.addLine(to: CGPoint(x: bubbleMinX + radius, y: bubbleMaxY))
        path.addCurve(
            to: CGPoint(x: bubbleMinX + 5, y: bubbleMaxY - 2),
            control1: CGPoint(x: bubbleMinX + 13, y: bubbleMaxY),
            control2: CGPoint(x: bubbleMinX + 8, y: bubbleMaxY - 1)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: bubbleMaxY - 1),
            control1: CGPoint(x: bubbleMinX + 2, y: bubbleMaxY),
            control2: CGPoint(x: rect.minX + 2, y: bubbleMaxY)
        )
        path.addCurve(
            to: CGPoint(x: bubbleMinX + 4, y: bubbleMaxY - tailHeight),
            control1: CGPoint(x: rect.minX + 7, y: bubbleMaxY - 2),
            control2: CGPoint(x: bubbleMinX + 4, y: bubbleMaxY - tailHeight * 0.45)
        )
        path.addLine(to: CGPoint(x: bubbleMinX, y: bubbleMinY + radius))
        path.addQuadCurve(
            to: CGPoint(x: bubbleMinX + radius, y: bubbleMinY),
            control: CGPoint(x: bubbleMinX, y: bubbleMinY)
        )
        path.closeSubpath()
        return path
    }
}

private struct HomePlaceholderScreen: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ZStack {
            OnboardingBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.figmaBlue)

                Text(message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
    }
}
