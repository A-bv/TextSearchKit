import UIKit

/// A single match occurrence within a `UITextView`.
public struct MatchResult: Equatable {
    public let range: NSRange
    public init(range: NSRange) {
        self.range = range
    }
}

private extension NSAttributedString.Key {
    /// Marks a range we highlighted. Its value is the original styled substring,
    /// so the exact prior formatting can be restored when the highlight clears.
    static let searchHighlight = NSAttributedString.Key("TextSearchKit.searchHighlight")
}

private enum Constants {
    static let inactiveAlpha: CGFloat = 0.6
}

public extension UITextView {

    /// Highlights every case-insensitive occurrence of `query`, drawing `activeRange`
    /// at full strength and the rest dimmed.
    ///
    /// The text view's existing attributes — fonts, colors, links, attachments —
    /// are preserved: only matched ranges are touched, and clearing the highlight
    /// (an empty `query`) restores their original styling exactly.
    ///
    /// - Returns: the range of every match, in document order.
    @discardableResult
    func highlight(query: String, color: UIColor = .systemBlue, activeRange: NSRange? = nil) -> [NSRange] {
        let storage = textStorage
        clearSearchHighlights(in: storage)

        guard !query.isEmpty else { return [] }

        let ranges = UITextView.matchRanges(of: query, in: storage.string)
        guard !ranges.isEmpty else { return [] }

        let textColor = color.readableForegroundColor
        storage.beginEditing()
        for range in ranges {
            // Back up the original styling before overwriting it.
            let backup = storage.attributedSubstring(from: range)
            storage.addAttribute(.searchHighlight, value: backup, range: range)

            let isActive = activeRange.map { NSEqualRanges($0, range) } ?? false
            storage.addAttribute(
                .backgroundColor,
                value: color.withAlphaComponent(isActive ? 1 : Constants.inactiveAlpha),
                range: range
            )
            storage.addAttribute(.foregroundColor, value: textColor, range: range)
        }
        storage.endEditing()
        return ranges
    }

    /// Every case-insensitive match of `word`, using the same engine as `highlight`
    /// so counts and highlights never disagree.
    func matchPositions(for word: String) -> [MatchResult] {
        UITextView.matchRanges(of: word, in: text ?? "").map(MatchResult.init)
    }

    func scrollToFirstMatch(of word: String) {
        if let first = matchPositions(for: word).first {
            scrollRangeToVisible(first.range)
        }
    }
}

// MARK: - Internal helpers

extension UITextView {

    /// Re-draws which match is emphasized without recomputing matches or rebuilding
    /// the document. Cheap enough to call on every next/previous step.
    func updateActiveMatch(to activeRange: NSRange, among ranges: [NSRange], color: UIColor) {
        guard !ranges.isEmpty else { return }
        let storage = textStorage
        storage.beginEditing()
        for range in ranges {
            let isActive = NSEqualRanges(range, activeRange)
            storage.addAttribute(
                .backgroundColor,
                value: color.withAlphaComponent(isActive ? 1 : Constants.inactiveAlpha),
                range: range
            )
        }
        storage.endEditing()
    }

    /// Restores every range we previously highlighted back to its original styling.
    private func clearSearchHighlights(in storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        var restorations: [(range: NSRange, original: NSAttributedString)] = []
        storage.enumerateAttribute(.searchHighlight, in: full, options: []) { value, range, _ in
            if let original = value as? NSAttributedString {
                restorations.append((range, original))
            }
        }
        guard !restorations.isEmpty else { return }

        storage.beginEditing()
        // Replacements are equal length, so earlier edits don't shift later ranges.
        for restoration in restorations {
            storage.replaceCharacters(in: restoration.range, with: restoration.original)
        }
        storage.endEditing()
    }

    static func matchRanges(of query: String, in string: String) -> [NSRange] {
        // A whitespace-only query would otherwise highlight every space in the
        // document; treat it as "no search", same as an empty query.
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let pattern = NSRegularExpression.escapedPattern(for: query)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let full = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: full).map(\.range)
    }

    func setCursorPositionAtStart() {
        let start = beginningOfDocument
        selectedTextRange = textRange(from: start, to: start)
    }
}

private extension UIColor {
    /// Black or white — whichever stays legible drawn on top of the receiver.
    var readableForegroundColor: UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}
