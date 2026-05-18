// ============================
// File: Views/Sheets/InspirationBankSheet.swift
// ============================
import SwiftUI

@MainActor
struct InspirationBankSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedCategory: InspirationCategory = .easternPhilosophy
    @State private var shuffledRemindersByCategory: [InspirationCategory: [InspirationReminder]] = [:]
    @State private var pendingReminder: InspirationReminder?
    @State private var showAddConfirmation = false
    @State private var addedReminderIDs: Set<String> = []
    @State private var toastMessage: String?
    @State private var isAdding = false

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

                VStack(spacing: usesAccessibilityLayout ? 14 : 18) {
                    InspirationBankDismissChevron { dismiss() }
                        .padding(.top, 8)

                    InspirationBankHeader(usesAccessibilityLayout: usesAccessibilityLayout)
                        .frame(width: contentWidth)

                    categoryTabs

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: usesAccessibilityLayout ? 14 : 12) {
                            ForEach(shuffledItems(in: selectedCategory)) { reminder in
                                InspirationReminderCard(
                                    reminder: reminder,
                                    isAdded: isReminderAlreadyInBank(reminder),
                                    isBusy: isAdding && pendingReminder?.id == reminder.id,
                                    usesAccessibilityLayout: usesAccessibilityLayout,
                                    onAdd: {
                                        pendingReminder = reminder
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            showAddConfirmation = true
                                        }
                                    }
                                )
                            }
                        }
                        .frame(width: contentWidth)
                        .padding(.top, usesAccessibilityLayout ? 4 : 2)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 28, 42))
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("inspiration.list")
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }

            if showAddConfirmation, let pendingReminder {
                BrainMailConfirmationOverlay(
                    title: "Add to reminder bank?",
                    message: pendingReminder.text,
                    confirmTitle: "Add",
                    cancelTitle: "Cancel",
                    symbolName: "plus",
                    onConfirm: {
                        confirmAdd(pendingReminder)
                    },
                    onCancel: cancelAdd
                )
                .transition(.opacity)
            }

            if let toastMessage {
                VStack {
                    Spacer()
                    InspirationToast(message: toastMessage)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .brainMailDynamicTypeRange()
        .onAppear {
            if shuffledRemindersByCategory.isEmpty {
                shuffleReminders()
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(InspirationCategory.allCases) { category in
                    InspirationCategoryPill(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        accessibilityID: "inspiration.category.\(category.id)"
                    ) {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("inspiration.categoryTabs")
    }

    private func isReminderAlreadyInBank(_ reminder: InspirationReminder) -> Bool {
        addedReminderIDs.contains(reminder.id) || appVM.hasActiveEntryMatching(reminder.text)
    }

    private func shuffledItems(in category: InspirationCategory) -> [InspirationReminder] {
        shuffledRemindersByCategory[category] ?? InspirationBankRepository.items(in: category)
    }

    private func shuffleReminders() {
        shuffledRemindersByCategory = Dictionary(
            uniqueKeysWithValues: InspirationCategory.allCases.map { category in
                (category, InspirationBankRepository.items(in: category).shuffled())
            }
        )
    }

    private func cancelAdd() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showAddConfirmation = false
        }
        pendingReminder = nil
    }

    private func confirmAdd(_ reminder: InspirationReminder) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showAddConfirmation = false
        }

        Task {
            await addReminder(reminder)
        }
    }

    private func addReminder(_ reminder: InspirationReminder) async {
        guard !isAdding else { return }
        isAdding = true
        pendingReminder = reminder
        defer {
            isAdding = false
            pendingReminder = nil
        }

        do {
            if appVM.hasActiveEntryMatching(reminder.text) {
                addedReminderIDs.insert(reminder.id)
                showToast("Already in your bank")
                return
            }

            try await appVM.addEntryToBank(
                text: reminder.text,
                source: "Inspiration Bank",
                sourceCategory: reminder.category.rawValue
            )
            addedReminderIDs.insert(reminder.id)
            Haptics.success()
            showToast("Added to your bank")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeInOut(duration: 0.22)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct InspirationCategoryPill: View {
    let title: String
    let isSelected: Bool
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.black.opacity(0.62))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(pillFill)
                .overlay(pillStroke)
                .shadow(
                    color: isSelected ? Color.figmaBlue.opacity(0.18) : Color.black.opacity(0.025),
                    radius: isSelected ? 12 : 7,
                    x: 0,
                    y: isSelected ? 7 : 4
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    private var pillFill: some View {
        Capsule(style: .continuous)
            .fill(isSelected ? Color.figmaBlue : Color.white.opacity(0.76))
    }

    private var pillStroke: some View {
        Capsule(style: .continuous)
            .stroke(isSelected ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
    }
}

private struct InspirationBankHeader: View {
    let usesAccessibilityLayout: Bool
    @State private var animateLight = false

    var body: some View {
        VStack(spacing: usesAccessibilityLayout ? 8 : 12) {
            if !usesAccessibilityLayout {
                InspirationLightbulbAnimation(isLit: animateLight)
                    .frame(width: 122, height: 122)
                    .onAppear(perform: restartLightAnimation)
                .accessibilityHidden(true)
            }

            VStack(spacing: 7) {
                Text("Borrow some inspiration")
                    .font((usesAccessibilityLayout ? Font.title3 : Font.title2).weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add anything that you'd want to receive later.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 430)
        }
    }

    private func restartLightAnimation() {
        animateLight = false
        DispatchQueue.main.async {
            animateLight = true
        }
    }
}

private struct InspirationBankDismissChevron: View {
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

private struct InspirationLightbulbAnimation: View {
    let isLit: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255/255, green: 244/255, blue: 187/255).opacity(isLit ? 0.34 : 0.16),
                            Color.figmaBlue.opacity(isLit ? 0.12 : 0.07),
                            Color(red: 222/255, green: 174/255, blue: 202/255).opacity(isLit ? 0.16 : 0.08),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 72
                    )
                )
                .scaleEffect(isLit ? 1.06 : 0.94)
                .opacity(isLit ? 1 : 0.78)
                .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: isLit)

            ForEach(0..<8, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.figmaBlue.opacity(isLit ? 0.20 : 0.08))
                    .frame(width: 3, height: index.isMultiple(of: 2) ? 16 : 11)
                    .offset(y: -50)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .scaleEffect(isLit ? 1.0 : 0.78, anchor: .center)
                    .animation(
                        .easeInOut(duration: 2.7)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.025),
                        value: isLit
                    )
            }

            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: 72, height: 72)
                .shadow(color: Color.figmaBlue.opacity(isLit ? 0.16 : 0.08), radius: isLit ? 18 : 9, x: 0, y: 8)
                .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: isLit)

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 43, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color(red: 255/255, green: 222/255, blue: 108/255).opacity(isLit ? 0.88 : 0.28),
                    Color.figmaBlue.opacity(isLit ? 0.96 : 0.68)
                )
                .shadow(color: Color(red: 255/255, green: 222/255, blue: 108/255).opacity(isLit ? 0.26 : 0.06), radius: isLit ? 14 : 4, x: 0, y: 4)
                .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: isLit)
        }
    }
}

private struct InspirationReminderCard: View {
    let reminder: InspirationReminder
    let isAdded: Bool
    let isBusy: Bool
    let usesAccessibilityLayout: Bool
    let onAdd: () -> Void

    var body: some View {
        Group {
            if usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: 14) {
                    cardText
                    HStack(alignment: .center) {
                        if reminder.showsSourcePill {
                            sourcePill
                        }
                        Spacer(minLength: 12)
                        addButton
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        cardText
                        if reminder.showsSourcePill {
                            sourcePill
                        }
                    }

                    Spacer(minLength: 0)
                    addButton
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var cardText: some View {
        Text(reminder.text)
            .font(.body.weight(.medium))
            .foregroundStyle(Color.black.opacity(0.78))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourcePill: some View {
        Text(reminder.sourceLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.figmaBlue.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.figmaBlue.opacity(0.08))
            )
            .accessibilityIdentifier("inspiration.source.\(reminder.id)")
            .accessibilityLabel(reminder.source)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .fill(isAdded ? Color.figmaBlue.opacity(0.12) : Color.figmaBlue)
                    .frame(width: usesAccessibilityLayout ? 48 : 42, height: usesAccessibilityLayout ? 48 : 42)
                    .shadow(color: isAdded ? Color.clear : Color.figmaBlue.opacity(0.20), radius: 12, x: 0, y: 7)

                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: usesAccessibilityLayout ? 20 : 18, weight: .bold))
                        .foregroundStyle(isAdded ? Color.figmaBlue : Color.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isAdded || isBusy)
        .accessibilityLabel(isAdded ? "Already in your reminder bank" : "Add to reminder bank")
        .accessibilityIdentifier("inspiration.add.\(reminder.id)")
    }
}

struct BrainMailConfirmationOverlay: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let symbolName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let hasMessage = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: max(proxy.safeAreaInsets.top + 24, 28))

                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.figmaBlue.opacity(0.10))
                                    .frame(width: 52, height: 52)

                                Image(systemName: symbolName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.figmaBlue)
                            }
                            .accessibilityHidden(true)

                            VStack(spacing: hasMessage ? 8 : 0) {
                                Text(title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.78))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)

                                if hasMessage {
                                    Text(message)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.black.opacity(0.58))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            VStack(spacing: 10) {
                                Button(action: onConfirm) {
                                    Text(confirmTitle)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 50)
                                        .background(Color.figmaBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Button(action: onCancel) {
                                    Text(cancelTitle)
                                        .font(.headline)
                                        .foregroundStyle(Color.black.opacity(0.62))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 50)
                                        .background(Color.white.opacity(0.74))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: 340)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.90), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 14)
                        .padding(.horizontal, 24)

                        Spacer(minLength: max(proxy.safeAreaInsets.bottom + 24, 28))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct InspirationToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.figmaBlue)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 9)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
    }
}

private enum InspirationCategory: String, CaseIterable, Identifiable {
    case easternPhilosophy = "Eastern Philosophy"
    case writersPoets = "Writers & Poets"
    case stoicism = "Stoicism"
    case christian = "Christian"
    case discipline = "Discipline"
    case mindfulness = "Mindfulness"
    case anxietyOverthinking = "Anxiety & overthinking"
    case selfWorth = "Self-worth"
    case developerFavorites = "Developer's favorites"

    var id: String { rawValue }
}

private struct InspirationReminder: Identifiable, Equatable {
    let id: String
    let category: InspirationCategory
    let text: String
    let source: String
    let sourceLabel: String

    var isDeveloperFavorite: Bool { category == .developerFavorites }
    var showsSourcePill: Bool { !isDeveloperFavorite && !sourceLabel.isEmpty }
}

private enum InspirationBankRepository {
    static func items(in category: InspirationCategory) -> [InspirationReminder] {
        reminders.filter { $0.category == category }
    }

    static let reminders: [InspirationReminder] = [
        InspirationReminder(id: "writers-poets-1", category: .writersPoets, text: "There is nothing either good or bad, but thinking makes it so.", source: "William Shakespeare, Hamlet", sourceLabel: "William Shakespeare"),
        InspirationReminder(id: "writers-poets-4", category: .writersPoets, text: "Our doubts are traitors.", source: "William Shakespeare, Measure for Measure", sourceLabel: "William Shakespeare"),
        InspirationReminder(id: "writers-poets-7", category: .writersPoets, text: "Love all, trust a few, do wrong to none.", source: "William Shakespeare, All's Well That Ends Well", sourceLabel: "William Shakespeare"),
        InspirationReminder(id: "writers-poets-8", category: .writersPoets, text: "How far that little candle throws his beams!", source: "William Shakespeare, The Merchant of Venice", sourceLabel: "William Shakespeare"),
        InspirationReminder(id: "writers-poets-14", category: .writersPoets, text: "Dwell in possibility.", source: "Emily Dickinson, poem 466", sourceLabel: "Emily Dickinson"),
        InspirationReminder(id: "writers-poets-15", category: .writersPoets, text: "The soul should always stand ajar.", source: "Emily Dickinson, poem 1055", sourceLabel: "Emily Dickinson"),
        InspirationReminder(id: "writers-poets-18", category: .writersPoets, text: "That it will never come again is what makes life so sweet.", source: "Emily Dickinson, poem 1741", sourceLabel: "Emily Dickinson"),
        InspirationReminder(id: "writers-poets-21", category: .writersPoets, text: "Keep your face always toward the sunshine.", source: "Walt Whitman, attributed", sourceLabel: "Walt Whitman"),
        InspirationReminder(id: "writers-poets-22", category: .writersPoets, text: "The powerful play goes on, and you may contribute a verse.", source: "Walt Whitman, O Me! O Life!", sourceLabel: "Walt Whitman"),
        InspirationReminder(id: "writers-poets-23", category: .writersPoets, text: "I exist as I am, that is enough.", source: "Walt Whitman, Song of Myself", sourceLabel: "Walt Whitman"),
        InspirationReminder(id: "writers-poets-24", category: .writersPoets, text: "Be curious, not judgmental.", source: "Walt Whitman, attributed", sourceLabel: "Walt Whitman"),
        InspirationReminder(id: "writers-poets-25", category: .writersPoets, text: "Simplicity, simplicity, simplicity!", source: "Henry David Thoreau, Walden", sourceLabel: "Henry David Thoreau"),
        InspirationReminder(id: "writers-poets-26", category: .writersPoets, text: "Go confidently in the direction of your dreams.", source: "Henry David Thoreau, Walden, commonly paraphrased", sourceLabel: "Henry David Thoreau"),
        InspirationReminder(id: "writers-poets-31", category: .writersPoets, text: "No bird soars too high if he soars with his own wings.", source: "William Blake, The Marriage of Heaven and Hell", sourceLabel: "William Blake"),
        InspirationReminder(id: "writers-poets-34", category: .writersPoets, text: "To be great is to be misunderstood.", source: "Ralph Waldo Emerson, Self-Reliance", sourceLabel: "Ralph Waldo Emerson"),
        InspirationReminder(id: "writers-poets-38", category: .writersPoets, text: "If Winter comes, can Spring be far behind?", source: "Percy Bysshe Shelley, Ode to the West Wind", sourceLabel: "Percy Bysshe Shelley"),
        InspirationReminder(id: "writers-poets-39", category: .writersPoets, text: "Our sweetest songs are those that tell of saddest thought.", source: "Percy Bysshe Shelley, To a Skylark", sourceLabel: "Percy Bysshe Shelley"),
        InspirationReminder(id: "writers-poets-44", category: .writersPoets, text: "Strong in will to strive, to seek, to find.", source: "Alfred, Lord Tennyson, Ulysses", sourceLabel: "Tennyson"),
        InspirationReminder(id: "writers-poets-48", category: .writersPoets, text: "Grow old along with me! The best is yet to be.", source: "Robert Browning, Rabbi Ben Ezra", sourceLabel: "Robert Browning"),
        InspirationReminder(id: "eastern-philosophy-1", category: .easternPhilosophy, text: "Nature does not hurry, yet everything is accomplished.", source: "Lao Tzu, Tao Te Ching, attributed", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-3", category: .easternPhilosophy, text: "He who knows others is wise; he who knows himself is enlightened.", source: "Lao Tzu, Tao Te Ching, ch. 33", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-4", category: .easternPhilosophy, text: "Mastering others is strength; mastering yourself is true power.", source: "Lao Tzu, Tao Te Ching, ch. 33", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-5", category: .easternPhilosophy, text: "A good traveler has no fixed plans.", source: "Lao Tzu, Tao Te Ching, ch. 27", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-7", category: .easternPhilosophy, text: "To know that you do not know is best.", source: "Lao Tzu, Tao Te Ching, ch. 71", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-8", category: .easternPhilosophy, text: "When I let go of what I am, I become what I might be.", source: "Lao Tzu, attributed", sourceLabel: "Lao Tzu"),
        InspirationReminder(id: "eastern-philosophy-9", category: .easternPhilosophy, text: "Be content with what you have.", source: "Lao Tzu, Tao Te Ching, ch. 44, paraphrase", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-10", category: .easternPhilosophy, text: "A bowl is useful because it is empty.", source: "Lao Tzu, Tao Te Ching, ch. 11, paraphrase", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-11", category: .easternPhilosophy, text: "The wise man is one who knows what he does not know.", source: "Lao Tzu, Tao Te Ching, paraphrase", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-12", category: .easternPhilosophy, text: "Water benefits all things and does not compete.", source: "Lao Tzu, Tao Te Ching, ch. 8", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-14", category: .easternPhilosophy, text: "Act without striving.", source: "Lao Tzu, Tao Te Ching, wu wei teaching", sourceLabel: "Tao Te Ching"),
        InspirationReminder(id: "eastern-philosophy-17", category: .easternPhilosophy, text: "Mind precedes all things.", source: "The Dhammapada, verse 1", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-18", category: .easternPhilosophy, text: "Hatred is never appeased by hatred.", source: "The Dhammapada, verse 5", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-19", category: .easternPhilosophy, text: "As rain falls through a badly thatched house, passion enters an untrained mind.", source: "The Dhammapada, verse 13", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-20", category: .easternPhilosophy, text: "The disciplined mind brings happiness.", source: "The Dhammapada, verse 35", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-21", category: .easternPhilosophy, text: "The wise shape themselves.", source: "The Dhammapada, verse 80", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-22", category: .easternPhilosophy, text: "Health is the greatest gift.", source: "The Dhammapada, verse 204", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-23", category: .easternPhilosophy, text: "Contentment is the greatest wealth.", source: "The Dhammapada, verse 204", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-24", category: .easternPhilosophy, text: "Conquer anger by non-anger.", source: "The Dhammapada, verse 223", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-25", category: .easternPhilosophy, text: "Let none find fault with others.", source: "The Dhammapada, verse 50", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-26", category: .easternPhilosophy, text: "Victory breeds hatred.", source: "The Dhammapada, verse 201", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-27", category: .easternPhilosophy, text: "Peacefully shall we live.", source: "The Dhammapada, verse 197", sourceLabel: "Dhammapada"),
        InspirationReminder(id: "eastern-philosophy-28", category: .easternPhilosophy, text: "To conquer oneself is a greater task than conquering others.", source: "Buddhist saying, attributed to the Buddha", sourceLabel: "Buddhist saying"),
        InspirationReminder(id: "eastern-philosophy-29", category: .easternPhilosophy, text: "If you light a lamp for somebody, it will also brighten your path.", source: "Buddhist saying, attributed to the Buddha", sourceLabel: "Buddhist saying"),
        InspirationReminder(id: "eastern-philosophy-30", category: .easternPhilosophy, text: "The foot feels the foot when it feels the ground.", source: "Buddhist proverb", sourceLabel: "Buddhist proverb"),
        InspirationReminder(id: "eastern-philosophy-31", category: .easternPhilosophy, text: "The obstacle is the path.", source: "Zen proverb", sourceLabel: "Zen proverb"),
        InspirationReminder(id: "eastern-philosophy-32", category: .easternPhilosophy, text: "When walking, walk. When eating, eat.", source: "Zen proverb", sourceLabel: "Zen proverb"),
        InspirationReminder(id: "eastern-philosophy-33", category: .easternPhilosophy, text: "Before enlightenment, chop wood, carry water.", source: "Zen proverb", sourceLabel: "Zen proverb"),
        InspirationReminder(id: "eastern-philosophy-34", category: .easternPhilosophy, text: "After enlightenment, chop wood, carry water.", source: "Zen proverb", sourceLabel: "Zen proverb"),
        InspirationReminder(id: "eastern-philosophy-35", category: .easternPhilosophy, text: "Sitting quietly, doing nothing, spring comes.", source: "Zen saying", sourceLabel: "Zen saying"),
        InspirationReminder(id: "eastern-philosophy-36", category: .easternPhilosophy, text: "Still water reflects clearly.", source: "Zen proverb", sourceLabel: "Zen proverb"),
        InspirationReminder(id: "eastern-philosophy-37", category: .easternPhilosophy, text: "The mind is everything; what you think, you become.", source: "Buddhist saying, attributed", sourceLabel: "Buddhist saying"),
        InspirationReminder(id: "eastern-philosophy-38", category: .easternPhilosophy, text: "We are here to awaken from the illusion of separateness.", source: "Thich Nhat Hanh, attributed", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "eastern-philosophy-39", category: .easternPhilosophy, text: "Perform your duty with a balanced mind.", source: "Bhagavad Gita, 2:48, paraphrase", sourceLabel: "Bhagavad Gita"),
        InspirationReminder(id: "eastern-philosophy-40", category: .easternPhilosophy, text: "The self-controlled soul attains peace.", source: "Bhagavad Gita, 2:64, paraphrase", sourceLabel: "Bhagavad Gita"),
        InspirationReminder(id: "eastern-philosophy-41", category: .easternPhilosophy, text: "The journey itself is home.", source: "Matsuo Basho", sourceLabel: "Matsuo Basho"),
        InspirationReminder(id: "eastern-philosophy-42", category: .easternPhilosophy, text: "Do not seek to follow in the footsteps of the wise.", source: "Matsuo Basho", sourceLabel: "Matsuo Basho"),
        InspirationReminder(id: "eastern-philosophy-43", category: .easternPhilosophy, text: "Flow with whatever may happen.", source: "Zhuangzi", sourceLabel: "Zhuangzi"),
        InspirationReminder(id: "eastern-philosophy-44", category: .easternPhilosophy, text: "Happiness is the absence of the striving for happiness.", source: "Zhuangzi, attributed", sourceLabel: "Zhuangzi"),
        InspirationReminder(id: "eastern-philosophy-45", category: .easternPhilosophy, text: "The perfect man employs his mind as a mirror.", source: "Zhuangzi", sourceLabel: "Zhuangzi"),
        InspirationReminder(id: "eastern-philosophy-46", category: .easternPhilosophy, text: "Wherever you go, go with all your heart.", source: "Confucius, attributed", sourceLabel: "Confucius"),
        InspirationReminder(id: "eastern-philosophy-47", category: .easternPhilosophy, text: "It does not matter how slowly you go as long as you do not stop.", source: "Confucius, attributed", sourceLabel: "Confucius"),
        InspirationReminder(id: "eastern-philosophy-48", category: .easternPhilosophy, text: "Our greatest glory is not in never falling.", source: "Confucius, attributed", sourceLabel: "Confucius"),
        InspirationReminder(id: "eastern-philosophy-49", category: .easternPhilosophy, text: "The man who moves a mountain begins by carrying away small stones.", source: "Confucius, attributed", sourceLabel: "Confucius"),
        InspirationReminder(id: "stoicism-1", category: .stoicism, text: "You have power over your mind - not outside events.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-2", category: .stoicism, text: "The happiness of your life depends upon the quality of your thoughts.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-3", category: .stoicism, text: "Waste no more time arguing what a good man should be. Be one.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-4", category: .stoicism, text: "The best revenge is not to be like your enemy.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-5", category: .stoicism, text: "If it is not right, do not do it.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-6", category: .stoicism, text: "If it is not true, do not say it.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-7", category: .stoicism, text: "Very little is needed to make a happy life.", source: "Marcus Aurelius, Meditations, attributed", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-8", category: .stoicism, text: "The obstacle becomes the way.", source: "Marcus Aurelius, Meditations, paraphrase", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-9", category: .stoicism, text: "Receive without pride, let go without attachment.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-10", category: .stoicism, text: "What we do now echoes in eternity.", source: "Marcus Aurelius, attributed", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-11", category: .stoicism, text: "The soul becomes dyed with the color of its thoughts.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-12", category: .stoicism, text: "Confine yourself to the present.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-13", category: .stoicism, text: "Be tolerant with others and strict with yourself.", source: "Marcus Aurelius, Meditations, paraphrase", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-14", category: .stoicism, text: "The universe is change; our life is what our thoughts make it.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-15", category: .stoicism, text: "Look well into thyself.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-16", category: .stoicism, text: "Dwell on the beauty of life.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-17", category: .stoicism, text: "The art of living is more like wrestling than dancing.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-18", category: .stoicism, text: "Choose not to be harmed, and you won't feel harmed.", source: "Marcus Aurelius, Meditations, paraphrase", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-19", category: .stoicism, text: "Reject your sense of injury and the injury disappears.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-20", category: .stoicism, text: "No random actions, none not based on underlying principles.", source: "Marcus Aurelius, Meditations", sourceLabel: "Marcus Aurelius"),
        InspirationReminder(id: "stoicism-21", category: .stoicism, text: "We suffer more often in imagination than in reality.", source: "Seneca, Letters from a Stoic", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-22", category: .stoicism, text: "He suffers more than necessary who suffers before it is necessary.", source: "Seneca, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-23", category: .stoicism, text: "Difficulties strengthen the mind, as labor does the body.", source: "Seneca, Letters from a Stoic", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-24", category: .stoicism, text: "Luck is what happens when preparation meets opportunity.", source: "Seneca, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-25", category: .stoicism, text: "No man is more unhappy than he who never faces adversity.", source: "Seneca, On Providence", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-26", category: .stoicism, text: "Begin at once to live.", source: "Seneca, On the Shortness of Life", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-27", category: .stoicism, text: "While we wait for life, life passes.", source: "Seneca, On the Shortness of Life", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-28", category: .stoicism, text: "It is not that we have a short time to live, but that we waste much of it.", source: "Seneca, On the Shortness of Life", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-29", category: .stoicism, text: "Associate with people who are likely to improve you.", source: "Seneca, Letters from a Stoic", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-30", category: .stoicism, text: "Every new beginning comes from some other beginning's end.", source: "Seneca, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-31", category: .stoicism, text: "No wind favors him who has no destined port.", source: "Seneca, Letters from a Stoic", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-32", category: .stoicism, text: "Fire tests gold, suffering tests brave men.", source: "Seneca, On Providence", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-33", category: .stoicism, text: "To bear trials with a calm mind robs misfortune of its strength.", source: "Seneca, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-34", category: .stoicism, text: "A gem cannot be polished without friction.", source: "Seneca, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-35", category: .stoicism, text: "It is a rough road that leads to the heights of greatness.", source: "Seneca, Letters from a Stoic, attributed", sourceLabel: "Seneca"),
        InspirationReminder(id: "stoicism-36", category: .stoicism, text: "It's not what happens to you, but how you react to it that matters.", source: "Epictetus, Enchiridion, paraphrase", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-37", category: .stoicism, text: "Some things are up to us and some are not.", source: "Epictetus, Enchiridion", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-38", category: .stoicism, text: "No man is free who is not master of himself.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-39", category: .stoicism, text: "First say to yourself what you would be.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-40", category: .stoicism, text: "Then do what you have to do.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-41", category: .stoicism, text: "Difficulty shows what men are.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-42", category: .stoicism, text: "Circumstances don't make the man, they only reveal him.", source: "Epictetus, attributed", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-43", category: .stoicism, text: "Don't explain your philosophy. Embody it.", source: "Epictetus, attributed", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-44", category: .stoicism, text: "Freedom is the only worthy goal in life.", source: "Epictetus, Discourses, paraphrase", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-45", category: .stoicism, text: "No great thing is created suddenly.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-46", category: .stoicism, text: "If you want to improve, be content to be thought foolish.", source: "Epictetus, Enchiridion", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-47", category: .stoicism, text: "It is impossible to begin to learn that which one thinks one already knows.", source: "Epictetus, Discourses", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-48", category: .stoicism, text: "The key is to keep company only with people who uplift you.", source: "Epictetus, attributed", sourceLabel: "Epictetus"),
        InspirationReminder(id: "stoicism-49", category: .stoicism, text: "The willing are led by fate, the reluctant dragged.", source: "Cleanthes, Hymn to Zeus, attributed", sourceLabel: "Cleanthes"),
        InspirationReminder(id: "stoicism-50", category: .stoicism, text: "Fate guides the willing, drags the unwilling.", source: "Cleanthes / Stoic maxim", sourceLabel: "Cleanthes"),
        InspirationReminder(id: "christian-1", category: .christian, text: "Be still, and know that I am God.", source: "Psalm 46:10, KJV", sourceLabel: "Psalm 46:10"),
        InspirationReminder(id: "christian-2", category: .christian, text: "The Lord is my shepherd; I shall not want.", source: "Psalm 23:1, KJV", sourceLabel: "Psalm 23:1"),
        InspirationReminder(id: "christian-3", category: .christian, text: "He restoreth my soul.", source: "Psalm 23:3, KJV", sourceLabel: "Psalm 23:3"),
        InspirationReminder(id: "christian-4", category: .christian, text: "The Lord is my light and my salvation.", source: "Psalm 27:1, KJV", sourceLabel: "Psalm 27:1"),
        InspirationReminder(id: "christian-5", category: .christian, text: "Wait on the Lord: be of good courage.", source: "Psalm 27:14, KJV", sourceLabel: "Psalm 27:14"),
        InspirationReminder(id: "christian-6", category: .christian, text: "The Lord is nigh unto them that are of a broken heart.", source: "Psalm 34:18, KJV", sourceLabel: "Psalm 34:18"),
        InspirationReminder(id: "christian-7", category: .christian, text: "Delight thyself also in the Lord.", source: "Psalm 37:4, KJV", sourceLabel: "Psalm 37:4"),
        InspirationReminder(id: "christian-8", category: .christian, text: "Create in me a clean heart, O God.", source: "Psalm 51:10, KJV", sourceLabel: "Psalm 51:10"),
        InspirationReminder(id: "christian-9", category: .christian, text: "In God have I put my trust: I will not be afraid.", source: "Psalm 56:11, KJV", sourceLabel: "Psalm 56:11"),
        InspirationReminder(id: "christian-10", category: .christian, text: "When my heart is overwhelmed: lead me to the rock.", source: "Psalm 61:2, KJV", sourceLabel: "Psalm 61:2"),
        InspirationReminder(id: "christian-11", category: .christian, text: "My soul, wait thou only upon God.", source: "Psalm 62:5, KJV", sourceLabel: "Psalm 62:5"),
        InspirationReminder(id: "christian-12", category: .christian, text: "Thy word is a lamp unto my feet.", source: "Psalm 119:105, KJV", sourceLabel: "Psalm 119:105"),
        InspirationReminder(id: "christian-13", category: .christian, text: "This is the day which the Lord hath made.", source: "Psalm 118:24, KJV", sourceLabel: "Psalm 118:24"),
        InspirationReminder(id: "christian-14", category: .christian, text: "The joy of the Lord is your strength.", source: "Nehemiah 8:10, KJV", sourceLabel: "Nehemiah 8:10"),
        InspirationReminder(id: "christian-15", category: .christian, text: "Trust in the Lord with all thine heart.", source: "Proverbs 3:5, KJV", sourceLabel: "Proverbs 3:5"),
        InspirationReminder(id: "christian-16", category: .christian, text: "In all thy ways acknowledge him.", source: "Proverbs 3:6, KJV", sourceLabel: "Proverbs 3:6"),
        InspirationReminder(id: "christian-17", category: .christian, text: "Keep thy heart with all diligence.", source: "Proverbs 4:23, KJV", sourceLabel: "Proverbs 4:23"),
        InspirationReminder(id: "christian-18", category: .christian, text: "A soft answer turneth away wrath.", source: "Proverbs 15:1, KJV", sourceLabel: "Proverbs 15:1"),
        InspirationReminder(id: "christian-19", category: .christian, text: "Commit thy works unto the Lord.", source: "Proverbs 16:3, KJV", sourceLabel: "Proverbs 16:3"),
        InspirationReminder(id: "christian-20", category: .christian, text: "A merry heart doeth good like a medicine.", source: "Proverbs 17:22, KJV", sourceLabel: "Proverbs 17:22"),
        InspirationReminder(id: "christian-21", category: .christian, text: "The righteous are bold as a lion.", source: "Proverbs 28:1, KJV", sourceLabel: "Proverbs 28:1"),
        InspirationReminder(id: "christian-22", category: .christian, text: "Fear thou not; for I am with thee.", source: "Isaiah 41:10, KJV", sourceLabel: "Isaiah 41:10"),
        InspirationReminder(id: "christian-23", category: .christian, text: "They that wait upon the Lord shall renew their strength.", source: "Isaiah 40:31, KJV", sourceLabel: "Isaiah 40:31"),
        InspirationReminder(id: "christian-24", category: .christian, text: "I will make darkness light before them.", source: "Isaiah 42:16, KJV", sourceLabel: "Isaiah 42:16"),
        InspirationReminder(id: "christian-25", category: .christian, text: "When thou passest through the waters, I will be with thee.", source: "Isaiah 43:2, KJV", sourceLabel: "Isaiah 43:2"),
        InspirationReminder(id: "christian-26", category: .christian, text: "I have loved thee with an everlasting love.", source: "Jeremiah 31:3, KJV", sourceLabel: "Jeremiah 31:3"),
        InspirationReminder(id: "christian-27", category: .christian, text: "The Lord is my portion, saith my soul.", source: "Lamentations 3:24, KJV", sourceLabel: "Lamentations 3:24"),
        InspirationReminder(id: "christian-28", category: .christian, text: "His compassions fail not.", source: "Lamentations 3:22, KJV", sourceLabel: "Lamentations 3:22"),
        InspirationReminder(id: "christian-29", category: .christian, text: "They are new every morning.", source: "Lamentations 3:23, KJV", sourceLabel: "Lamentations 3:23"),
        InspirationReminder(id: "christian-30", category: .christian, text: "The just shall live by his faith.", source: "Habakkuk 2:4, KJV", sourceLabel: "Habakkuk 2:4"),
        InspirationReminder(id: "christian-31", category: .christian, text: "Blessed are the poor in spirit.", source: "Matthew 5:3, KJV", sourceLabel: "Matthew 5:3"),
        InspirationReminder(id: "christian-32", category: .christian, text: "Blessed are the meek.", source: "Matthew 5:5, KJV", sourceLabel: "Matthew 5:5"),
        InspirationReminder(id: "christian-33", category: .christian, text: "Blessed are the peacemakers.", source: "Matthew 5:9, KJV", sourceLabel: "Matthew 5:9"),
        InspirationReminder(id: "christian-34", category: .christian, text: "Ye are the light of the world.", source: "Matthew 5:14, KJV", sourceLabel: "Matthew 5:14"),
        InspirationReminder(id: "christian-35", category: .christian, text: "Let your light so shine before men.", source: "Matthew 5:16, KJV", sourceLabel: "Matthew 5:16"),
        InspirationReminder(id: "christian-36", category: .christian, text: "Ask, and it shall be given you.", source: "Matthew 7:7, KJV", sourceLabel: "Matthew 7:7"),
        InspirationReminder(id: "christian-37", category: .christian, text: "With God all things are possible.", source: "Matthew 19:26, KJV", sourceLabel: "Matthew 19:26"),
        InspirationReminder(id: "christian-41", category: .christian, text: "Peace, be still.", source: "Mark 4:39, KJV", sourceLabel: "Mark 4:39"),
        InspirationReminder(id: "christian-42", category: .christian, text: "The truth shall make you free.", source: "John 8:32, KJV", sourceLabel: "John 8:32"),
        InspirationReminder(id: "christian-43", category: .christian, text: "I am the light of the world.", source: "John 8:12, KJV", sourceLabel: "John 8:12"),
        InspirationReminder(id: "christian-44", category: .christian, text: "Let not your heart be troubled.", source: "John 14:1, KJV", sourceLabel: "John 14:1"),
        InspirationReminder(id: "christian-45", category: .christian, text: "Peace I leave with you.", source: "John 14:27, KJV", sourceLabel: "John 14:27"),
        InspirationReminder(id: "christian-46", category: .christian, text: "The light shineth in darkness.", source: "John 1:5, KJV", sourceLabel: "John 1:5"),
        InspirationReminder(id: "christian-47", category: .christian, text: "We walk by faith, not by sight.", source: "2 Corinthians 5:7, KJV", sourceLabel: "2 Corinthians 5:7"),
        InspirationReminder(id: "christian-48", category: .christian, text: "My grace is sufficient for thee.", source: "2 Corinthians 12:9, KJV", sourceLabel: "2 Corinthians 12:9"),
        InspirationReminder(id: "christian-49", category: .christian, text: "I can do all things through Christ.", source: "Philippians 4:13, KJV", sourceLabel: "Philippians 4:13"),
        InspirationReminder(id: "christian-50", category: .christian, text: "Perfect love casteth out fear.", source: "1 John 4:18, KJV", sourceLabel: "1 John 4:18"),
        InspirationReminder(id: "christian-51", category: .christian, text: "You have made us for yourself, O Lord.", source: "Augustine, Confessions", sourceLabel: "Augustine"),
        InspirationReminder(id: "christian-52", category: .christian, text: "Our heart is restless until it rests in you.", source: "Augustine, Confessions", sourceLabel: "Augustine"),
        InspirationReminder(id: "christian-53", category: .christian, text: "Love, and do what you will.", source: "Augustine, Homily on 1 John", sourceLabel: "Augustine"),
        InspirationReminder(id: "christian-54", category: .christian, text: "Pray as though everything depended on God.", source: "Augustine, attributed", sourceLabel: "Augustine"),
        InspirationReminder(id: "christian-55", category: .christian, text: "The glory of God is man fully alive.", source: "Irenaeus, Against Heresies", sourceLabel: "Irenaeus"),
        InspirationReminder(id: "christian-56", category: .christian, text: "The world is thy ship and not thy home.", source: "Therese of Lisieux, attributed", sourceLabel: "Therese of Lisieux"),
        InspirationReminder(id: "christian-57", category: .christian, text: "Do small things with great love.", source: "Mother Teresa, attributed", sourceLabel: "Mother Teresa"),
        InspirationReminder(id: "christian-58", category: .christian, text: "Prayer enlarges the heart.", source: "Mother Teresa, attributed", sourceLabel: "Mother Teresa"),
        InspirationReminder(id: "christian-59", category: .christian, text: "Peace begins with a smile.", source: "Mother Teresa, attributed", sourceLabel: "Mother Teresa"),
        InspirationReminder(id: "christian-60", category: .christian, text: "Aim at Heaven and you will get earth thrown in.", source: "C.S. Lewis, Mere Christianity", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-61", category: .christian, text: "Humility is not thinking less of yourself.", source: "C.S. Lewis, Mere Christianity, paraphrase", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-62", category: .christian, text: "You are never too old to set another goal.", source: "C.S. Lewis, attributed", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-63", category: .christian, text: "Hardships often prepare ordinary people for an extraordinary destiny.", source: "C.S. Lewis, attributed", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-64", category: .christian, text: "Relying on God has to begin all over again every day.", source: "C.S. Lewis, Letters to Malcolm", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-65", category: .christian, text: "God whispers to us in our pleasures.", source: "C.S. Lewis, The Problem of Pain", sourceLabel: "C.S. Lewis"),
        InspirationReminder(id: "christian-67", category: .christian, text: "The fullness of joy is to behold God in everything.", source: "Julian of Norwich", sourceLabel: "Julian of Norwich"),
        InspirationReminder(id: "discipline-1", category: .discipline, text: "Well done is better than well said.", source: "Benjamin Franklin, Poor Richard's Almanack", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-2", category: .discipline, text: "Energy and persistence conquer all things.", source: "Benjamin Franklin", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-3", category: .discipline, text: "Diligence is the mother of good luck.", source: "Benjamin Franklin, Poor Richard's Almanack", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-4", category: .discipline, text: "No gains without pains.", source: "Benjamin Franklin, Poor Richard's Almanack", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-5", category: .discipline, text: "Lost time is never found again.", source: "Benjamin Franklin, Poor Richard's Almanack", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-7", category: .discipline, text: "Never leave that till tomorrow which you can do today.", source: "Benjamin Franklin, Poor Richard's Almanack", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-8", category: .discipline, text: "By failing to prepare, you are preparing to fail.", source: "Benjamin Franklin, attributed", sourceLabel: "Benjamin Franklin"),
        InspirationReminder(id: "discipline-13", category: .discipline, text: "Nothing in the world is worth having unless it means effort.", source: "Theodore Roosevelt", sourceLabel: "Theodore Roosevelt"),
        InspirationReminder(id: "discipline-14", category: .discipline, text: "Far and away the best prize that life offers is work worth doing.", source: "Theodore Roosevelt", sourceLabel: "Theodore Roosevelt"),
        InspirationReminder(id: "discipline-15", category: .discipline, text: "The credit belongs to the man who is actually in the arena.", source: "Theodore Roosevelt, Citizenship in a Republic", sourceLabel: "Theodore Roosevelt"),
        InspirationReminder(id: "discipline-17", category: .discipline, text: "Success is a journey, not a destination.", source: "Arthur Ashe, attributed", sourceLabel: "Arthur Ashe"),
        InspirationReminder(id: "discipline-19", category: .discipline, text: "Action cures fear.", source: "David J. Schwartz, The Magic of Thinking Big", sourceLabel: "David J. Schwartz"),
        InspirationReminder(id: "discipline-20", category: .discipline, text: "The secret of getting ahead is getting started.", source: "Mark Twain, attributed", sourceLabel: "Mark Twain"),
        InspirationReminder(id: "discipline-21", category: .discipline, text: "The way to get started is to quit talking and begin doing.", source: "Walt Disney", sourceLabel: "Walt Disney"),
        InspirationReminder(id: "discipline-22", category: .discipline, text: "Great things are done by a series of small things brought together.", source: "Vincent van Gogh", sourceLabel: "Vincent van Gogh"),
        InspirationReminder(id: "discipline-23", category: .discipline, text: "What would life be if we had no courage to attempt anything?", source: "Vincent van Gogh", sourceLabel: "Vincent van Gogh"),
        InspirationReminder(id: "discipline-24", category: .discipline, text: "If you hear a voice within you say you cannot paint, then paint.", source: "Vincent van Gogh", sourceLabel: "Vincent van Gogh"),
        InspirationReminder(id: "discipline-25", category: .discipline, text: "Genius is one percent inspiration and ninety-nine percent perspiration.", source: "Thomas Edison", sourceLabel: "Thomas Edison"),
        InspirationReminder(id: "discipline-27", category: .discipline, text: "There is no substitute for hard work.", source: "Thomas Edison", sourceLabel: "Thomas Edison"),
        InspirationReminder(id: "discipline-28", category: .discipline, text: "I have not failed. I've just found 10,000 ways that won't work.", source: "Thomas Edison", sourceLabel: "Thomas Edison"),
        InspirationReminder(id: "discipline-29", category: .discipline, text: "Our greatest weakness lies in giving up.", source: "Thomas Edison", sourceLabel: "Thomas Edison"),
        InspirationReminder(id: "discipline-30", category: .discipline, text: "Fall seven times and stand up eight.", source: "Japanese proverb", sourceLabel: "Japanese proverb"),
        InspirationReminder(id: "discipline-31", category: .discipline, text: "Success is the sum of small efforts repeated day in and day out.", source: "Robert Collier", sourceLabel: "Robert Collier"),
        InspirationReminder(id: "discipline-32", category: .discipline, text: "A year from now you may wish you had started today.", source: "Karen Lamb", sourceLabel: "Karen Lamb"),
        InspirationReminder(id: "discipline-33", category: .discipline, text: "Discipline is the bridge between goals and accomplishment.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-34", category: .discipline, text: "Either you run the day or the day runs you.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-35", category: .discipline, text: "Motivation is what gets you started. Habit is what keeps you going.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-36", category: .discipline, text: "We must all suffer one of two things: discipline or regret.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-37", category: .discipline, text: "Success is nothing more than a few simple disciplines practiced every day.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-38", category: .discipline, text: "Don't wish it were easier; wish you were better.", source: "Jim Rohn", sourceLabel: "Jim Rohn"),
        InspirationReminder(id: "discipline-39", category: .discipline, text: "Dreams don't work unless you do.", source: "John C. Maxwell", sourceLabel: "John C. Maxwell"),
        InspirationReminder(id: "discipline-40", category: .discipline, text: "Small disciplines repeated with consistency lead to great achievements.", source: "John C. Maxwell", sourceLabel: "John C. Maxwell"),
        InspirationReminder(id: "discipline-41", category: .discipline, text: "Motivation gets you going, discipline keeps you growing.", source: "John C. Maxwell", sourceLabel: "John C. Maxwell"),
        InspirationReminder(id: "discipline-42", category: .discipline, text: "You will never change your life until you change something you do daily.", source: "John C. Maxwell", sourceLabel: "John C. Maxwell"),
        InspirationReminder(id: "discipline-43", category: .discipline, text: "The secret of your success is found in your daily routine.", source: "John C. Maxwell", sourceLabel: "John C. Maxwell"),
        InspirationReminder(id: "discipline-44", category: .discipline, text: "Success is the progressive realization of a worthy goal.", source: "Earl Nightingale", sourceLabel: "Earl Nightingale"),
        InspirationReminder(id: "discipline-45", category: .discipline, text: "We become what we think about.", source: "Earl Nightingale", sourceLabel: "Earl Nightingale"),
        InspirationReminder(id: "discipline-46", category: .discipline, text: "All you need is the plan, the road map, and the courage to press on.", source: "Earl Nightingale", sourceLabel: "Earl Nightingale"),
        InspirationReminder(id: "discipline-47", category: .discipline, text: "The future depends on what you do today.", source: "Mahatma Gandhi, attributed", sourceLabel: "Mahatma Gandhi"),
        InspirationReminder(id: "discipline-48", category: .discipline, text: "Strength does not come from physical capacity.", source: "Mahatma Gandhi, attributed", sourceLabel: "Mahatma Gandhi"),
        InspirationReminder(id: "discipline-49", category: .discipline, text: "Satisfaction lies in the effort, not in the attainment.", source: "Mahatma Gandhi", sourceLabel: "Mahatma Gandhi"),
        InspirationReminder(id: "discipline-50", category: .discipline, text: "The difference between ordinary and extraordinary is that little extra.", source: "Jimmy Johnson, attributed", sourceLabel: "Jimmy Johnson"),
        InspirationReminder(id: "mindfulness-1", category: .mindfulness, text: "Wherever you are, be there totally.", source: "Eckhart Tolle, The Power of Now", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-2", category: .mindfulness, text: "Realize deeply that the present moment is all you have.", source: "Eckhart Tolle, The Power of Now", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-3", category: .mindfulness, text: "Life is now.", source: "Eckhart Tolle, The Power of Now", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-4", category: .mindfulness, text: "Awareness is the greatest agent for change.", source: "Eckhart Tolle, A New Earth", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-5", category: .mindfulness, text: "Worry pretends to be necessary but serves no useful purpose.", source: "Eckhart Tolle, A New Earth", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-6", category: .mindfulness, text: "The primary cause of unhappiness is never the situation.", source: "Eckhart Tolle, A New Earth", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-7", category: .mindfulness, text: "Stillness is where creativity and solutions are found.", source: "Eckhart Tolle, Stillness Speaks", sourceLabel: "Eckhart Tolle"),
        InspirationReminder(id: "mindfulness-8", category: .mindfulness, text: "The present moment is filled with joy and happiness.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-9", category: .mindfulness, text: "Feelings come and go like clouds in a windy sky.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-10", category: .mindfulness, text: "Smile, breathe, and go slowly.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-11", category: .mindfulness, text: "Walk as if you are kissing the Earth with your feet.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-12", category: .mindfulness, text: "The present moment is the only time over which we have dominion.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-13", category: .mindfulness, text: "Peace is every step.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-14", category: .mindfulness, text: "Breathe. You are alive.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-15", category: .mindfulness, text: "Drink your tea slowly and reverently.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-16", category: .mindfulness, text: "Awareness is like the sun.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-17", category: .mindfulness, text: "Because you are alive, everything is possible.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-18", category: .mindfulness, text: "Breathing in, I calm body and mind.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-19", category: .mindfulness, text: "Breathing out, I smile.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-20", category: .mindfulness, text: "The miracle is to walk on the earth.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "mindfulness-21", category: .mindfulness, text: "Mindfulness is awareness that arises through paying attention.", source: "Jon Kabat-Zinn", sourceLabel: "Jon Kabat-Zinn"),
        InspirationReminder(id: "mindfulness-22", category: .mindfulness, text: "You can't stop the waves, but you can learn to surf.", source: "Jon Kabat-Zinn", sourceLabel: "Jon Kabat-Zinn"),
        InspirationReminder(id: "mindfulness-23", category: .mindfulness, text: "Wherever you go, there you are.", source: "Jon Kabat-Zinn", sourceLabel: "Jon Kabat-Zinn"),
        InspirationReminder(id: "mindfulness-24", category: .mindfulness, text: "As long as you are breathing, there is more right with you than wrong.", source: "Jon Kabat-Zinn", sourceLabel: "Jon Kabat-Zinn"),
        InspirationReminder(id: "mindfulness-25", category: .mindfulness, text: "The little things? The little moments? They aren't little.", source: "Jon Kabat-Zinn", sourceLabel: "Jon Kabat-Zinn"),
        InspirationReminder(id: "mindfulness-26", category: .mindfulness, text: "Attention is the rarest and purest form of generosity.", source: "Simone Weil", sourceLabel: "Simone Weil"),
        InspirationReminder(id: "mindfulness-27", category: .mindfulness, text: "Absolutely unmixed attention is prayer.", source: "Simone Weil, Gravity and Grace", sourceLabel: "Simone Weil"),
        InspirationReminder(id: "mindfulness-28", category: .mindfulness, text: "Almost everything will work again if you unplug it for a few minutes.", source: "Anne Lamott", sourceLabel: "Anne Lamott"),
        InspirationReminder(id: "mindfulness-29", category: .mindfulness, text: "Rest and laughter are the most spiritual acts.", source: "Anne Lamott, attributed", sourceLabel: "Anne Lamott"),
        InspirationReminder(id: "mindfulness-30", category: .mindfulness, text: "Nothing ever goes away until it teaches us what we need to know.", source: "Pema Chodron", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-31", category: .mindfulness, text: "You are the sky. Everything else is just the weather.", source: "Pema Chodron, attributed", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-32", category: .mindfulness, text: "Fear is a natural reaction to moving closer to the truth.", source: "Pema Chodron", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-33", category: .mindfulness, text: "Start where you are.", source: "Pema Chodron", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-34", category: .mindfulness, text: "The most fundamental aggression to ourselves is ignorance.", source: "Pema Chodron", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-35", category: .mindfulness, text: "Meditation is not about getting rid of thoughts.", source: "Pema Chodron, paraphrase", sourceLabel: "Pema Chodron"),
        InspirationReminder(id: "mindfulness-36", category: .mindfulness, text: "Feelings are just visitors. Let them come and go.", source: "Mooji", sourceLabel: "Mooji"),
        InspirationReminder(id: "mindfulness-37", category: .mindfulness, text: "Step into the fire of self-discovery.", source: "Mooji", sourceLabel: "Mooji"),
        InspirationReminder(id: "mindfulness-38", category: .mindfulness, text: "The mind creates the abyss; the heart crosses it.", source: "Nisargadatta Maharaj", sourceLabel: "Nisargadatta Maharaj"),
        InspirationReminder(id: "mindfulness-39", category: .mindfulness, text: "You are not your mind.", source: "Nisargadatta Maharaj", sourceLabel: "Nisargadatta Maharaj"),
        InspirationReminder(id: "mindfulness-40", category: .mindfulness, text: "The quieter you become, the more you can hear.", source: "Ram Dass", sourceLabel: "Ram Dass"),
        InspirationReminder(id: "mindfulness-41", category: .mindfulness, text: "Be here now.", source: "Ram Dass", sourceLabel: "Ram Dass"),
        InspirationReminder(id: "mindfulness-42", category: .mindfulness, text: "The next message you need is always right where you are.", source: "Ram Dass", sourceLabel: "Ram Dass"),
        InspirationReminder(id: "mindfulness-43", category: .mindfulness, text: "Treat everyone you meet like God in drag.", source: "Ram Dass", sourceLabel: "Ram Dass"),
        InspirationReminder(id: "mindfulness-44", category: .mindfulness, text: "When you know how to listen, everybody is the guru.", source: "Ram Dass", sourceLabel: "Ram Dass"),
        InspirationReminder(id: "mindfulness-45", category: .mindfulness, text: "The breath is always with you.", source: "Mindfulness teaching", sourceLabel: "Mindfulness teaching"),
        InspirationReminder(id: "mindfulness-46", category: .mindfulness, text: "Name it to tame it.", source: "Dan Siegel, mindfulness/therapy phrase", sourceLabel: "Dan Siegel"),
        InspirationReminder(id: "mindfulness-47", category: .mindfulness, text: "Between stimulus and response there is a space.", source: "Viktor Frankl, attributed", sourceLabel: "Viktor Frankl"),
        InspirationReminder(id: "mindfulness-48", category: .mindfulness, text: "Be where your feet are.", source: "Mindfulness saying", sourceLabel: "Mindfulness saying"),
        InspirationReminder(id: "mindfulness-49", category: .mindfulness, text: "This moment is enough.", source: "Mindfulness saying", sourceLabel: "Mindfulness saying"),
        InspirationReminder(id: "mindfulness-50", category: .mindfulness, text: "Pause. Breathe. Begin again.", source: "Mindfulness saying", sourceLabel: "Mindfulness saying"),
        InspirationReminder(id: "anxiety-overthinking-1", category: .anxietyOverthinking, text: "Rule your mind or it will rule you.", source: "Horace", sourceLabel: "Horace"),
        InspirationReminder(id: "anxiety-overthinking-2", category: .anxietyOverthinking, text: "Nothing diminishes anxiety faster than action.", source: "Walter Anderson", sourceLabel: "Walter Anderson"),
        InspirationReminder(id: "anxiety-overthinking-4", category: .anxietyOverthinking, text: "Present fears are less than horrible imaginings.", source: "William Shakespeare, Macbeth", sourceLabel: "William Shakespeare"),
        InspirationReminder(id: "anxiety-overthinking-5", category: .anxietyOverthinking, text: "Anxiety does not empty tomorrow of its sorrows.", source: "Charles Spurgeon, attributed", sourceLabel: "Charles Spurgeon"),
        InspirationReminder(id: "anxiety-overthinking-6", category: .anxietyOverthinking, text: "Worry often gives a small thing a big shadow.", source: "Swedish proverb", sourceLabel: "Swedish proverb"),
        InspirationReminder(id: "anxiety-overthinking-7", category: .anxietyOverthinking, text: "No amount of anxiety makes any difference to anything that is going to happen.", source: "Alan Watts, attributed", sourceLabel: "Alan Watts"),
        InspirationReminder(id: "anxiety-overthinking-8", category: .anxietyOverthinking, text: "You don't have to control your thoughts.", source: "Dan Millman, attributed", sourceLabel: "Dan Millman"),
        InspirationReminder(id: "anxiety-overthinking-9", category: .anxietyOverthinking, text: "Worry is misuse of imagination.", source: "Dan Zadra, attributed", sourceLabel: "Dan Zadra"),
        InspirationReminder(id: "anxiety-overthinking-10", category: .anxietyOverthinking, text: "Feel the fear and do it anyway.", source: "Susan Jeffers", sourceLabel: "Susan Jeffers"),
        InspirationReminder(id: "anxiety-overthinking-11", category: .anxietyOverthinking, text: "Do not ruin today with mourning tomorrow.", source: "Catherynne M. Valente", sourceLabel: "Catherynne M. Valente"),
        InspirationReminder(id: "anxiety-overthinking-12", category: .anxietyOverthinking, text: "This too shall pass.", source: "Persian proverb", sourceLabel: "Persian proverb"),
        InspirationReminder(id: "anxiety-overthinking-14", category: .anxietyOverthinking, text: "The storm will pass.", source: "Common proverb", sourceLabel: "Common proverb"),
        InspirationReminder(id: "anxiety-overthinking-15", category: .anxietyOverthinking, text: "Fear defeats more people than any other one thing.", source: "Ralph Waldo Emerson, attributed", sourceLabel: "Ralph Waldo Emerson"),
        InspirationReminder(id: "anxiety-overthinking-16", category: .anxietyOverthinking, text: "The greatest weapon against stress is choosing one thought over another.", source: "William James, attributed", sourceLabel: "William James"),
        InspirationReminder(id: "anxiety-overthinking-17", category: .anxietyOverthinking, text: "Action may not always bring happiness, but there is no happiness without action.", source: "William James", sourceLabel: "William James"),
        InspirationReminder(id: "anxiety-overthinking-18", category: .anxietyOverthinking, text: "The greatest discovery is that a person can change his future by changing his attitude.", source: "William James, attributed", sourceLabel: "William James"),
        InspirationReminder(id: "anxiety-overthinking-19", category: .anxietyOverthinking, text: "The art of being wise is knowing what to overlook.", source: "William James", sourceLabel: "William James"),
        InspirationReminder(id: "anxiety-overthinking-20", category: .anxietyOverthinking, text: "The mind is its own place.", source: "John Milton, Paradise Lost", sourceLabel: "John Milton"),
        InspirationReminder(id: "anxiety-overthinking-22", category: .anxietyOverthinking, text: "If a problem is fixable, take action.", source: "Dalai Lama, attributed", sourceLabel: "Dalai Lama"),
        InspirationReminder(id: "anxiety-overthinking-23", category: .anxietyOverthinking, text: "If it is not fixable, worry is of no use.", source: "Dalai Lama, attributed", sourceLabel: "Dalai Lama"),
        InspirationReminder(id: "anxiety-overthinking-24", category: .anxietyOverthinking, text: "Fears are educated into us, and can be educated out.", source: "Karl Augustus Menninger", sourceLabel: "Karl Augustus Menninger"),
        InspirationReminder(id: "anxiety-overthinking-27", category: .anxietyOverthinking, text: "I've had a lot of worries, most of which never happened.", source: "Mark Twain, attributed", sourceLabel: "Mark Twain"),
        InspirationReminder(id: "anxiety-overthinking-29", category: .anxietyOverthinking, text: "The man who fears suffering is already suffering from what he fears.", source: "Michel de Montaigne, Essays", sourceLabel: "Michel de Montaigne"),
        InspirationReminder(id: "anxiety-overthinking-30", category: .anxietyOverthinking, text: "My life has been full of terrible misfortunes, most of which never happened.", source: "Michel de Montaigne, attributed", sourceLabel: "Michel de Montaigne"),
        InspirationReminder(id: "anxiety-overthinking-31", category: .anxietyOverthinking, text: "There is no trouble so great that a little truth cannot make it smaller.", source: "Unknown, traditional saying", sourceLabel: "Unknown"),
        InspirationReminder(id: "anxiety-overthinking-32", category: .anxietyOverthinking, text: "Fear is a reaction. Courage is a decision.", source: "Winston Churchill, attributed", sourceLabel: "Winston Churchill"),
        InspirationReminder(id: "anxiety-overthinking-33", category: .anxietyOverthinking, text: "Kites rise highest against the wind.", source: "Winston Churchill, attributed", sourceLabel: "Winston Churchill"),
        InspirationReminder(id: "anxiety-overthinking-34", category: .anxietyOverthinking, text: "If you are going through hell, keep going.", source: "Winston Churchill, attributed", sourceLabel: "Winston Churchill"),
        InspirationReminder(id: "anxiety-overthinking-35", category: .anxietyOverthinking, text: "Courage is going from failure to failure without losing enthusiasm.", source: "Winston Churchill, attributed", sourceLabel: "Winston Churchill"),
        InspirationReminder(id: "anxiety-overthinking-36", category: .anxietyOverthinking, text: "The only thing we have to fear is fear itself.", source: "Franklin D. Roosevelt, First Inaugural Address", sourceLabel: "Franklin D. Roosevelt"),
        InspirationReminder(id: "anxiety-overthinking-37", category: .anxietyOverthinking, text: "Do one thing every day that scares you.", source: "Eleanor Roosevelt, attributed", sourceLabel: "Eleanor Roosevelt"),
        InspirationReminder(id: "anxiety-overthinking-38", category: .anxietyOverthinking, text: "Keep your fears to yourself, but share your courage.", source: "Robert Louis Stevenson, attributed", sourceLabel: "Robert Louis Stevenson"),
        InspirationReminder(id: "anxiety-overthinking-39", category: .anxietyOverthinking, text: "The cave you fear to enter holds the treasure you seek.", source: "Joseph Campbell, attributed", sourceLabel: "Joseph Campbell"),
        InspirationReminder(id: "anxiety-overthinking-40", category: .anxietyOverthinking, text: "The privilege of a lifetime is being who you are.", source: "Joseph Campbell", sourceLabel: "Joseph Campbell"),
        InspirationReminder(id: "anxiety-overthinking-41", category: .anxietyOverthinking, text: "In the middle of difficulty lies opportunity.", source: "Albert Einstein, attributed", sourceLabel: "Albert Einstein"),
        InspirationReminder(id: "anxiety-overthinking-42", category: .anxietyOverthinking, text: "Adversity introduces a man to himself.", source: "Albert Einstein, attributed", sourceLabel: "Albert Einstein"),
        InspirationReminder(id: "anxiety-overthinking-43", category: .anxietyOverthinking, text: "Life is like riding a bicycle. To keep your balance, keep moving.", source: "Albert Einstein, attributed", sourceLabel: "Albert Einstein"),
        InspirationReminder(id: "anxiety-overthinking-44", category: .anxietyOverthinking, text: "A calm mind brings inner strength and self-confidence.", source: "Dalai Lama", sourceLabel: "Dalai Lama"),
        InspirationReminder(id: "anxiety-overthinking-46", category: .anxietyOverthinking, text: "If you want to conquer anxiety, live in the breath.", source: "Amit Ray, attributed", sourceLabel: "Amit Ray"),
        InspirationReminder(id: "anxiety-overthinking-47", category: .anxietyOverthinking, text: "You cannot always control what goes on outside.", source: "Wayne Dyer", sourceLabel: "Wayne Dyer"),
        InspirationReminder(id: "anxiety-overthinking-48", category: .anxietyOverthinking, text: "Change the way you look at things and the things you look at change.", source: "Wayne Dyer", sourceLabel: "Wayne Dyer"),
        InspirationReminder(id: "anxiety-overthinking-49", category: .anxietyOverthinking, text: "You are not stuck where you are unless you decide to be.", source: "Wayne Dyer, attributed", sourceLabel: "Wayne Dyer"),
        InspirationReminder(id: "self-worth-1", category: .selfWorth, text: "No one can make you feel inferior without your consent.", source: "Eleanor Roosevelt", sourceLabel: "Eleanor Roosevelt"),
        InspirationReminder(id: "self-worth-2", category: .selfWorth, text: "You gain strength by every experience in which you stop to look fear in the face.", source: "Eleanor Roosevelt", sourceLabel: "Eleanor Roosevelt"),
        InspirationReminder(id: "self-worth-3", category: .selfWorth, text: "Friendship with oneself is all-important.", source: "Eleanor Roosevelt", sourceLabel: "Eleanor Roosevelt"),
        InspirationReminder(id: "self-worth-4", category: .selfWorth, text: "Do what you feel in your heart to be right.", source: "Eleanor Roosevelt", sourceLabel: "Eleanor Roosevelt"),
        InspirationReminder(id: "self-worth-5", category: .selfWorth, text: "You alone are enough. You have nothing to prove.", source: "Maya Angelou, attributed", sourceLabel: "Maya Angelou"),
        InspirationReminder(id: "self-worth-6", category: .selfWorth, text: "Nothing can dim the light which shines from within.", source: "Maya Angelou, attributed", sourceLabel: "Maya Angelou"),
        InspirationReminder(id: "self-worth-7", category: .selfWorth, text: "I can be changed by what happens to me, but I refuse to be reduced by it.", source: "Maya Angelou", sourceLabel: "Maya Angelou"),
        InspirationReminder(id: "self-worth-8", category: .selfWorth, text: "You may not control all the events that happen to you.", source: "Maya Angelou", sourceLabel: "Maya Angelou"),
        InspirationReminder(id: "self-worth-10", category: .selfWorth, text: "Ask for what you want and be prepared to get it.", source: "Maya Angelou", sourceLabel: "Maya Angelou"),
        InspirationReminder(id: "self-worth-11", category: .selfWorth, text: "The privilege of a lifetime is to become who you truly are.", source: "Carl Jung, attributed", sourceLabel: "Carl Jung"),
        InspirationReminder(id: "self-worth-12", category: .selfWorth, text: "I am not what happened to me.", source: "Carl Jung, attributed", sourceLabel: "Carl Jung"),
        InspirationReminder(id: "self-worth-13", category: .selfWorth, text: "Who looks outside, dreams; who looks inside, awakes.", source: "Carl Jung, attributed", sourceLabel: "Carl Jung"),
        InspirationReminder(id: "self-worth-14", category: .selfWorth, text: "Until you make the unconscious conscious, it will direct your life.", source: "Carl Jung, attributed", sourceLabel: "Carl Jung"),
        InspirationReminder(id: "self-worth-15", category: .selfWorth, text: "To love oneself is the beginning of a lifelong romance.", source: "Oscar Wilde, An Ideal Husband", sourceLabel: "Oscar Wilde"),
        InspirationReminder(id: "self-worth-16", category: .selfWorth, text: "Be yourself; everyone else is already taken.", source: "Oscar Wilde, attributed", sourceLabel: "Oscar Wilde"),
        InspirationReminder(id: "self-worth-17", category: .selfWorth, text: "To define is to limit.", source: "Oscar Wilde, The Picture of Dorian Gray", sourceLabel: "Oscar Wilde"),
        InspirationReminder(id: "self-worth-18", category: .selfWorth, text: "Self-respect is the fruit of discipline.", source: "Abraham Joshua Heschel, attributed", sourceLabel: "Abraham Joshua Heschel"),
        InspirationReminder(id: "self-worth-19", category: .selfWorth, text: "Be faithful to that which exists within yourself.", source: "Andre Gide", sourceLabel: "Andre Gide"),
        InspirationReminder(id: "self-worth-20", category: .selfWorth, text: "It is better to be hated for what you are.", source: "Andre Gide, Autumn Leaves", sourceLabel: "Andre Gide"),
        InspirationReminder(id: "self-worth-21", category: .selfWorth, text: "Talk to yourself like someone you love.", source: "Brene Brown, attributed", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-22", category: .selfWorth, text: "Courage starts with showing up.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-24", category: .selfWorth, text: "Vulnerability is the birthplace of innovation, creativity and change.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-25", category: .selfWorth, text: "You are imperfect, you are wired for struggle, but you are worthy.", source: "Brene Brown, The Gifts of Imperfection", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-26", category: .selfWorth, text: "Authenticity is the daily practice of letting go of who we think we should be.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-27", category: .selfWorth, text: "You either walk inside your story and own it or stand outside it.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-28", category: .selfWorth, text: "What we know matters but who we are matters more.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-29", category: .selfWorth, text: "Daring greatly means the courage to be vulnerable.", source: "Brene Brown", sourceLabel: "Brene Brown"),
        InspirationReminder(id: "self-worth-32", category: .selfWorth, text: "For most of history, Anonymous was a woman.", source: "Virginia Woolf, attributed", sourceLabel: "Virginia Woolf"),
        InspirationReminder(id: "self-worth-34", category: .selfWorth, text: "I am rooted, but I flow.", source: "Virginia Woolf, The Waves", sourceLabel: "Virginia Woolf"),
        InspirationReminder(id: "self-worth-37", category: .selfWorth, text: "Insist on yourself; never imitate.", source: "Ralph Waldo Emerson, Self-Reliance", sourceLabel: "Ralph Waldo Emerson"),
        InspirationReminder(id: "self-worth-38", category: .selfWorth, text: "To be yourself in a world that is constantly trying to make you something else is accomplishment.", source: "Ralph Waldo Emerson, attributed", sourceLabel: "Ralph Waldo Emerson"),
        InspirationReminder(id: "self-worth-39", category: .selfWorth, text: "What lies behind us and what lies before us are tiny matters.", source: "Ralph Waldo Emerson, attributed", sourceLabel: "Ralph Waldo Emerson"),
        InspirationReminder(id: "self-worth-40", category: .selfWorth, text: "Accept no one's definition of your life; define yourself.", source: "Harvey Fierstein", sourceLabel: "Harvey Fierstein"),
        InspirationReminder(id: "self-worth-41", category: .selfWorth, text: "Wanting to be someone else is a waste of who you are.", source: "Kurt Cobain, attributed", sourceLabel: "Kurt Cobain"),
        InspirationReminder(id: "self-worth-42", category: .selfWorth, text: "You yourself, as much as anybody, deserve your love and affection.", source: "Buddhist saying, attributed to Buddha", sourceLabel: "Buddhist saying"),
        InspirationReminder(id: "self-worth-43", category: .selfWorth, text: "To be beautiful means to be yourself.", source: "Thich Nhat Hanh", sourceLabel: "Thich Nhat Hanh"),
        InspirationReminder(id: "self-worth-44", category: .selfWorth, text: "Because one believes in oneself, one doesn't try to convince others.", source: "Lao Tzu, attributed", sourceLabel: "Lao Tzu"),
        InspirationReminder(id: "self-worth-45", category: .selfWorth, text: "Care about what other people think and you will always be their prisoner.", source: "Lao Tzu, attributed", sourceLabel: "Lao Tzu"),
        InspirationReminder(id: "self-worth-46", category: .selfWorth, text: "Do not feel lonely; the entire universe is inside you.", source: "Rumi, attributed", sourceLabel: "Rumi"),
        InspirationReminder(id: "self-worth-47", category: .selfWorth, text: "You were born with wings, why prefer to crawl through life?", source: "Rumi, attributed", sourceLabel: "Rumi"),
        InspirationReminder(id: "self-worth-48", category: .selfWorth, text: "Let yourself be silently drawn by what you really love.", source: "Rumi, attributed", sourceLabel: "Rumi"),
        InspirationReminder(id: "self-worth-49", category: .selfWorth, text: "You are very powerful, provided you know how powerful you are.", source: "Yogi Bhajan, attributed", sourceLabel: "Yogi Bhajan"),
        InspirationReminder(id: "developer-favorites-1", category: .developerFavorites, text: "Be cockier", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-2", category: .developerFavorites, text: "Willingness to change your mind is the ultimate intelligence", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-3", category: .developerFavorites, text: "Without humility, accomplishments become sour", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-4", category: .developerFavorites, text: "Worrying means suffering twice", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-5", category: .developerFavorites, text: "Not knowing what’s in the future is the fun of it", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-6", category: .developerFavorites, text: "A smile does more for your appearance than anything else could", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-7", category: .developerFavorites, text: "Other people care the most about how you make them feel", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-8", category: .developerFavorites, text: "Stop and smell the roses", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-9", category: .developerFavorites, text: "Clarity comes from action, not thinking", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-10", category: .developerFavorites, text: "Keep failing, it’s getting you closer", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-11", category: .developerFavorites, text: "Either be on or off", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-12", category: .developerFavorites, text: "You can only connect the dots looking backwards", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-13", category: .developerFavorites, text: "Work more on realizing you already have all you need", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-14", category: .developerFavorites, text: "It’s never that serious", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-15", category: .developerFavorites, text: "Guard your influences", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-16", category: .developerFavorites, text: "Win where your feet are now", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-17", category: .developerFavorites, text: "Don’t be normal. Stand for something", source: "Developer's favorites", sourceLabel: ""),
        InspirationReminder(id: "developer-favorites-18", category: .developerFavorites, text: "Keep your shoulders back", source: "Developer's favorites", sourceLabel: "")
    ]
}
