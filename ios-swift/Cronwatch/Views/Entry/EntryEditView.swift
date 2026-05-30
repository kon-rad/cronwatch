import SwiftUI
import UIKit

private enum EntryEditField: Hashable {
    case start, end, note
}

struct EntryEditView: View {
    let entryID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService

    @State private var entry: Entry?
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var entryDate: Date = Date()
    @State private var startMin: Int = 0
    @State private var endMin: Int = 0
    @State private var didLoad = false
    @State private var showDeleteAlert = false
    @State private var saveError: String?
    @State private var pendingEdit: PendingEntryEdit?
    @FocusState private var focusedField: EntryEditField?

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
                if didLoad {
                    Text("Entry not found.")
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                } else {
                    ProgressView()
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        sectionLabel("CATEGORY")
                        chipGrid
                        sectionLabel("NOTE")
                        noteField
                        dateRow
                        timeRow
                        deleteButton
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl * 2)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Palette.bg)
        .clipShape(RoundedCornersEntry(radius: 20, corners: [.topLeft, .topRight]))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task { await loadEntry() }
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "An unexpected error occurred. Please try again.")
        }
        .sheet(item: $pendingEdit) { pending in
            EntryEditConflictSheet(
                category: pending.category,
                startTime: pending.startTime,
                endTime: pending.endTime,
                resolutions: pending.resolutions,
                onConfirm: { Task { await commitEdit(pending) } },
                onCancel: { pendingEdit = nil }
            )
            .presentationDetents([.medium, .large])
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
                .scrollDismissesKeyboard(.interactively)
                .focused($focusedField, equals: .note)
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

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("DATE")
            HStack {
                Text(weekdayLabel)
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
                Spacer()
                DatePicker("", selection: $entryDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Palette.amber)
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
    }

    private var weekdayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: entryDate)
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                TimeStepper(
                    label: "START",
                    minutes: $startMin,
                    focused: $focusedField,
                    field: .start,
                    minBound: 0,
                    maxBound: 24 * 60 - 1,
                    onMinus: {
                        startMin = TimeUtils.snapTo15(max(0, startMin - 15))
                    },
                    onPlus: {
                        startMin = TimeUtils.snapTo15(min(24 * 60 - 15, startMin + 15))
                    }
                )
                TimeStepper(
                    label: "END",
                    minutes: $endMin,
                    focused: $focusedField,
                    field: .end,
                    minBound: 0,
                    maxBound: 24 * 60 - 1,
                    onMinus: {
                        var next = TimeUtils.snapTo15(endMin) - 15
                        if next < 0 { next = 24 * 60 - 15 }
                        endMin = next
                    },
                    onPlus: {
                        var next = TimeUtils.snapTo15(endMin) + 15
                        if next >= 24 * 60 { next = 0 }
                        endMin = next
                    }
                )
            }
            HStack(spacing: Spacing.xs) {
                Text(TimeUtils.formatDuration(durationMinutes))
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                if spansNextDay {
                    Text("ends next day")
                        .font(.cwCaption.weight(.semibold))
                        .foregroundColor(Palette.amber)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Palette.amber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, Spacing.sm)
    }

    // End time at or before start means the entry crosses midnight and ends
    // on the following day (e.g. start 10:30pm, end 1:00am).
    private var spansNextDay: Bool { endMin <= startMin }

    private var durationMinutes: Int {
        spansNextDay ? (24 * 60 - startMin) + endMin : endMin - startMin
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

    private func loadEntry() async {
        guard entry == nil, let uid else { return }
        let found = try? await EntriesService.shared.getEntry(uid: uid, id: entryID)
        if let found {
            entry = found
            category = found.category
            note = found.note
            entryDate = found.startTime
            startMin = TimeUtils.minutesOfDay(of: found.startTime)
            endMin = TimeUtils.minutesOfDay(of: found.endTime)
        }
        didLoad = true
    }

    private func onSave() async {
        guard let entry, let uid else { return }
        let start = TimeUtils.date(entryDate, withMinutesOfDay: startMin)
        // When end <= start the entry crosses midnight, so resolve the end
        // against the following day by adding a full day of minutes.
        let endTotalMin = spansNextDay ? endMin + 24 * 60 : endMin
        let end = TimeUtils.date(entryDate, withMinutesOfDay: endTotalMin)
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let nextCategory = trimmedCategory.isEmpty ? entry.category : trimmedCategory
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        do {
            // Check whether the new range collides with other entries. If it
            // does, surface a confirmation modal before touching anything.
            let resolutions = try await EntriesService.shared.planEditResolutions(
                uid: uid,
                entryId: entry.id,
                newStart: start,
                newEnd: end,
                category: nextCategory,
                note: trimmedNote
            )
            if resolutions.isEmpty {
                try await EntriesService.shared.updateEntry(
                    uid: uid,
                    id: entry.id,
                    category: nextCategory,
                    note: trimmedNote,
                    startTime: start,
                    endTime: end
                )
                dismiss()
            } else {
                pendingEdit = PendingEntryEdit(
                    category: nextCategory,
                    note: trimmedNote,
                    startTime: start,
                    endTime: end,
                    resolutions: resolutions
                )
            }
        } catch {
            print("[EntryEditView] save failed: \(error)")
            saveError = error.localizedDescription
        }
    }

    private func commitEdit(_ pending: PendingEntryEdit) async {
        guard let entry, let uid else { return }
        do {
            try await EntriesService.shared.commitEntryEdit(
                uid: uid,
                id: entry.id,
                category: pending.category,
                note: pending.note,
                startTime: pending.startTime,
                endTime: pending.endTime,
                resolutions: pending.resolutions
            )
            pendingEdit = nil
            dismiss()
        } catch {
            print("[EntryEditView] save (with conflicts) failed: \(error)")
            pendingEdit = nil
            saveError = error.localizedDescription
        }
    }

    private func onDelete() async {
        guard let entry, let uid else { return }
        do {
            try await EntriesService.shared.deleteEntry(uid: uid, id: entry.id)
            dismiss()
        } catch {
            print("[EntryEditView] delete failed: \(error)")
            saveError = error.localizedDescription
        }
    }
}

private struct TimeStepper: View {
    let label: String
    @Binding var minutes: Int
    @FocusState.Binding var focused: EntryEditField?
    let field: EntryEditField
    let minBound: Int
    let maxBound: Int
    let onMinus: () -> Void
    let onPlus: () -> Void

    @State private var textValue: String = ""

    private var isFocused: Bool { focused == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
                .tracking(1.2)
                .padding(.bottom, 4)

            HStack(spacing: Spacing.xs) {
                TextField("", text: $textValue)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: field)
                    .font(.cwBody)
                    .foregroundColor(Palette.ink)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        textValue = TimeUtils.formatTimeOfDay(minutes)
                    }
                    .onChange(of: isFocused) { _, nowFocused in
                        if nowFocused {
                            textValue = Self.digits(from: minutes)
                            DispatchQueue.main.async {
                                UIApplication.shared
                                    .sendAction(#selector(UIResponder.selectAll(_:)),
                                                to: nil, from: nil, for: nil)
                            }
                        } else {
                            commit()
                        }
                    }
                    .onChange(of: minutes) { _, _ in
                        if !isFocused {
                            textValue = TimeUtils.formatTimeOfDay(minutes)
                        }
                    }

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
                    .stroke(isFocused ? Palette.amber : Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .frame(maxWidth: .infinity)
    }

    private static func digits(from m: Int) -> String {
        let h = (m / 60) % 24
        let mn = m % 60
        return String(format: "%02d%02d", h, mn)
    }

    private func commit() {
        let digits = textValue.filter(\.isNumber)
        if let parsed = Self.parse(digits) {
            minutes = max(minBound, min(maxBound, parsed))
        }
        textValue = TimeUtils.formatTimeOfDay(minutes)
    }

    private static func parse(_ digits: String) -> Int? {
        guard !digits.isEmpty else { return nil }
        if digits.count <= 2 {
            guard let h = Int(digits), h >= 0, h <= 23 else { return nil }
            return h * 60
        }
        let padded = String(repeating: "0", count: max(0, 4 - digits.count)) + digits
        let last4 = String(padded.suffix(4))
        let hStr = String(last4.prefix(2))
        let mStr = String(last4.suffix(2))
        guard let h = Int(hStr), let mn = Int(mStr),
              (0...23).contains(h), (0...59).contains(mn) else { return nil }
        return h * 60 + mn
    }
}

// A confirmed-pending edit that overlaps other entries. Held while the
// conflict confirmation sheet is shown; committed atomically on confirm.
struct PendingEntryEdit: Identifiable {
    let id = UUID()
    let category: String
    let note: String
    let startTime: Date
    let endTime: Date
    let resolutions: [Resolution]
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
