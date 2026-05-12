import SwiftUI

struct DonutSlice: Hashable {
    let category: String
    let minutes: Int
}

struct DonutView: View {
    let slices: [DonutSlice]
    var size: CGFloat = 132
    var thickness: CGFloat = 18

    init(slices: [DonutSlice], size: CGFloat = 132, thickness: CGFloat = 18) {
        self.slices = slices
        self.size = size
        self.thickness = thickness
    }

    init(slices: [(category: String, minutes: Int)], size: CGFloat = 132, thickness: CGFloat = 18) {
        self.slices = slices.map { DonutSlice(category: $0.category, minutes: $0.minutes) }
        self.size = size
        self.thickness = thickness
    }

    private var total: Double {
        let sum = slices.reduce(0) { $0 + $1.minutes }
        return sum > 0 ? Double(sum) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.borderSoft, lineWidth: thickness)

            if total > 0 {
                ForEach(Array(sliceRanges.enumerated()), id: \.offset) { _, item in
                    Circle()
                        .trim(from: item.from, to: item.to)
                        .stroke(
                            Categories.color(for: item.category),
                            style: StrokeStyle(lineWidth: thickness, lineCap: .butt)
                        )
                }
            }
        }
        .rotationEffect(.degrees(-90))
        .frame(width: size, height: size)
    }

    private var sliceRanges: [(category: String, from: CGFloat, to: CGFloat)] {
        guard total > 0 else { return [] }
        var running: Double = 0
        var out: [(String, CGFloat, CGFloat)] = []
        for s in slices {
            let frac = Double(s.minutes) / total
            let from = running
            let to = running + frac
            out.append((s.category, CGFloat(from), CGFloat(to)))
            running = to
        }
        return out.map { (category: $0.0, from: $0.1, to: $0.2) }
    }
}
