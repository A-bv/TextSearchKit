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

    func testMatchPositions_usesNonOverlappingMatches() {
        let textView = UITextView()
        textView.text = "aaaa"

        let matches = textView.matchPositions(for: "aa")

        XCTAssertEqual(matches.map(\.range), [
            NSRange(location: 0, length: 2),
            NSRange(location: 2, length: 2),
        ])
    }

    // MARK: - scrollToFirstMatch

    func testScrollToFirstMatch_scrollsMatchNearTheEndIntoView() {
        // A tall document in a short viewport: the first (only) match sits far
        // below the fold, so scrolling to it must move the content offset down.
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        textView.text = String(repeating: "filler line\n", count: 200) + "needle"
        textView.layoutIfNeeded()
        XCTAssertEqual(textView.contentOffset.y, 0, accuracy: 0.5) // starts at the top

        textView.scrollToFirstMatch(of: "needle")

        XCTAssertGreaterThan(textView.contentOffset.y, 0) // scrolled down to reveal the match
    }

    func testScrollToFirstMatch_noMatch_isASafeNoOp() {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        textView.text = String(repeating: "filler line\n", count: 200)
        textView.layoutIfNeeded()
        let before = textView.contentOffset

        XCTAssertNoThrow(textView.scrollToFirstMatch(of: "zzz")) // no such match
        XCTAssertEqual(textView.contentOffset, before)           // nothing moved
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

    func testHighlight_whitespaceOnlyQueryHighlightsNothing() {
        let textView = UITextView()
        textView.text = "a b c"

        let ranges = textView.highlight(query: "   ", color: .systemBlue)

        XCTAssertTrue(ranges.isEmpty)
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

    func testHighlight_returnsRangesConsistentWithMatchPositions() {
        let textView = UITextView()
        textView.text = "fox FOX Fox"

        let highlighted = textView.highlight(query: "fox")
        let counted = textView.matchPositions(for: "fox").map(\.range)

        XCTAssertEqual(highlighted, counted)
        XCTAssertEqual(highlighted.count, 3)
    }

    func testHighlight_preservesOriginalAttributesAfterClear() {
        let textView = UITextView()
        let font = UIFont.boldSystemFont(ofSize: 22)
        textView.attributedText = NSAttributedString(
            string: "keep me",
            attributes: [.font: font, .foregroundColor: UIColor.systemRed]
        )

        textView.highlight(query: "keep", color: .systemBlue)
        textView.highlight(query: "") // clear

        let attrs = textView.attributedText.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.font] as? UIFont, font)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, .systemRed)
        XCTAssertNil(attrs[.backgroundColor])
    }

    func testHighlight_leavesUnrelatedAttributesIntactWhileActive() {
        let textView = UITextView()
        let font = UIFont.italicSystemFont(ofSize: 18)
        textView.attributedText = NSAttributedString(string: "abc abc", attributes: [.font: font])

        textView.highlight(query: "abc", color: .systemBlue)

        // Font survives under the highlight; only color attributes are added.
        let attrs = textView.attributedText.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.font] as? UIFont, font)
        XCTAssertNotNil(attrs[.backgroundColor])
    }

    func testHighlight_picksDarkTextOnLightAccent() {
        let textView = UITextView()
        textView.text = "abc"

        textView.highlight(query: "abc", color: .systemYellow)
        let light = textView.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor

        textView.highlight(query: "abc", color: .systemBlue)
        let dark = textView.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor

        XCTAssertEqual(light, .black)
        XCTAssertEqual(dark, .white)
    }

    // MARK: - TextSearchBar

    func testSearchBar_collapsed_pinsButtonToTrailingEdgeWithoutACallerSpacer() {
        // Mirror the documented usage: the bar pinned full-width in a container.
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let bar = TextSearchBar()
        bar.attach(to: UITextView())
        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.layoutIfNeeded()

        let button = bar.arrangedSubviews.last
        let spacer = bar.arrangedSubviews.first
        XCTAssertEqual(button?.frame.maxX ?? 0, 320, accuracy: 1) // button sits at the right edge
        XCTAssertGreaterThan(spacer?.frame.width ?? 0, 0)         // the bar's own spacer fills the rest
    }

    func testSearchBar_expanded_searchFieldTakesTheFreedWidth() {
        // When expanded, the spacer must collapse so the search field — not the
        // spacer — soaks up the width. Otherwise the field lays out at zero width
        // and the typed query is invisible.
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 56))
        let bar = TextSearchBar()
        bar.attach(to: UITextView())
        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        bar.beginSearch()
        container.layoutIfNeeded()

        let spacer = bar.arrangedSubviews[0]
        let searchField = bar.arrangedSubviews[1]
        XCTAssertTrue(spacer.isHidden)                          // spacer steps aside
        XCTAssertGreaterThan(searchField.frame.width, 100)      // field fills the freed space
    }

    func testSearchBar_rightToLeft_mirrorsControlsToLeadingEdge() {
        // In LTR the controls pin to the trailing (right) edge and the spacer fills
        // the left. Under a right-to-left layout the whole thing must mirror: the
        // toggle lands at the left edge and the spacer fills the right. UIStackView
        // does this by semantic direction as long as nothing forces LTR.
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        container.semanticContentAttribute = .forceRightToLeft
        let bar = TextSearchBar()
        bar.semanticContentAttribute = .forceRightToLeft
        bar.attach(to: UITextView())
        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.layoutIfNeeded()

        let button = bar.arrangedSubviews.last   // toggle: sits at the trailing edge
        let spacer = bar.arrangedSubviews.first  // spacer: fills the leading slack
        XCTAssertEqual(button?.frame.minX ?? -1, 0, accuracy: 1)   // toggle mirrored to the left
        XCTAssertEqual(spacer?.frame.maxX ?? 0, 320, accuracy: 1)  // spacer fills toward the right
        XCTAssertGreaterThan(spacer?.frame.width ?? 0, 0)
    }

    func testSearchBar_resolvesLocalizedStringsFromBundle() {
        // If the resource bundle is misconfigured, NSLocalizedString returns the
        // raw key ("search.open") instead of the resolved text.
        let bar = TextSearchBar()
        let toggle = bar.arrangedSubviews.last as? UIButton
        XCTAssertEqual(toggle?.accessibilityLabel, "Search")
    }

    func testSearchBar_beginSearch_disablesEditingWhileActive() {
        let bar = TextSearchBar()
        let textView = UITextView()
        textView.isEditable = true
        bar.attach(to: textView)

        bar.beginSearch()

        XCTAssertFalse(textView.isEditable) // editing is disabled during search
    }

    func testSearchBar_endSearch_restoresReadOnlyTextView() {
        let bar = TextSearchBar()
        let textView = UITextView()
        textView.isEditable = false // a read-only, search-only text view
        bar.attach(to: textView)

        bar.beginSearch()
        bar.endSearch()

        // Closing search must not silently turn editing on.
        XCTAssertFalse(textView.isEditable)
    }

    func testSearchBar_endSearch_restoresEditableTextView() {
        let bar = TextSearchBar()
        let textView = UITextView()
        textView.isEditable = true
        bar.attach(to: textView)

        bar.beginSearch()
        bar.endSearch()

        XCTAssertTrue(textView.isEditable)
    }

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

    func testSearchBar_beginSearchWithoutAttachedTextViewDoesNotCrash() {
        let bar = TextSearchBar()
        var active: Bool?
        bar.onActiveChange = { active = $0 }

        XCTAssertNoThrow(bar.beginSearch())
        XCTAssertEqual(active, true)
    }

    func testSearchBar_onActiveChange_falseAfterClose() {
        let bar = TextSearchBar()
        let textView = UITextView()
        bar.attach(to: textView)
        var events: [Bool] = []
        bar.onActiveChange = { events.append($0) }

        bar.beginSearch()
        bar.beginSearch() // ignored: already active, so no duplicate event
        bar.endSearch()

        XCTAssertEqual(events, [true, false])
    }

    func testSearchBar_controlsMeetMinimumTapTarget() {
        // The collapsed bar lays out just the toggle button (no UISearchBar to
        // distort the stack host-less). Every control shares the same size
        // constant, so this guards the 44pt minimum for all of them.
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        let bar = TextSearchBar()
        bar.attach(to: UITextView())
        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        container.layoutIfNeeded()

        let toggle = try! XCTUnwrap(bar.arrangedSubviews.last as? UIButton)
        XCTAssertGreaterThanOrEqual(toggle.frame.width, 44, "control too narrow to tap")
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44, "control too short to tap")
    }

    // MARK: - TextSearchBar navigation

    /// Attaches a bar to a text view and drives its real search path for `query`,
    /// returning the pieces a test needs. `field` is the bar's own search bar, so
    /// its text feeds the "X of Y" counter exactly as live typing would.
    private func startSearch(text: String, query: String) -> (bar: TextSearchBar, textView: UITextView, field: UISearchBar) {
        let bar = TextSearchBar()
        let textView = UITextView()
        textView.text = text
        bar.attach(to: textView)
        bar.beginSearch()
        let field = bar.arrangedSubviews[1] as! UISearchBar
        field.text = query
        bar.searchBar(field, textDidChange: query)
        return (bar, textView, field)
    }

    /// Background-highlight opacity at a range: 1.0 = active match, dimmed = inactive.
    private func backgroundAlpha(in textView: UITextView, at range: NSRange) -> CGFloat {
        guard let color = textView.attributedText.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor else {
            return 0
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }

    func testSearchBar_nextMatch_advancesWrapsAndMovesActiveHighlight() {
        let (bar, textView, _) = startSearch(text: "cat cat cat", query: "cat")
        let ranges = textView.matchPositions(for: "cat").map(\.range)
        XCTAssertEqual(bar.resultsLabel.text, "1 of 3")

        bar.nextMatch()
        XCTAssertEqual(bar.resultsLabel.text, "2 of 3")
        XCTAssertEqual(backgroundAlpha(in: textView, at: ranges[1]), 1.0, accuracy: 0.01)
        XCTAssertLessThan(backgroundAlpha(in: textView, at: ranges[0]), 1.0)

        bar.nextMatch()
        XCTAssertEqual(bar.resultsLabel.text, "3 of 3")

        bar.nextMatch() // wraps back to the first match
        XCTAssertEqual(bar.resultsLabel.text, "1 of 3")
        XCTAssertEqual(backgroundAlpha(in: textView, at: ranges[0]), 1.0, accuracy: 0.01)
    }

    func testSearchBar_previousMatch_wrapsBackward() {
        let (bar, _, _) = startSearch(text: "cat cat cat", query: "cat")
        XCTAssertEqual(bar.resultsLabel.text, "1 of 3")

        bar.previousMatch() // wraps to the last match
        XCTAssertEqual(bar.resultsLabel.text, "3 of 3")
    }

    func testSearchBar_noMatches_hidesCounterAndDisablesNavigation() {
        let (bar, _, _) = startSearch(text: "cat cat", query: "zzz")

        XCTAssertTrue(bar.resultsLabel.isHidden)
        let prev = bar.arrangedSubviews[2] as? UIButton
        let next = bar.arrangedSubviews[3] as? UIButton
        XCTAssertEqual(prev?.isEnabled, false)
        XCTAssertEqual(next?.isEnabled, false)
    }

}
