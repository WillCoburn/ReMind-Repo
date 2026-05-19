// ======================
// File: Views/Main/MainView.swift
// ======================
import SwiftUI
import Foundation

private enum ActiveHomeSheet: String, Equatable, Identifiable {
    case sendNow
    case export
    case inspiration
    case help

    var id: String { rawValue }
}

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var isPageActive: Bool = true

    @State private var input: String = ""
    @State private var activeHomeSheet: ActiveHomeSheet?
    @State private var guardedActionTask: Task<Void, Never>?
    @State private var showDeleteReminderConfirmation = false
    @State private var pendingDeleteReminder: LastReminder?
    @State private var showSuccessMessage = false
    @State private var pulseEditor = false
    @State private var isSubmitting = false
    @State private var isDeletingLatestReminder = false
    @FocusState private var isEntryFieldFocused: Bool

    // Alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let goal: Int = 3

    var body: some View {
        let count = appVM.activeEntries.count

        let inputIsEmpty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let buttonDisabled = isSubmitting || inputIsEmpty || !net.isConnected
        let isComposing = isEntryFieldFocused
        GeometryReader { proxy in
            let safeTop = max(proxy.safeAreaInsets.top, 16)
            let safeBottom = max(proxy.safeAreaInsets.bottom, 16)
            let viewportWidth = max(proxy.size.width, 1)
            let topContentWidth = constrainedTopContentWidth(for: viewportWidth)
            let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout
            let entryInputHeight = entryInputHeight(
                for: proxy.size.height,
                isFocused: isComposing,
                usesAccessibilityLayout: usesAccessibilityLayout
            )

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: isComposing ? (usesAccessibilityLayout ? 18 : 14) : (usesAccessibilityLayout ? 24 : 18)) {
                        VStack(spacing: isComposing ? (usesAccessibilityLayout ? 16 : 12) : (usesAccessibilityLayout ? 22 : 18)) {
                            VStack(spacing: isComposing ? (usesAccessibilityLayout ? 16 : 12) : (usesAccessibilityLayout ? 22 : 18)) {
                                logoHeader
                                    .scaleEffect(isComposing && !usesAccessibilityLayout ? 0.86 : 1)
                                    .opacity(isComposing ? 0.82 : 1)
                                    .frame(height: logoHeight(isComposing: isComposing, usesAccessibilityLayout: usesAccessibilityLayout))
                                    .padding(.top, safeTop + (isComposing ? 6 : 12))
                                    .id(HomeScrollTarget.top)

                                recentReminderSection(
                                    isComposing: isComposing,
                                    maxBubbleWidth: recentReminderBubbleMaxWidth(
                                        for: topContentWidth,
                                        usesAccessibilityLayout: usesAccessibilityLayout
                                    ),
                                    usesAccessibilityLayout: usesAccessibilityLayout
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissEntryKeyboard()
                            }

                            EntryComposer(
                                text: $input,
                                isSubmitting: $isSubmitting,
                                isDisabled: buttonDisabled,
                                pulseEditor: pulseEditor,
                                inputHeight: entryInputHeight,
                                isEntryFieldFocused: _isEntryFieldFocused,
                                onSubmit: { await sendEntry() },
                                onCancel: cancelEntryComposer
                            )
                            .id(HomeScrollTarget.entryComposer)

                            saveStatusView

                            HintBadge(count: count, goal: goal)
                                .padding(.top, isComposing ? 0 : 2)
                                .opacity(isComposing ? 0.72 : 1)
                                .scaleEffect(isComposing ? 0.98 : 1, anchor: .top)
                                .allowsHitTesting(!isComposing)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissEntryKeyboard()
                                }
                        }
                        .frame(width: topContentWidth, alignment: .top)

                        actionIconActions(count: count, viewportWidth: viewportWidth)
                            .frame(width: viewportWidth)
                            .opacity(isComposing ? 0.72 : 1)
                            .scaleEffect(isComposing ? 0.98 : 1)
                            .padding(.top, isComposing ? 0 : 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissEntryKeyboard()
                            }
                    }
                    .frame(width: viewportWidth, alignment: .top)
                    .padding(.bottom, safeBottom + (isComposing ? 42 : 24))
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onChange(of: isEntryFieldFocused) { focused in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            scrollProxy.scrollTo(
                                focused ? HomeScrollTarget.entryComposer : HomeScrollTarget.top,
                                anchor: focused ? .center : .top
                            )
                        }
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
            .sheet(item: $activeHomeSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .sendNow:
                        SendNowSheet()
                    case .export:
                        ExportSheet()
                    case .inspiration:
                        InspirationBankSheet()
                    case .help:
                        HelpGuideSheet()
                    }
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
                guard active else {
                    guardedActionTask?.cancel()
                    dismissEntryKeyboard()
                    return
                }
                refreshMainViewData()
            }
            .onChange(of: activeHomeSheet) { showing in
                guard showing == nil, isPageActive else { return }
                refreshMainViewData()
            }
            .onDisappear {
                guardedActionTask?.cancel()
            }
            .onChange(of: appVM.user?.uid) { _ in
                guardedActionTask?.cancel()
                activeHomeSheet = nil
            }
            .tint(.figmaBlue)
            .toolbar(.hidden, for: .navigationBar)
            .brainMailDynamicTypeRange()
            .overlay {
                if showDeleteReminderConfirmation, let pendingDeleteReminder {
                    BrainMailConfirmationOverlay(
                        title: "Are you sure you want to remove this reminder from your bank?",
                        message: "",
                        confirmTitle: "Yes, delete",
                        cancelTitle: "Cancel",
                        symbolName: "trash",
                        onConfirm: {
                            confirmDeleteReminder(pendingDeleteReminder)
                        },
                        onCancel: cancelDeleteReminder
                    )
                    .transition(.opacity)
                }
            }
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
    private func recentReminderSection(
        isComposing: Bool,
        maxBubbleWidth: CGFloat,
        usesAccessibilityLayout: Bool
    ) -> some View {
        if isComposing && usesAccessibilityLayout {
            EmptyView()
        } else if isComposing {
            recentReminderCard(maxBubbleWidth: maxBubbleWidth)
                .opacity(0.38)
                .scaleEffect(0.97, anchor: .top)
                .frame(maxHeight: 72, alignment: .top)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            recentReminderCard(
                maxBubbleWidth: maxBubbleWidth,
                usesAccessibilityLayout: usesAccessibilityLayout
            )
        }
    }

    private func recentReminderCard(maxBubbleWidth: CGFloat, usesAccessibilityLayout: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most recent reminder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))

            if let reminder = mostRecentReceivedReminder {
                let deleteButtonSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 44
                let bubbleWidth = max(maxBubbleWidth - deleteButtonSize - 6, 1)

                HStack(alignment: .center, spacing: 6) {
                    ReceivedMessageBubble(
                        text: reminder.text,
                        maxBubbleWidth: bubbleWidth
                    )
                    .layoutPriority(1)

                    deleteReminderButton(for: reminder)
                        .frame(width: deleteButtonSize, height: deleteButtonSize)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Group {
                    if usesAccessibilityLayout {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "message")
                                .font(.title3.weight(.semibold))
                            Text("No received reminders yet")
                                .font(.body)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "message")
                                .font(.subheadline.weight(.semibold))
                            Text("No received reminders yet")
                                .font(.subheadline)
                        }
                    }
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

    private func deleteReminderButton(for reminder: LastReminder) -> some View {
        let isDeleted = appVM.isReminderDeleted(reminder)
        let iconSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 18 : 15
        let buttonSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 44

        return Button {
            pendingDeleteReminder = reminder
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                showDeleteReminderConfirmation = true
            }
        } label: {
            ZStack {
                if isDeletingLatestReminder && !isDeleted {
                    ProgressView()
                        .scaleEffect(0.74)
                        .tint(Color.figmaBlue.opacity(0.62))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(isDeleted ? Color.black.opacity(0.24) : Color.figmaBlue.opacity(0.58))
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDeleted || isDeletingLatestReminder)
        .accessibilityLabel(isDeleted ? "Reminder removed from bank" : "Remove reminder from bank")
        .accessibilityIdentifier("home.recentReminder.delete")
    }

    @ViewBuilder
    private func actionIconActions(count: Int, viewportWidth: CGFloat) -> some View {
        if dynamicTypeSize.brainMailUsesAccessibilityLayout {
            actionIconGrid(count: count, viewportWidth: viewportWidth)
        } else {
            actionIconRow(count: count, viewportWidth: viewportWidth)
        }
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
                        style: .compact,
                        action: handleSendNowTap
                    )

                    actionIconButton(
                        title: "Full PDF",
                        systemImage: "doc.fill",
                        isEnabled: canUseGuardedActions,
                        style: .compact,
                        action: handleExportTap
                    )

                    actionIconButton(
                        title: inspirationBankActionTitle,
                        systemImage: "lightbulb.fill",
                        isEnabled: true,
                        style: .compact,
                        action: { activeHomeSheet = .inspiration }
                    )

                    actionIconButton(
                        title: "Help",
                        systemImage: "questionmark.circle.fill",
                        isEnabled: true,
                        style: .compact,
                        action: { activeHomeSheet = .help }
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

    private func actionIconGrid(count: Int, viewportWidth: CGFloat) -> some View {
        let canUseGuardedActions = net.isConnected && count >= goal
        let gridWidth = actionGridWidth(for: viewportWidth)
        let columns = [
            GridItem(.flexible(minimum: HomeLayout.accessibilityActionGridCellMinWidth), spacing: HomeLayout.accessibilityActionGridColumnSpacing),
            GridItem(.flexible(minimum: HomeLayout.accessibilityActionGridCellMinWidth), spacing: HomeLayout.accessibilityActionGridColumnSpacing)
        ]

        return LazyVGrid(columns: columns, spacing: HomeLayout.accessibilityActionGridRowSpacing) {
            actionIconButton(
                title: "Send One Now",
                systemImage: "bolt.fill",
                isEnabled: canUseGuardedActions,
                style: .accessibilityGrid,
                action: handleSendNowTap
            )

            actionIconButton(
                title: "Full PDF",
                systemImage: "doc.fill",
                isEnabled: canUseGuardedActions,
                style: .accessibilityGrid,
                action: handleExportTap
            )

            actionIconButton(
                title: inspirationBankActionTitle,
                systemImage: "lightbulb.fill",
                isEnabled: true,
                style: .accessibilityGrid,
                action: { activeHomeSheet = .inspiration }
            )

            actionIconButton(
                title: "Help",
                systemImage: "questionmark.circle.fill",
                isEnabled: true,
                style: .accessibilityGrid,
                action: { activeHomeSheet = .help }
            )
        }
        .frame(width: gridWidth)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actionIconButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        style: HomeActionIconStyle,
        action: @escaping () -> Void
    ) -> some View {
        let circleSize = style.circleSize
        let buttonHeight = style.buttonHeight
        let accessibilityTitle = title == "Inspo Bank" ? "Inspiration Bank" : title

        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.figmaBlue)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(color: Color.figmaBlue.opacity(0.24), radius: 12, x: 0, y: 7)

                    Image(systemName: systemImage)
                        .font(.system(size: style.iconSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: style.iconAlignment)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineLimit(style.labelLineLimit)
                    .minimumScaleFactor(style.minimumLabelScale)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(width: style.buttonWidth, alignment: .top)
            .frame(minHeight: buttonHeight, alignment: .top)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityIdentifier("home.action.\(accessibilityTitle)")
    }

    private var inspirationBankActionTitle: String {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large, .xLarge:
            return "Inspiration Bank"
        default:
            return "Inspo Bank"
        }
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

        do {
            try await appVM.submit(text: text)
            input = ""
            dismissEntryKeyboard()

            withAnimation(.easeInOut(duration: 0.5)) { pulseEditor = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.5)) { pulseEditor = false }
            }

            withAnimation(.easeInOut(duration: 0.5)) { showSuccessMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) { showSuccessMessage = false }
            }
        } catch {
            alertTitle = "Couldn't save reminder"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func handleExportTap() {
        let count = appVM.activeEntries.count
        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Export PDF"); return }
        guardedActionTask?.cancel()
        guardedActionTask = Task { @MainActor in
            let freshOptOut = await appVM.reloadSmsOptOut()
            guard !Task.isCancelled, isPageActive else { return }
            if freshOptOut { presentOptOutAlert(); return }
            activeHomeSheet = .export
        }
    }

    private func handleSendNowTap() {
        let count = appVM.activeEntries.count
        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Send One Now"); return }
        guardedActionTask?.cancel()
        guardedActionTask = Task { @MainActor in
            let freshOptOut = await appVM.reloadSmsOptOut()
            guard !Task.isCancelled, isPageActive else { return }
            if freshOptOut { presentOptOutAlert(); return }
            activeHomeSheet = .sendNow
        }
    }

    private func cancelDeleteReminder() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showDeleteReminderConfirmation = false
        }
        pendingDeleteReminder = nil
    }

    private func confirmDeleteReminder(_ reminder: LastReminder) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showDeleteReminderConfirmation = false
        }

        Task {
            await deleteReminderFromBank(reminder)
        }
    }

    private func deleteReminderFromBank(_ reminder: LastReminder) async {
        guard !isDeletingLatestReminder else { return }
        isDeletingLatestReminder = true
        defer {
            isDeletingLatestReminder = false
            pendingDeleteReminder = nil
        }

        do {
            try await appVM.softDeleteReminderFromBank(reminder)
            Haptics.success()
        } catch {
            alertTitle = "Couldn't remove reminder"
            alertMessage = error.localizedDescription
            showAlert = true
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

    private func dismissEntryKeyboard() {
        guard isEntryFieldFocused else { return }
        isEntryFieldFocused = false
        hideKeyboard()
    }

    private func cancelEntryComposer() {
        input = ""
        dismissEntryKeyboard()
    }

    private func constrainedTopContentWidth(for viewportWidth: CGFloat) -> CGFloat {
        max(viewportWidth - HomeLayout.horizontalPadding * 2, 1)
    }

    private func recentReminderBubbleMaxWidth(for contentWidth: CGFloat, usesAccessibilityLayout: Bool) -> CGFloat {
        let availableCardContentWidth = max(contentWidth - 32, 1)
        return max(availableCardContentWidth * (usesAccessibilityLayout ? 0.99 : 0.98), 1)
    }

    private func actionRowSidePadding(for viewportWidth: CGFloat, iconSpacing: CGFloat) -> CGFloat {
        let buttonWidth = dynamicTypeSize.brainMailUsesAccessibilityLayout
            ? HomeLayout.accessibilityActionIconButtonWidth
            : HomeLayout.actionIconButtonWidth
        let groupWidth = buttonWidth * 4 + iconSpacing * 3
        return max((viewportWidth - groupWidth) / 2, 0)
    }

    private func actionIconSpacing(for viewportWidth: CGFloat) -> CGFloat {
        let itemWidth = dynamicTypeSize.brainMailUsesAccessibilityLayout
            ? HomeLayout.accessibilityActionIconButtonWidth
            : HomeLayout.actionIconButtonWidth
        let buttonWidth = itemWidth * 4
        let availableForCenteredRow = max(viewportWidth - HomeLayout.minimumCenteredActionEdgeInset * 2, 1)
        let fittingSpacing = (availableForCenteredRow - buttonWidth) / 3
        return min(
            HomeLayout.actionIconSpacing,
            max(HomeLayout.minimumActionIconSpacing, fittingSpacing)
        )
    }

    private func actionGridWidth(for viewportWidth: CGFloat) -> CGFloat {
        let availableWidth = max(viewportWidth - HomeLayout.horizontalPadding * 2, 1)
        return min(HomeLayout.accessibilityActionGridMaxWidth, availableWidth)
    }

    private func entryInputHeight(
        for availableHeight: CGFloat,
        isFocused: Bool,
        usesAccessibilityLayout: Bool
    ) -> CGFloat {
        guard isFocused else {
            return usesAccessibilityLayout
                ? HomeLayout.accessibilityCollapsedEntryInputHeight
                : HomeLayout.collapsedEntryInputHeight
        }

        if usesAccessibilityLayout {
            return min(max(availableHeight * 0.24, 168), 230)
        }

        return min(max(availableHeight * 0.17, 124), 154)
    }

    private func logoHeight(isComposing: Bool, usesAccessibilityLayout: Bool) -> CGFloat {
        if usesAccessibilityLayout {
            return isComposing ? 54 : 70
        }

        return isComposing ? 72 : 90
    }
}

private enum HomeLayout {
    static let horizontalPadding: CGFloat = 24
    static let collapsedEntryInputHeight: CGFloat = 112
    static let accessibilityCollapsedEntryInputHeight: CGFloat = 136
    static let actionIconCircleSize: CGFloat = 64
    static let accessibilityActionIconCircleSize: CGFloat = 72
    static let actionIconButtonWidth: CGFloat = 68
    static let accessibilityActionIconButtonWidth: CGFloat = 92
    static let accessibilityActionIconButtonHeight: CGFloat = 152
    static let actionIconSpacing: CGFloat = 18
    static let minimumActionIconSpacing: CGFloat = 8
    static let minimumCenteredActionEdgeInset: CGFloat = 12
    static let accessibilityActionGridCellMinWidth: CGFloat = 112
    static let accessibilityActionGridColumnSpacing: CGFloat = 18
    static let accessibilityActionGridRowSpacing: CGFloat = 16
    static let accessibilityActionGridMaxWidth: CGFloat = 360
}

private enum HomeActionIconStyle {
    case compact
    case accessibilityGrid

    var circleSize: CGFloat {
        switch self {
        case .compact:
            return HomeLayout.actionIconCircleSize
        case .accessibilityGrid:
            return HomeLayout.accessibilityActionIconCircleSize
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact:
            return 24
        case .accessibilityGrid:
            return 27
        }
    }

    var buttonWidth: CGFloat? {
        switch self {
        case .compact:
            return HomeLayout.actionIconButtonWidth
        case .accessibilityGrid:
            return nil
        }
    }

    var iconAlignment: Alignment {
        switch self {
        case .compact:
            return .leading
        case .accessibilityGrid:
            return .center
        }
    }

    var buttonHeight: CGFloat {
        switch self {
        case .compact:
            return 104
        case .accessibilityGrid:
            return HomeLayout.accessibilityActionIconButtonHeight
        }
    }

    var labelLineLimit: Int {
        switch self {
        case .compact:
            return 2
        case .accessibilityGrid:
            return 2
        }
    }

    var minimumLabelScale: CGFloat {
        switch self {
        case .compact:
            return 0.82
        case .accessibilityGrid:
            return 0.88
        }
    }
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
        let bubbleWidth = max(maxBubbleWidth, 1)

        ViewThatFits(in: .horizontal) {
            shortBubble
                .frame(maxWidth: bubbleWidth, alignment: .leading)

            fullWidthBubble(width: bubbleWidth)
        }
        .frame(width: bubbleWidth, alignment: .leading)
        .accessibilityIdentifier("home.recentReminder.bubble")
    }

    private var shortBubble: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.leading, 25)
            .padding(.trailing, 18)
            .padding(.vertical, 13)
            .background(bubbleBackground)
            .overlay(bubbleStroke)
    }

    private func fullWidthBubble(width: CGFloat) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.white)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 25)
            .padding(.trailing, 18)
            .padding(.vertical, 13)
            .frame(width: width, alignment: .leading)
            .background(bubbleBackground)
            .overlay(bubbleStroke)
    }

    private var bubbleBackground: some View {
        ModernSMSBubbleShape()
            .fill(Color.figmaBlue)
            .shadow(color: Color.figmaBlue.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private var bubbleStroke: some View {
        ModernSMSBubbleShape()
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }
}

private struct ModernSMSBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 4, rect.height > 4 else {
            var path = Path()
            path.addRect(rect)
            return path
        }

        let tailWidth = min(max(rect.width * 0.07, 12), min(17, rect.width * 0.32))
        let tailHeight = min(max(rect.height * 0.30, 16), min(24, rect.height * 0.62))
        let bubbleMinX = rect.minX + tailWidth
        let bubbleMaxX = rect.maxX - 0.5
        let bubbleMinY = rect.minY + 0.5
        let bubbleMaxY = rect.maxY - 0.5
        let corner = max(1, min(23, rect.height * 0.47, (rect.width - tailWidth) / 2))
        let lowerCorner = min(corner, 21)
        let tailTip = CGPoint(x: rect.minX + 0.8, y: bubbleMaxY - 2.8)
        let tailBaseTop = CGPoint(x: bubbleMinX, y: bubbleMaxY - tailHeight)
        let tailBaseBottom = CGPoint(x: bubbleMinX + lowerCorner * 0.55, y: bubbleMaxY)

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
        path.addLine(to: tailBaseBottom)
        path.addCurve(
            to: tailTip,
            control1: CGPoint(x: bubbleMinX - 4.2, y: bubbleMaxY + 0.8),
            control2: CGPoint(x: rect.minX + 4.0, y: bubbleMaxY + 0.5)
        )
        path.addCurve(
            to: tailBaseTop,
            control1: CGPoint(x: rect.minX + 4.8, y: bubbleMaxY - 9.2),
            control2: CGPoint(x: bubbleMinX - 1.8, y: bubbleMaxY - tailHeight * 0.50)
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var animateHero = false

    var body: some View {
        let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 246/255, green: 249/255, blue: 255/255),
                    Color(red: 249/255, green: 244/255, blue: 251/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let horizontalPadding = min(max(proxy.size.width * 0.055, 18), 28)
                let contentWidth = max(1, min(560, proxy.size.width - horizontalPadding * 2))
                let heroHeight: CGFloat = usesAccessibilityLayout ? 132 : (proxy.size.height < 660 ? 140 : 174)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: usesAccessibilityLayout ? 22 : 18) {
                        HelpDismissChevron { dismiss() }
                            .padding(.top, 8)

                        VStack(spacing: usesAccessibilityLayout ? 8 : 10) {
                            HelpHeroIllustration(animate: animateHero)
                                .frame(width: contentWidth, height: heroHeight)
                                .accessibilityHidden(true)

                            Text("A guide to BrainMail")
                                .font((usesAccessibilityLayout ? Font.title3 : Font.title2).weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: min(430, contentWidth))
                        .frame(width: contentWidth)

                        HelpSectionCard(title: "What is this app?", systemImage: "sparkles") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("BrainMail is a tool for focusing on healthy thoughts.")
                                HelpBodyText("Keep track of moments of clarity and inspiration, and they’ll be continually texted back to you to keep you in a better headspace.")
                            }
                        }

                        HelpSectionCard(title: "How do I use it?", systemImage: "pencil.and.outline") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("Challenge yourself to be more intentional about recognizing and celebrating your good thoughts.")
                                HelpBodyText("Jot them down here, and we will do the rest.")
                            }
                        }

                        HelpSectionCard(title: "How does it work?", systemImage: "shuffle") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("An algorithm selects random entries and routes them to you through a toll-free phone number based on the frequency settings you select.")
                                HelpBodyText("We never see your entries or phone number.")
                            }
                        }

                        HelpSectionCard(title: "What’s the deal with the community page?", systemImage: "person.2") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("We wanted to create a space for people to uplift others and connect if they feel so inclined.")
                                HelpBodyText("All messages are from real people. Click the flag icon to report inappropriate messages.")
                            }
                        }

                        HelpSectionCard(title: "Do I have to pay?", systemImage: "creditcard") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("All features are free to use, but we had to place some limits due to SMS backend cost.")
                                HelpBodyText("If you’d like roomier limits — 15 auto/week and unlimited instant sends — consider upgrading to Pro for $0.99/month.")
                                HelpBodyText("If you genuinely can’t pay for premium but it would improve your well-being, hit the help email and I’ll hook you up.")
                            }
                        }

                        HelpSectionCard(title: "A note from the developer", systemImage: "heart.text.square") {
                            VStack(alignment: .leading, spacing: 10) {
                                HelpBodyText("I recognize this isn’t for everyone, and that’s okay.")
                                HelpBodyText("I originally made this for myself in a deep NYC winter in an attempt to be more thoughtful, intentional, and self-kind.")
                                HelpBodyText("But it was useful for me, so I decided to share. If you’ve also tried to take account of your wandering mind in the Notes app, journaling, affirmations, etc. but nothing ever stuck, I hope this helps you too.")
                                HelpBodyText("Remember, you’re somebody’s everything :)")
                            }
                        }

                        HelpSectionCard(title: "Support/contact", systemImage: "envelope") {
                            VStack(alignment: .leading, spacing: 12) {
                                HelpBodyText("Questions, bugs, feedback, and suggestions are all welcome. Find me here:")

                                Link(destination: supportURL) {
                                    Label("brainmailhelp@gmail.com", systemImage: "paperplane.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.figmaBlue)
                                        .lineLimit(usesAccessibilityLayout ? 2 : 1)
                                        .minimumScaleFactor(0.78)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(width: contentWidth)
                    .padding(.top, usesAccessibilityLayout ? 4 : 2)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 28, 42))
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("help.scroll")
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartHeroAnimation() }
        .brainMailDynamicTypeRange()
    }

    private var supportURL: URL {
        URL(string: "mailto:brainmailhelp@gmail.com?subject=BrainMail%20Support")!
    }

    private func restartHeroAnimation() {
        animateHero = false
        DispatchQueue.main.async {
            animateHero = true
        }
    }
}

private struct HelpDismissChevron: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.36))
                .frame(width: 44, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
    }
}

private struct HelpHeroIllustration: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let logoSize = min(128, availableWidth * 0.44, availableHeight * 0.76)
            let waterWidth = min(availableWidth * 0.72, logoSize * 1.74)
            let waterHeight = max(34, logoSize * 0.34)
            let wavePhase: CGFloat = animate ? 1 : 0
            let bobOffset: CGFloat = animate ? -5 : 4
            let driftOffset: CGFloat = animate ? 3 : -3
            let tilt: Double = animate ? 2.2 : -2.0

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.figmaBlue.opacity(0.09),
                                Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.10),
                                Color.white.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: logoSize * 0.86
                        )
                    )
                    .frame(width: logoSize * 1.42, height: logoSize * 1.42)
                    .offset(y: -logoSize * 0.04)
                    .opacity(animate ? 0.95 : 0.78)
                    .animation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: animate)

                Image("BottleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                    .rotationEffect(.degrees(tilt), anchor: .center)
                    .offset(x: driftOffset, y: bobOffset - logoSize * 0.08)
                    .shadow(color: Color.figmaBlue.opacity(0.10), radius: 12, x: 0, y: 8)
                    .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: animate)

                ZStack {
                    HelpWaterWaveShape(phase: wavePhase, amplitude: waterHeight * 0.10, baseline: waterHeight * 0.36)
                        .fill(Color.figmaBlue.opacity(0.14))
                        .animation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true), value: animate)

                    HelpWaterWaveShape(phase: 1 - wavePhase, amplitude: waterHeight * 0.08, baseline: waterHeight * 0.45)
                        .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.14))
                        .offset(x: animate ? -8 : 8)
                        .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: animate)

                    HelpWaveLineShape(phase: wavePhase, amplitude: waterHeight * 0.09, baseline: waterHeight * 0.30)
                        .stroke(Color.figmaBlue.opacity(0.20), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .animation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true), value: animate)
                }
                .frame(width: waterWidth, height: waterHeight)
                .offset(x: animate ? -4 : 4, y: logoSize * 0.34)
                .mask {
                    RoundedRectangle(cornerRadius: waterHeight * 0.48, style: .continuous)
                        .frame(width: waterWidth, height: waterHeight)
                }
                .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: animate)
            }
            .frame(width: availableWidth, height: availableHeight)
            .clipped()
        }
        .clipped()
    }
}

private struct HelpWaterWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var baseline: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(rect.width / 24, 3)
        let startX = rect.minX
        let endX = rect.maxX
        let phaseRadians = Double(phase * 2 * .pi)

        path.move(to: CGPoint(x: startX, y: waveY(for: startX, in: rect, phaseRadians: phaseRadians)))

        var x = startX
        while x <= endX {
            path.addLine(to: CGPoint(x: x, y: waveY(for: x, in: rect, phaseRadians: phaseRadians)))
            x += step
        }

        path.addLine(to: CGPoint(x: endX, y: rect.maxY))
        path.addLine(to: CGPoint(x: startX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func waveY(for x: CGFloat, in rect: CGRect, phaseRadians: Double) -> CGFloat {
        let progress = rect.width > 0 ? (x - rect.minX) / rect.width : 0
        let sine = sin(Double(progress * 2 * .pi) + phaseRadians)
        return rect.minY + baseline + CGFloat(sine) * amplitude
    }
}

private struct HelpWaveLineShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var baseline: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(rect.width / 24, 3)
        let phaseRadians = Double(phase * 2 * .pi)

        path.move(to: CGPoint(x: rect.minX, y: waveY(for: rect.minX, in: rect, phaseRadians: phaseRadians)))

        var x = rect.minX
        while x <= rect.maxX {
            path.addLine(to: CGPoint(x: x, y: waveY(for: x, in: rect, phaseRadians: phaseRadians)))
            x += step
        }

        return path
    }

    private func waveY(for x: CGFloat, in rect: CGRect, phaseRadians: Double) -> CGFloat {
        let progress = rect.width > 0 ? (x - rect.minX) / rect.width : 0
        let sine = sin(Double(progress * 2 * .pi) + phaseRadians)
        return rect.minY + baseline + CGFloat(sine) * amplitude
    }
}

private struct HelpSectionCard<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    helpHeaderIcon
                    helpHeaderTitle
                }

                VStack(alignment: .leading, spacing: 8) {
                    helpHeaderIcon
                    helpHeaderTitle
                }
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

    private var helpHeaderIcon: some View {
        Image(systemName: systemImage)
            .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 18 : 16, weight: .semibold))
            .foregroundStyle(Color.figmaBlue)
            .frame(
                width: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 34 : 30,
                height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 34 : 30
            )
            .background(
                Circle()
                    .fill(Color.figmaBlue.opacity(0.09))
            )
    }

    private var helpHeaderTitle: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.80))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HelpBodyText: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(dynamicTypeSize.brainMailUsesAccessibilityLayout ? .body : .subheadline)
            .foregroundStyle(Color.black.opacity(0.62))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HelpBullet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 15 : 13, weight: .semibold))
                .foregroundStyle(Color.figmaBlue.opacity(0.86))
                .frame(
                    width: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 18,
                    height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 18
                )
                .padding(.top, 1)

            Text(text)
                .font(dynamicTypeSize.brainMailUsesAccessibilityLayout ? .body : .subheadline)
                .foregroundStyle(Color.black.opacity(0.64))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
