import SwiftUI

struct CategoryDotView: View {
    let category: String
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(Categories.color(for: category))
            .frame(width: size, height: size)
    }
}
