import SwiftUI
import UIKit

struct EntryEditView: View {
    let entryID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService

    @State private var entry: Entry?
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var startMin: Int = 0
    @State private var endMin: Int = 0
    @State private var cancel: (() -> Void)? = nil
    @State private var showDeleteAlert = false

    private var uid: String? { auth.currentUser?.uid }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.border)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            header

            if entry == nil {
                Spacer()
                Text("Entry not found.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        sectionLabel("CATEGORY")
                        chipGrid
                        sectionLabel("NOTE")
                        noteField
                        timeRow
                        deleteButton
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl * 2)
                }
            }
        }
        .background(Palette.bg)
        .clipShape(RoundedCornersEntry(radius: 20, corners: [.topLeft, .topRight]))
        .onAppear { subscribe() }
        .onDisappear { cancel?() }
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
            }
            .contentShape(Rectangle())

            Spacer()

            Text("Edit entry")
                .font(.cwBody.weight(.semibold))
                .foregroundColor(Palette.ink)

            Spacer()

            Button(action: { Task { await onSave() } }) {
                Text("Save")
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.amber)
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.cwCaption)
            .foregroundColor(Palette.muted)
            .tracking(1.2)
            .padding(.top, Spacing.sm)
    }

    private var chipGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)],
            alignment: .leading,
            spacing: Spacing.sm
        ) {
            ForEach(Categories.all, id: \.key) { c in
                let selected = category == c.key
                Button(action: { category = c.key }) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(c.color)
                            .frame(width: 6, height: 6)
                        Text(c.label)
                            .font(.cwBody)
                            .foregroundColor(Palette.ink)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selected ? Palette.amber.opacity(0.10) : Palette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(selected ? Palette.amber : Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noteField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note)
                .font(.cwBody)
                .foregroundColor(Palette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: 72)
                .background(Palette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            if note.isEmpty {
                Text("What did you do?")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm + 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private var timeRow: some View {
        HStack(spacing: Spacing.md) {
            TimeStepper(
                label: "START",
                value: TimeUtils.formatTimeOfDay(startMin),
                onMinus: {
                    let next = TimeUtils.snapTo15(max(0, startMin - 15))
                    startMin = next
                },
                onPlus: {
                    let next = TimeUtils.snapTo15(min(24 * 60 - 15, startMin + 15))
                    startMin = next
                    if next >= endMin { endMin = next + 15 }
                }
            )
            TimeStepper(
                label: "END",
                value: TimeUtils.formatTimeOfDay(endMin),
                onMinus: {
                    endMin = TimeUtils.snapTo15(max(startMin + 15, endMin - 15))
                },
                onPlus: {
                    endMin = TimeUtils.snapTo15(min(24 * 60, endMin + 15))
                }
            )
        }
        .padding(.top, Spacing.sm)
    }

    private var deleteButton: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Palette.danger)
                Text("Delete entry")
                    .font(.cwBody)
                    .foregroundColor(Palette.danger)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subscribe() {
        cancel?()
        guard let uid else { return }
        cancel = EntriesService.shared.subscribeToToday(uid: uid) { entries in
            if entry == nil, let found = entries.first(where: { $0.id == entryID }) {
                entry = found
                category = found.category
                note = found.note
                startMin = TimeUtils.minutesOfDay(of: found.startTime)
                endMin = TimeUtils.minutesOfDay(of: found.endTime)
            }
        }
    }

    private func onSave() async {
        guard let entry, let uid else { return }
        let baseDate = entry.startTime
        let start = TimeUtils.date(baseDate, withMinutesOfDay: startMin)
        let end = TimeUtils.date(baseDate, withMinutesOfDay: max(endMin, startMin + 15))
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let nextCategory = trimmedCategory.isEmpty ? entry.category : trimmedCategory
        do {
            try await EntriesService.shared.updateEntry(
                uid: uid,
                id: entry.id,
                category: nextCategory,
                note: note.trimmingCharacters(in: .whitespaces),
                startTime: start,
                endTime: end
            )
            dismiss()
        } catch {
            // leave the sheet open on error
        }
    }

    private func onDelete() async {
        guard let entry, let uid else { return }
        do {
            try await EntriesService.shared.deleteEntry(uid: uid, id: entry.id)
            dismiss()
        } catch {
            // leave the sheet open on error
        }
    }
}

private struct TimeStepper: View {
    let label: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
                .tracking(1.2)
                .padding(.bottom, 4)

            HStack(spacing: Spacing.xs) {
                Text(value)
                    .font(.cwBody)
                    .foregroundColor(Palette.ink)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Palette.ink)
                        .frame(width: 28, height: 28)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Palette.ink)
                        .frame(width: 28, height: 28)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(Palette.white)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RoundedCornersEntry: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
