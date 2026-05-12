import SwiftUI

struct CaptureRowView: View {
    let capture: Capture
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet)
                            .font(.cwCaption)
                            .foregroundColor(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(dateLine)
                            .font(.cwCaption)
                            .foregroundColor(Palette.muted)
                        Text(timeLine)
                            .font(.cwCaption)
                            .monospacedDigit()
                            .foregroundColor(Palette.muted)
                    }
                    .frame(minWidth: 64, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(capture.blocks) { block in
                        BlockLine(block: block)
                    }
                }
                .padding(.leading, Spacing.xs)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.border)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .background(Palette.bg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var snippet: String {
        let raw = (capture.transcript ?? capture.blocks.first?.note ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "—" }
        if raw.count <= 150 { return raw }
        let prefix = raw.prefix(150).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + "…"
    }

    private var dateLine: String {
        guard let start = capture.blocks.first?.startTime else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: start)
    }

    private var timeLine: String {
        guard let start = capture.blocks.first?.startTime else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start)
    }
}

private struct BlockLine: View {
    let block: Entry

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Categories.color(for: block.category))
                .frame(width: 8, height: 8)
            Text(titleText)
                .font(.cwBody)
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metaText)
                .font(.cwCaption)
                .monospacedDigit()
                .foregroundColor(Palette.muted)
        }
    }

    private var titleText: AttributedString {
        var label = AttributedString(Categories.label(for: block.category))
        label.font = .cwBody.weight(.semibold)
        label.foregroundColor = Palette.ink
        if !block.note.isEmpty {
            var note = AttributedString("  ·  \(block.note)")
            note.foregroundColor = Palette.muted
            note.font = .cwBody
            label.append(note)
        }
        return label
    }

    private var metaText: String {
        let dur = TimeUtils.entryDurationMin(block)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: block.startTime)) · \(TimeUtils.formatDuration(dur))"
    }
}
