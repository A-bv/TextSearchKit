import UIKit

/// A single match occurrence within a `UITextView`.
public struct MatchResult {
    public let range: NSRange
}

private enum Constants {
    static let highlightAlpha: CGFloat = 0.6
}

public extension UITextView {
    func highlight(query: String, color: UIColor = .systemBlue, activeRange: NSRange? = nil) {
        let base = text ?? ""
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let baseAttr = NSMutableAttributedString(
            string: base,
            attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
        )

        guard !query.isEmpty else {
            attributedText = baseAttr
            return
        }

        let pattern = NSRegularExpression.escapedPattern(for: query)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            attributedText = baseAttr
            return
        }

        let fullRange = NSRange(location: 0, length: base.utf16.count)
        regex.matches(in: base, options: .withTransparentBounds, range: fullRange).forEach { result in
            let isActive = activeRange.map { $0 == result.range } ?? false
            let attrs: [NSAttributedString.Key: Any] = [
                .backgroundColor: color.withAlphaComponent(isActive ? 1.0 : Constants.highlightAlpha),
                .foregroundColor: UIColor.white
            ]
            baseAttr.addAttributes(attrs, range: result.range)
        }
        attributedText = baseAttr
    }

    func matchPositions(for word: String) -> [MatchResult] {
        guard !word.isEmpty, let str = text else { return [] }
        var results = [MatchResult]()
        var pos = str.startIndex
        while let range = str.range(of: word, options: .caseInsensitive, range: pos..<str.endIndex) {
            results.append(MatchResult(range: NSRange(range, in: str)))
            pos = range.upperBound
        }
        return results
    }

    func scrollToFirstMatch(of word: String) {
        guard let first = matchPositions(for: word).first else { return }
        scrollRangeToVisible(first.range)
    }

    func setCursorPositionAtStart() {
        let start = beginningOfDocument
        selectedTextRange = textRange(from: start, to: start)
    }
}
