import SwiftUI

extension Font {
    static let cwTitle   = Font.system(size: 22, weight: .semibold)
    static let cwBody    = Font.system(size: 15, weight: .medium)
    static let cwCaption = Font.system(size: 12, weight: .medium)
}

extension Text {
    func tabularNumbers() -> Text { self.monospacedDigit() }
}
