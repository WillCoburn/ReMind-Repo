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

                            recentReminderSection(
                                isComposing: isComposing,
                                maxBubbleWidth: recentReminderBubbleMaxWidth(for: topContentWidth)
                            )

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
                    HelpGuideSheet()
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text(alertMessage) }
            .onAppear {
                guard isPageActive else { return }
                refreshMainViewData()
            }
            .onChange(of: isPageActive) { active in
                guard active else { return }
                refreshMainViewData()
            }
            .onChange(of: showSendNowSheet) { showing in
                guard !showing, isPageActive else { return }
                refreshMainViewData()
            }
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
    private func recentReminderSection(isComposing: Bool, maxBubbleWidth: CGFloat) -> some View {
        if isComposing {
            recentReminderCard(maxBubbleWidth: maxBubbleWidth)
                .opacity(0.38)
                .scaleEffect(0.97, anchor: .top)
                .frame(maxHeight: 72, alignment: .top)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            recentReminderCard(maxBubbleWidth: maxBubbleWidth)
        }
    }

    private func recentReminderCard(maxBubbleWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most recent reminder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))

            if let reminder = mostRecentReceivedReminder {
                HStack(alignment: .bottom, spacing: 0) {
                    ReceivedMessageBubble(text: reminder.text, maxBubbleWidth: maxBubbleWidth)
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

    private var mostRecentReceivedReminder: LastReminder? {
        appVM.latestReminderForDisplay
    }

    private func actionIconRow(count: Int, viewportWidth: CGFloat) -> some View {
        let canUseGuardedActions = net.isConnected && count >= goal
        let iconSpacing = actionIconSpacing(for: viewportWidth)
        let sidePadding = actionRowSidePadding(for: viewportWidth, iconSpacing: iconSpacing)

        return ScrollViewReader { actionScrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: iconSpacing) {
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
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 8)
                .id(HomeActionScrollTarget.leading)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                resetActionRowToLeading(using: actionScrollProxy, animated: false)
            }
            .onChange(of: isPageActive) { active in
                guard active else { return }
                resetActionRowToLeading(using: actionScrollProxy, animated: false)
            }
            .onChange(of: viewportWidth) { _ in
                guard isPageActive else { return }
                resetActionRowToLeading(using: actionScrollProxy, animated: false)
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
                        .frame(width: HomeLayout.actionIconCircleSize, height: HomeLayout.actionIconCircleSize)
                        .shadow(color: Color.figmaBlue.opacity(0.24), radius: 12, x: 0, y: 7)

                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: HomeLayout.actionIconButtonWidth, height: 104, alignment: .top)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func resetActionRowToLeading(using scrollProxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            let scrollAction = {
                scrollProxy.scrollTo(HomeActionScrollTarget.leading, anchor: .leading)
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

    private func refreshMainViewData() {
        Task {
            await appVM.refreshLatestSentReminder()
        }
    }

    private func constrainedTopContentWidth(for viewportWidth: CGFloat) -> CGFloat {
        max(viewportWidth - HomeLayout.horizontalPadding * 2, 1)
    }

    private func recentReminderBubbleMaxWidth(for contentWidth: CGFloat) -> CGFloat {
        let availableCardContentWidth = max(contentWidth - 32, 1)
        return max(availableCardContentWidth * 0.84, 1)
    }

    private func actionRowSidePadding(for viewportWidth: CGFloat, iconSpacing: CGFloat) -> CGFloat {
        let groupWidth = HomeLayout.actionIconButtonWidth * 4 + iconSpacing * 3
        return max((viewportWidth - groupWidth) / 2, 0)
    }

    private func actionIconSpacing(for viewportWidth: CGFloat) -> CGFloat {
        let buttonWidth = HomeLayout.actionIconButtonWidth * 4
        let availableForCenteredRow = max(viewportWidth - HomeLayout.minimumCenteredActionEdgeInset * 2, 1)
        let fittingSpacing = (availableForCenteredRow - buttonWidth) / 3
        return min(
            HomeLayout.actionIconSpacing,
            max(HomeLayout.minimumActionIconSpacing, fittingSpacing)
        )
    }

    private func entryInputHeight(for availableHeight: CGFloat, isFocused: Bool) -> CGFloat {
        guard isFocused else { return HomeLayout.collapsedEntryInputHeight }
        return min(max(availableHeight * 0.36, 210), 290)
    }
}

private enum HomeLayout {
    static let horizontalPadding: CGFloat = 24
    static let collapsedEntryInputHeight: CGFloat = 154
    static let actionIconCircleSize: CGFloat = 64
    static let actionIconButtonWidth: CGFloat = 68
    static let actionIconSpacing: CGFloat = 18
    static let minimumActionIconSpacing: CGFloat = 8
    static let minimumCenteredActionEdgeInset: CGFloat = 12
}

private enum HomeScrollTarget: Hashable {
    case top
    case entryComposer
}

private enum HomeActionScrollTarget: Hashable {
    case leading
}

private struct ReceivedMessageBubble: View {
    let text: String
    let maxBubbleWidth: CGFloat

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.black.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 24)
            .padding(.trailing, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            .background {
                ReceivedBubbleShape()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.06), radius: 11, x: 0, y: 5)
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
        let tailWidth = min(max(rect.width * 0.05, 10), 14)
        let tailHeight = min(max(rect.height * 0.27, 14), 22)
        let bubbleMinX = rect.minX + tailWidth
        let bubbleMaxX = rect.maxX
        let bubbleMinY = rect.minY
        let bubbleMaxY = rect.maxY
        let corner = min(22, rect.height * 0.48, (rect.width - tailWidth) / 2)
        let lowerCorner = min(corner, 20)
        let tailTip = CGPoint(x: rect.minX + 0.7, y: bubbleMaxY - 3.2)
        let tailRejoin = CGPoint(x: bubbleMinX + 5.2, y: bubbleMaxY - tailHeight)

        var path = Path()

        path.move(to: CGPoint(x: bubbleMinX + corner, y: bubbleMinY))
        path.addLine(to: CGPoint(x: bubbleMaxX - corner, y: bubbleMinY))
        path.addCurve(
            to: CGPoint(x: bubbleMaxX, y: bubbleMinY + corner),
            control1: CGPoint(x: bubbleMaxX - corner * 0.28, y: bubbleMinY),
            control2: CGPoint(x: bubbleMaxX, y: bubbleMinY + corner * 0.28)
        )
        path.addLine(to: CGPoint(x: bubbleMaxX, y: bubbleMaxY - lowerCorner))
        path.addCurve(
            to: CGPoint(x: bubbleMaxX - lowerCorner, y: bubbleMaxY),
            control1: CGPoint(x: bubbleMaxX, y: bubbleMaxY - lowerCorner * 0.28),
            control2: CGPoint(x: bubbleMaxX - lowerCorner * 0.28, y: bubbleMaxY)
        )
        path.addLine(to: CGPoint(x: bubbleMinX + lowerCorner + 7, y: bubbleMaxY))
        path.addCurve(
            to: CGPoint(x: bubbleMinX + 7.4, y: bubbleMaxY - 1.4),
            control1: CGPoint(x: bubbleMinX + 20, y: bubbleMaxY),
            control2: CGPoint(x: bubbleMinX + 12.2, y: bubbleMaxY + 0.2)
        )
        path.addCurve(
            to: tailTip,
            control1: CGPoint(x: bubbleMinX + 4.8, y: bubbleMaxY + 0.4),
            control2: CGPoint(x: rect.minX + 2.7, y: bubbleMaxY - 0.2)
        )
        path.addCurve(
            to: tailRejoin,
            control1: CGPoint(x: rect.minX + 5.8, y: bubbleMaxY - 5.3),
            control2: CGPoint(x: bubbleMinX + 3.5, y: bubbleMaxY - tailHeight * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: bubbleMinX, y: bubbleMaxY - lowerCorner),
            control1: CGPoint(x: bubbleMinX + 1.3, y: bubbleMaxY - tailHeight - 4.4),
            control2: CGPoint(x: bubbleMinX, y: bubbleMaxY - lowerCorner + 6)
        )
        path.addLine(to: CGPoint(x: bubbleMinX, y: bubbleMinY + corner))
        path.addCurve(
            to: CGPoint(x: bubbleMinX + corner, y: bubbleMinY),
            control1: CGPoint(x: bubbleMinX, y: bubbleMinY + corner * 0.28),
            control2: CGPoint(x: bubbleMinX + corner * 0.28, y: bubbleMinY)
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

private struct HelpGuideSheet: View {
    @EnvironmentObject private var appVM: AppViewModel
    @State private var animateHero = false

    var body: some View {
        ZStack {
            OnboardingBackgroundView()
                .ignoresSafeArea()

            GeometryReader { proxy in
                let horizontalPadding = min(max(proxy.size.width * 0.055, 18), 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HelpHeroIllustration(animate: animateHero)
                            .frame(height: proxy.size.height < 660 ? 148 : 184)
                            .padding(.top, 18)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("A little guide to BrainMail")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .multilineTextAlignment(.center)

                            Text("I wanted this page to feel less like a manual and more like a quick note from the person who made the thing.")
                                .font(.subheadline)
                                .foregroundStyle(Color.black.opacity(0.58))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 430)

                        HelpSectionCard(title: "What is this app?", systemImage: "sparkles") {
                            HelpBodyText("BrainMail is a mini positivity journal for your future self. Jot down affirmations, moments of clarity, ideas, reminders, or thoughts that resonate with you, and BrainMail will text them back to you at random times.")
                        }

                        HelpSectionCard(title: "Why did I make this?", systemImage: "heart.text.square") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("At first I made this app just for me in an attempt to be more thoughtful, intentional, and kind to myself. Journaling was always too much work just to end up forgetting all that hard-earned clarity the next day.")
                                HelpBodyText("I recognize this isn't for everyone, and that's totally fine. But I ended up sharing this app in the off chance that you're like me, and you've tried to support yourself or take account of your own wandering mind through notes, journaling, affirmations, or little reminders, but nothing ever stuck.")
                            }
                        }

                        HelpSectionCard(title: "How do I use it?", systemImage: "pencil.and.outline") {
                            VStack(alignment: .leading, spacing: 12) {
                                HelpBullet(icon: "plus.bubble", text: "Write small notes you would actually want to receive later.")
                                HelpBullet(icon: "tray.and.arrow.down", text: "Save thoughts, reminders, affirmations, quotes, or moments of clarity.")
                                HelpBullet(icon: "message", text: "Let BrainMail text them back at random times inside your reminder window.")
                                HelpBullet(icon: "bolt.fill", text: "Use Send One Now when you want something from your own archive right away.")
                                HelpBullet(icon: "doc.text", text: "Export a Full PDF when you want a clean copy of what you've written.")
                                HelpBullet(icon: "person.2", text: "Use Community if you want to share something encouraging with others.")
                            }
                        }

                        HelpSectionCard(title: "How does it work?", systemImage: "shuffle") {
                            VStack(alignment: .leading, spacing: 12) {
                                HelpBullet(icon: "text.quote", text: "Reminder texts are selected from your own saved entries.")
                                HelpBullet(icon: "clock", text: "Your settings control roughly how often reminders arrive and what hours they can send.")
                                HelpBullet(icon: "lock", text: "Your private entries stay private unless you intentionally post something to Community.")
                                HelpBullet(icon: "shield", text: "Community posts are anonymous and moderated so the space can stay kind.")
                            }
                        }

                        HelpSectionCard(title: "Do I have to pay?", systemImage: "creditcard") {
                            HelpBodyText(pricingText)
                        }

                        HelpSectionCard(title: "A few writing tips", systemImage: "leaf") {
                            VStack(alignment: .leading, spacing: 12) {
                                HelpBullet(icon: "quote.opening", text: "Write the way you would talk to someone you care about.")
                                HelpBullet(icon: "scope", text: "Specific usually lands better than perfect.")
                                HelpBullet(icon: "heart", text: "Save the thoughts you tend to forget when life gets loud.")
                            }
                        }

                        HelpSectionCard(title: "Support / Contact", systemImage: "envelope") {
                            VStack(alignment: .leading, spacing: 12) {
                                HelpBodyText("Questions, bugs, weird ideas, or honest feedback are welcome. I genuinely read feedback and ideas.")

                                Link(destination: supportURL) {
                                    Label("remindapphelp@gmail.com", systemImage: "paperplane.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.figmaBlue)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 28, 36))
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartHeroAnimation() }
    }

    private var pricingText: String {
        if appVM.isProUser {
            return "You're on Premium, so you have the roomier version of the app. Thank you for helping cover the texting and backend costs that keep BrainMail running."
        }

        return "You can save reminders and receive up to a few random texts each week for free. Premium is there if you want roomier limits, like higher reminder frequency and more instant sends. No pressure, truly. SMS and backend costs are the reason there are limits at all."
    }

    private var supportURL: URL {
        URL(string: "mailto:remindapphelp@gmail.com?subject=BrainMail%20Feedback")!
    }

    private func restartHeroAnimation() {
        animateHero = false
        DispatchQueue.main.async {
            animateHero = true
        }
    }
}

private struct HelpHeroIllustration: View {
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 174, height: 174)
                .scaleEffect(animate ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: animate)

            BottleAnimationView(width: 58, height: 98)
                .offset(x: -58, y: animate ? 2 : 9)
                .rotationEffect(.degrees(animate ? -8 : -4))
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animate)

            HelpFloatingNote(width: 138, accent: Color.figmaBlue)
                .offset(x: animate ? 34 : 20, y: animate ? -28 : -16)
                .rotationEffect(.degrees(animate ? 4 : 1))
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: animate)

            HelpFloatingNote(width: 104, accent: Color(red: 222/255, green: 174/255, blue: 202/255))
                .offset(x: animate ? 62 : 74, y: animate ? 44 : 32)
                .rotationEffect(.degrees(animate ? -7 : -2))
                .opacity(0.84)
                .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: animate)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HelpFloatingNote: View {
    let width: CGFloat
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(accent.opacity(0.28))
                .frame(width: width * 0.42, height: 6)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.13))
                .frame(width: width * 0.68, height: 6)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.09))
                .frame(width: width * 0.54, height: 6)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.86))
                .shadow(color: Color.black.opacity(0.055), radius: 12, x: 0, y: 7)
        )
    }
}

private struct HelpSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.figmaBlue)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.figmaBlue.opacity(0.09))
                    )

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

private struct HelpBodyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.black.opacity(0.62))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HelpBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.figmaBlue.opacity(0.86))
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.64))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
