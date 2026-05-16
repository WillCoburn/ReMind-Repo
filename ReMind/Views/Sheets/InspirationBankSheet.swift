// ============================
// File: Views/Sheets/InspirationBankSheet.swift
// ============================
import SwiftUI

@MainActor
struct InspirationBankSheet: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedCategory: InspirationCategory = .philosophers
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
                    InspirationBankHeader(usesAccessibilityLayout: usesAccessibilityLayout)
                        .frame(width: contentWidth)
                        .padding(.top, usesAccessibilityLayout ? 10 : 18)

                    categoryTabs

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: usesAccessibilityLayout ? 14 : 12) {
                            ForEach(InspirationBankRepository.items(in: selectedCategory)) { reminder in
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
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
        .navigationTitle("Inspiration Bank")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .brainMailDynamicTypeRange()
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
    }

    private func isReminderAlreadyInBank(_ reminder: InspirationReminder) -> Bool {
        addedReminderIDs.contains(reminder.id) || appVM.hasActiveEntryMatching(reminder.text)
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

    var body: some View {
        VStack(spacing: usesAccessibilityLayout ? 8 : 12) {
            if !usesAccessibilityLayout {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.figmaBlue.opacity(0.11),
                                    Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.18)
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 78
                            )
                        )
                        .frame(width: 118, height: 118)

                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.figmaBlue)
                        .shadow(color: Color.figmaBlue.opacity(0.18), radius: 10, x: 0, y: 5)

                    Circle()
                        .fill(Color(red: 130/255, green: 198/255, blue: 184/255).opacity(0.35))
                        .frame(width: 12, height: 12)
                        .offset(x: 45, y: -34)

                    Circle()
                        .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.42))
                        .frame(width: 9, height: 9)
                        .offset(x: -42, y: 36)
                }
                .accessibilityHidden(true)
            }

            VStack(spacing: 7) {
                Text("A few thoughtful starts")
                    .font((usesAccessibilityLayout ? Font.title3 : Font.title2).weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add anything that feels like a note you would want to receive later.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 430)
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
                        sourcePill
                        Spacer(minLength: 12)
                        addButton
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        cardText
                        sourcePill
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
        Text(reminder.source)
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
        ZStack {
            Color.black.opacity(0.20)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

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

                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
        }
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
    case philosophers = "Philosophers"
    case writersPoets = "Writers & poets"
    case easternPhilosophy = "Eastern philosophy"
    case stoicism = "Stoicism"
    case christian = "Christian"
    case discipline = "Discipline"
    case mindfulness = "Mindfulness"
    case anxietyOverthinking = "Anxiety & overthinking"
    case selfWorth = "Self-worth"

    var id: String { rawValue }
}

private struct InspirationReminder: Identifiable, Equatable {
    let id: String
    let category: InspirationCategory
    let text: String
    let source: String
}

private enum InspirationBankRepository {
    static func items(in category: InspirationCategory) -> [InspirationReminder] {
        reminders.filter { $0.category == category }
    }

    static let reminders: [InspirationReminder] = [
        InspirationReminder(id: "philosophers-1", category: .philosophers, text: "A clear mind is often built by asking one honest question at a time.", source: "Philosophers"),
        InspirationReminder(id: "philosophers-2", category: .philosophers, text: "You do not need certainty to take the next thoughtful step.", source: "Philosophers"),
        InspirationReminder(id: "philosophers-3", category: .philosophers, text: "Let the day be a teacher, not a judge.", source: "Philosophers"),
        InspirationReminder(id: "philosophers-4", category: .philosophers, text: "The examined life can still be gentle.", source: "Philosophers"),
        InspirationReminder(id: "philosophers-5", category: .philosophers, text: "Choose the smaller truth over the impressive excuse.", source: "Philosophers"),

        InspirationReminder(id: "writers-1", category: .writersPoets, text: "Notice the small light. It usually tells you where to begin.", source: "Writers & poets"),
        InspirationReminder(id: "writers-2", category: .writersPoets, text: "Make one honest sentence out of the noise.", source: "Writers & poets"),
        InspirationReminder(id: "writers-3", category: .writersPoets, text: "There is room in you for both ache and beauty.", source: "Writers & poets"),
        InspirationReminder(id: "writers-4", category: .writersPoets, text: "Do not rush the part of you that is learning to speak plainly.", source: "Writers & poets"),
        InspirationReminder(id: "writers-5", category: .writersPoets, text: "A softer attention can find what force keeps missing.", source: "Writers & poets"),

        InspirationReminder(id: "eastern-1", category: .easternPhilosophy, text: "Let the thought pass through without making it your home.", source: "Eastern philosophy"),
        InspirationReminder(id: "eastern-2", category: .easternPhilosophy, text: "You can return to the breath before you solve the whole life.", source: "Eastern philosophy"),
        InspirationReminder(id: "eastern-3", category: .easternPhilosophy, text: "Hold the moment lightly and it becomes easier to carry.", source: "Eastern philosophy"),
        InspirationReminder(id: "eastern-4", category: .easternPhilosophy, text: "A steady step is still movement.", source: "Eastern philosophy"),
        InspirationReminder(id: "eastern-5", category: .easternPhilosophy, text: "Peace is practiced in small returns.", source: "Eastern philosophy"),

        InspirationReminder(id: "stoicism-1", category: .stoicism, text: "Handle what is yours. Release what is not.", source: "Stoicism"),
        InspirationReminder(id: "stoicism-2", category: .stoicism, text: "Your response is the part of the storm you can steer.", source: "Stoicism"),
        InspirationReminder(id: "stoicism-3", category: .stoicism, text: "Do the next right thing without demanding applause from the day.", source: "Stoicism"),
        InspirationReminder(id: "stoicism-4", category: .stoicism, text: "Discomfort is information, not an emergency.", source: "Stoicism"),
        InspirationReminder(id: "stoicism-5", category: .stoicism, text: "Practice being the person you would trust under pressure.", source: "Stoicism"),

        InspirationReminder(id: "christian-1", category: .christian, text: "Grace can be the place where you begin again.", source: "Christian"),
        InspirationReminder(id: "christian-2", category: .christian, text: "You are allowed to be held while you are still unfinished.", source: "Christian"),
        InspirationReminder(id: "christian-3", category: .christian, text: "Let love be louder than the accusation in your head.", source: "Christian"),
        InspirationReminder(id: "christian-4", category: .christian, text: "Mercy is not weakness. It is a way back to yourself.", source: "Christian"),
        InspirationReminder(id: "christian-5", category: .christian, text: "Rest can be faithful too.", source: "Christian"),

        InspirationReminder(id: "discipline-1", category: .discipline, text: "Make the next step small enough that you can actually take it.", source: "Discipline"),
        InspirationReminder(id: "discipline-2", category: .discipline, text: "Consistency is often a quieter form of courage.", source: "Discipline"),
        InspirationReminder(id: "discipline-3", category: .discipline, text: "Begin before the mood arrives.", source: "Discipline"),
        InspirationReminder(id: "discipline-4", category: .discipline, text: "Protect the promise you made to your future self.", source: "Discipline"),
        InspirationReminder(id: "discipline-5", category: .discipline, text: "Tiny repetitions become a place you can stand.", source: "Discipline"),

        InspirationReminder(id: "mindfulness-1", category: .mindfulness, text: "Come back to this breath. You only need one doorway.", source: "Mindfulness"),
        InspirationReminder(id: "mindfulness-2", category: .mindfulness, text: "Name what is here without turning it into a verdict.", source: "Mindfulness"),
        InspirationReminder(id: "mindfulness-3", category: .mindfulness, text: "You can soften your shoulders before you fix the problem.", source: "Mindfulness"),
        InspirationReminder(id: "mindfulness-4", category: .mindfulness, text: "The present moment is not asking you to perform.", source: "Mindfulness"),
        InspirationReminder(id: "mindfulness-5", category: .mindfulness, text: "Let your attention land gently, then decide.", source: "Mindfulness"),

        InspirationReminder(id: "anxiety-1", category: .anxietyOverthinking, text: "A worried thought is not a prophecy.", source: "Anxiety & overthinking"),
        InspirationReminder(id: "anxiety-2", category: .anxietyOverthinking, text: "You can be uncertain and still be safe enough for this moment.", source: "Anxiety & overthinking"),
        InspirationReminder(id: "anxiety-3", category: .anxietyOverthinking, text: "Do not answer every alarm your mind rings.", source: "Anxiety & overthinking"),
        InspirationReminder(id: "anxiety-4", category: .anxietyOverthinking, text: "Return to evidence. Return to breath. Return to now.", source: "Anxiety & overthinking"),
        InspirationReminder(id: "anxiety-5", category: .anxietyOverthinking, text: "You do not have to rehearse every possible hurt.", source: "Anxiety & overthinking"),

        InspirationReminder(id: "self-worth-1", category: .selfWorth, text: "Your worth is not waiting on your productivity.", source: "Self-worth"),
        InspirationReminder(id: "self-worth-2", category: .selfWorth, text: "You are more than the hardest thing you are carrying.", source: "Self-worth"),
        InspirationReminder(id: "self-worth-3", category: .selfWorth, text: "Being loved does not require becoming easier to explain.", source: "Self-worth"),
        InspirationReminder(id: "self-worth-4", category: .selfWorth, text: "Treat yourself like someone whose future still matters.", source: "Self-worth"),
        InspirationReminder(id: "self-worth-5", category: .selfWorth, text: "You can need care and still be strong.", source: "Self-worth")
    ]
}
