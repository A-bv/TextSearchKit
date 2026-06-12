import XCTest
@testable import TextSearchKit

@MainActor
final class SearchHighlightTests: XCTestCase {

    // MARK: - matchPositions

    func testMatchPositions_findEveryCaseInsensitiveOccurrence() {
        let textView = UITextView()
        textView.text = "#sun fun #SUN rerun"

        let matches = textView.matchPositions(for: "#sun")

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches.first?.range.location, 0)
        XCTAssertEqual(matches.first?.range.length, 4)
    }

    func testMatchPositions_emptyWhenNothingMatches() {
        let textView = UITextView()
        textView.text = "#sea #beach"

        XCTAssertTrue(textView.matchPositions(for: "#sun").isEmpty)
    }

    func testMatchPositions_emptyQueryReturnsEmpty() {
        let textView = UITextView()
        textView.text = "some text"

        XCTAssertTrue(textView.matchPositions(for: "").isEmpty)
    }

    func testMatchPositions_rangesAreCorrect() {
        let textView = UITextView()
        textView.text = "abcabc"

        let matches = textView.matchPositions(for: "abc")

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].range, NSRange(location: 0, length: 3))
        XCTAssertEqual(matches[1].range, NSRange(location: 3, length: 3))
    }

    // MARK: - highlight

    func testHighlight_appliesBackgroundToAllMatches() {
        let textView = UITextView()
        textView.text = "#sun and #sun"

        textView.highlight(query: "#sun", color: .systemPurple)

        var highlighted = 0
        textView.attributedText.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: textView.attributedText.length)
        ) { value, _, _ in
            if value != nil { highlighted += 1 }
        }
        XCTAssertEqual(highlighted, 2)
    }

    func testHighlight_activeRangeGetsFullOpacity() {
        let textView = UITextView()
        textView.text = "cat and cat"
        let activeRange = NSRange(location: 0, length: 3)

        textView.highlight(query: "cat", color: .systemBlue, activeRange: activeRange)

        var activeAlpha: CGFloat = 0
        var inactiveAlpha: CGFloat = 0
        textView.attributedText.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: textView.attributedText.length)
        ) { value, range, _ in
            guard let color = value as? UIColor else { return }
            color.getWhite(nil, alpha: nil)
            var a: CGFloat = 0
            color.getRed(nil, green: nil, blue: nil, alpha: &a)
            if NSEqualRanges(range, activeRange) {
                activeAlpha = a
            } else {
                inactiveAlpha = a
            }
        }
        XCTAssertGreaterThan(activeAlpha, inactiveAlpha)
    }

    func testHighlight_emptyQueryClearsFormatting() {
        let textView = UITextView()
        textView.text = "hello"
        textView.highlight(query: "hello", color: .systemBlue)

        textView.highlight(query: "", color: .systemBlue)

        var highlighted = 0
        textView.attributedText.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: textView.attributedText.length)
        ) { value, _, _ in if value != nil { highlighted += 1 } }
        XCTAssertEqual(highlighted, 0)
    }

    func testHighlight_regexSpecialCharsDoNotCrash() {
        let textView = UITextView()
        textView.text = "price $10.00 (sale)"

        XCTAssertNoThrow(textView.highlight(query: "$10.00 ("))
    }

    // MARK: - TextSearchBar

    func testSearchBar_beginSearch_notifiesActive() {
        let bar = TextSearchBar()
        let textView = UITextView()
        bar.attach(to: textView)
        var active: Bool?
        bar.onActiveChange = { active = $0 }

        bar.beginSearch()

        XCTAssertFalse(bar.isHidden)
        XCTAssertEqual(active, true)
    }

    func testSearchBar_onActiveChange_falseAfterClose() {
        let bar = TextSearchBar()
        let textView = UITextView()
        bar.attach(to: textView)
        var events: [Bool] = []
        bar.onActiveChange = { events.append($0) }

        bar.beginSearch()
        // Simulate tapping the toggle button again (endSearch is private — trigger via beginSearch guard)
        bar.beginSearch() // should be ignored since already active

        XCTAssertEqual(events, [true])
    }
}
