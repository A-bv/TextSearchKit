import XCTest
@testable import TextSearchKit

@MainActor
final class SearchHighlightTests: XCTestCase {

    func testMatchPositions_findEveryCaseInsensitiveOccurrence() {
        let textView = UITextView()
        textView.text = "#sun fun #SUN rerun"

        let positions = textView.getEveryHighlightedWordPosition(word: "#sun")

        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions.first?.0, 0)
        XCTAssertEqual(positions.first?.1, 4)
    }

    func testMatchPositions_emptyWhenNothingMatches() {
        let textView = UITextView()
        textView.text = "#sea #beach"

        XCTAssertTrue(textView.getEveryHighlightedWordPosition(word: "#sun").isEmpty)
    }

    func testHighlight_appliesBackgroundToMatches() {
        let textView = UITextView()
        textView.text = "#sun and #sun"
        textView.tintColor = .systemPurple

        textView.highlightColorsForSearchedWords(keyword: ["#sun"])

        var highlighted = 0
        textView.attributedText.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: textView.attributedText.length)
        ) { value, _, _ in
            if value != nil { highlighted += 1 }
        }
        XCTAssertEqual(highlighted, 2)
    }

    func testSearchBar_beginSearch_unhidesAndNotifies() {
        let bar = TextSearchBar()
        let textView = UITextView()
        bar.attach(to: textView)
        var active: Bool?
        bar.onActiveChange = { active = $0 }

        bar.beginSearch()

        XCTAssertFalse(bar.isHidden)
        XCTAssertEqual(active, true)
    }
}
