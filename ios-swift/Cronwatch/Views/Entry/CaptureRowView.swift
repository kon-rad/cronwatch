import SwiftUI

struct CaptureRowView: View {
    let capture: Capture
    let entryNumber: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Entry \(entryNumber)")
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    Text(createdAtText)
                        .font(.cwCaption)
                        .monospacedDigit()
                        .foregroundColor(Palette.muted)
                        .lineLimit(1)
                }

                if !categories.isEmpty {
                    categoryTags
                }
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
        .accessibilityLabel(accessibilityText)
    }

    private var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for block in capture.blocks {
            let key = block.category
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }

    private var categoryTags: some View {
        FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs) {
            ForEach(categories, id: \.self) { category in
                HStack(spacing: 4) {
                    CategoryDotView(category: category)
                    Text(Categories.label(for: category))
                        .font(.cwCaption)
                        .foregroundColor(Palette.ink)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(Categories.pillBackground(for: category))
                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
            }
        }
    }

    private var createdAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d · h:mm a"
        return formatter.string(from: capture.createdAt)
    }

    private var accessibilityText: String {
        let labels = categories.map { Categories.label(for: $0) }.joined(separator: ", ")
        if labels.isEmpty {
            return "Entry \(entryNumber), \(createdAtText)"
        }
        return "Entry \(entryNumber), \(labels), \(createdAtText)"
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalWidth = max(totalWidth, rowWidth - spacing)
                totalHeight += rowHeight + lineSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth - spacing)
        totalHeight += rowHeight
        return CGSize(width: max(0, totalWidth), height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
