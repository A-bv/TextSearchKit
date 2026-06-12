import UIKit

// The text-search engine behind TextSearchBar: highlight, scroll-to-match,
// and match positions for any UITextView.

public extension UITextView {
    func highlightColorsForSearchedWords(keyword: [String]) {
        let color1 = UIColor.label
        let color2 = self.tintColor
        let color3 = UIColor.white
        let base = self.text

        self.attributedText = NSAttributedString(
            base: base!,
            keyWords: keyword,
            foregroundColor: color1,
            font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body),
            highlightForeground: color3,
            highlighBackground: color2!,
            alpha: 0.6)
    }
}

extension NSAttributedString {
    internal convenience init(
        base: String,
        keyWords: [String],
        foregroundColor: UIColor,
        font: UIFont,
        highlightForeground: UIColor,
        highlighBackground: UIColor,
        alpha: CGFloat
    ) {
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: foregroundColor
        ]
        let baseAttributed = NSMutableAttributedString(
            string: base,
            attributes: attributes)

        let range = NSRange(location: 0, length: base.utf16.count)

        for word in keyWords {
            guard let regex = try? NSRegularExpression(pattern: word, options: .caseInsensitive) else {
                continue
            }

            let attributes = [
                NSAttributedString.Key.backgroundColor: highlighBackground.withAlphaComponent(alpha),
                NSAttributedString.Key.foregroundColor: highlightForeground
            ]

            regex.matches(
                in: base,
                options: .withTransparentBounds,
                range: range
            ).forEach {
                baseAttributed.addAttributes(attributes, range: $0.range)
            }
        }
        self.init(attributedString: baseAttributed)
    }
}

// MARK: - Scrolling

public extension UITextView {
    func scrollToSubstring(substring: String) {
        let value = getFirstHighlightedWordPosition(word: substring)
        self.setContentOffset(CGPoint(x: 0, y: 0.5), animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            self.setCursorPosition(value: value)
            self.scrollToCursorPosition()
        }
    }

    private func scrollToCursorPosition() {
        if let cursorPosition = self.selectedTextRange?.start {
            let rect: CGRect = self.caretRect(for: cursorPosition)
            let point = CGPoint(x: 0, y: rect.origin.y)
            self.setContentOffset(point, animated: true)
        }
    }
}

// MARK: - Cursor

public extension UITextView {
    func setCursorPositionAtStart() {
        let newPosition = self.beginningOfDocument
        self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
    }

    private func setCursorPosition(value: Int) {
        if let newPosition = self.position(from: self.beginningOfDocument, offset: value) {
            self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
        }
    }
}

// MARK: - Match positions

public extension UITextView {
    func getEveryHighlightedWordPosition(word: String) -> [(Int, Int)] {
        var searchedWords = [(Int, Int)]()
        if let mystring = self.text {
            var searchPosition = mystring.startIndex
            while let range = mystring.range(
                of: word,
                options: .caseInsensitive,
                range: searchPosition..<mystring.endIndex
            ) {
                let startPos = mystring.distance(from: mystring.startIndex, to: range.lowerBound)
                let endPos = mystring.distance(from: mystring.startIndex, to: range.upperBound)
                searchedWords.append((startPos, endPos))
                searchPosition = range.upperBound
            }
        }
        return searchedWords
    }

    private func getFirstHighlightedWordPosition(word: String) -> Int {
        if let mystring = self.text,
           let range = mystring.range(of: word, options: .caseInsensitive) {
            return mystring.distance(from: mystring.startIndex, to: range.upperBound)
        } else {
            return 0
        }
    }
}
