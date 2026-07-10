import UIKit

/// Looks up a TextSearchKit UI string from the package's bundle.
private func localized(_ key: String, comment: String = "") -> String {
    NSLocalizedString(key, bundle: .module, comment: comment)
}

/// A drop-in search bar for any `UITextView`. Starts collapsed as a magnifying-glass
/// button and expands leftward into the full search UI when tapped.
///
/// Minimum setup:
/// ```swift
/// let bar = TextSearchBar()
/// bar.attach(to: textView)
/// // place bar and bar.resultsLabel anywhere in your layout
/// ```
@MainActor
public final class TextSearchBar: UIStackView {

    /// Customizable strings and accent color, injectable for localization and branding.
    public struct Configuration {
        public var placeholder: String
        /// Tints the buttons and the match highlight.
        public var accentColor: UIColor
        /// Keyboard shown for the search field. Defaults to `.default`.
        public var keyboardType: UIKeyboardType

        /// The localized default placeholder ("Search …" in English).
        public static var defaultPlaceholder: String { localized("search.placeholder") }

        public init(
            placeholder: String = Configuration.defaultPlaceholder,
            accentColor: UIColor = .systemBlue,
            keyboardType: UIKeyboardType = .default
        ) {
            self.placeholder = placeholder
            self.accentColor = accentColor
            self.keyboardType = keyboardType
        }
    }

    private enum Constants {
        // 44pt is Apple's minimum tap target (HIG). The SF Symbol glyph keeps its
        // own size; the extra space becomes tappable area, not a bigger icon.
        static let buttonSide: CGFloat = 44
        static let stackSpacing: CGFloat = 4
        static let expandDuration: TimeInterval = 0.38
        static let expandDamping: CGFloat = 0.82
        static let iconOutDuration: TimeInterval = 0.14
        static let iconInDuration: TimeInterval = 0.42
        static let iconInDamping: CGFloat = 0.48
        static let iconInVelocity: CGFloat = 0.9
        static let iconRotation: CGFloat = .pi / 3
    }

    private let configuration: Configuration

    /// A symbol image sized to the body text style, so control glyphs track Dynamic Type.
    private static func symbolImage(_ name: String) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))
    }

    // Always-visible toggle: magnifyingglass when idle, xmark.circle.fill when active
    private lazy var toggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(Self.symbolImage("magnifyingglass"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = localized("search.open")
        btn.addTarget(self, action: #selector(handleToggle), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var searchField: UISearchBar = {
        let bar = UISearchBar()
        bar.searchBarStyle = .minimal
        bar.placeholder = configuration.placeholder
        bar.autocorrectionType = .no
        bar.spellCheckingType = .no
        bar.keyboardType = configuration.keyboardType
        bar.smartDashesType = .no
        bar.smartQuotesType = .no
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private lazy var prevButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(Self.symbolImage("chevron.up"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = localized("search.previous")
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(previousMatch), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(Self.symbolImage("chevron.down"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = localized("search.next")
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(nextMatch), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // Fills the leading slack so the bar's controls sit at the trailing edge.
    // This is what lets the collapsed 🔍 expand leftward inside any full-width
    // container, so callers don't have to add a spacer of their own.
    private let spacer: UIView = {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()

    /// "X of Y" counter. A plain `UILabel` — place it anywhere in your layout.
    public let resultsLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private weak var textView: UITextView?
    private var isActive = false
    /// The text view's `isEditable` before search began, so closing search restores
    /// it instead of unconditionally re-enabling editing on a read-only text view.
    private var wasEditable = true
    private var currentMatches: [MatchResult] = []
    private var currentMatchIndex: Int = 0

    /// Fired when search mode starts (`true`) or ends (`false`).
    public var onActiveChange: ((Bool) -> Void)?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init(frame: .zero)
        axis = .horizontal
        spacing = Constants.stackSpacing
        alignment = .center
        distribution = .fill
        translatesAutoresizingMaskIntoConstraints = false

        // spacer is leftmost, toggleButton rightmost: the bar keeps its controls
        // at the trailing edge and grows leftward as it expands.
        [spacer, searchField, prevButton, nextButton, toggleButton].forEach(addArrangedSubview)
        searchField.delegate = self
        // While expanded, the search field (not the spacer) should soak up width.
        searchField.setContentHuggingPriority(
            UILayoutPriority(UILayoutPriority.defaultLow.rawValue - 1),
            for: .horizontal
        )

        // Start collapsed
        searchField.isHidden = true
        prevButton.isHidden = true
        nextButton.isHidden = true

        // 44pt is the floor; the button can grow if a Dynamic-Type-scaled icon
        // needs more room.
        let side = Constants.buttonSide
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
            toggleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: side),
            prevButton.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
            prevButton.heightAnchor.constraint(greaterThanOrEqualToConstant: side),
            nextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: side),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: side),
        ])
    }

    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - API

    /// Connect the bar to a text view. Call once before adding to the layout.
    public func attach(to textView: UITextView) {
        self.textView = textView
    }

    /// Expand the bar programmatically — e.g. from a nav-bar button or key command.
    @objc public func beginSearch() {
        guard !isActive else { return }
        isActive = true
        wasEditable = textView?.isEditable ?? true
        textView?.isEditable = false
        toggleButton.accessibilityLabel = localized("search.close")

        morphIcon(to: "xmark.circle.fill")

        let revealed: [UIView] = [searchField, prevButton, nextButton]
        revealed.forEach { $0.alpha = 0 }
        let animator = UIViewPropertyAnimator(duration: Constants.expandDuration, dampingRatio: Constants.expandDamping) {
            // Collapse the spacer so the search field — not the spacer — soaks up
            // the freed width; otherwise the field lays out at zero width.
            self.spacer.isHidden = true
            revealed.forEach {
                $0.isHidden = false
                $0.alpha = 1
            }
            self.layoutIfNeeded()
        }
        animator.addCompletion { _ in
            guard self.isActive else { return }
            self.searchField.becomeFirstResponder()
        }
        animator.startAnimation()

        onActiveChange?(true)
    }

    /// Run a search for `query` from code: expands the bar if it isn't already,
    /// fills the search field, highlights every match, and moves to the first one.
    /// An empty `query` clears the current search.
    public func search(_ query: String) {
        if !isActive { beginSearch() }
        searchField.text = query
        runSearch(query: query)
    }

    // MARK: - Navigation

    /// Key commands to include in your view controller's `keyCommands`.
    /// Cmd+F opens search, Cmd+G steps forward, Cmd+Shift+G steps backward.
    /// ```swift
    /// override var keyCommands: [UIKeyCommand]? { searchBar.searchKeyCommands }
    /// ```
    public var searchKeyCommands: [UIKeyCommand] {
        let find = UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(beginSearch))
        find.discoverabilityTitle = localized("search.command.find")
        let next = UIKeyCommand(input: "g", modifierFlags: .command, action: #selector(nextMatch))
        next.discoverabilityTitle = localized("search.command.next")
        let prev = UIKeyCommand(input: "g", modifierFlags: [.command, .shift], action: #selector(previousMatch))
        prev.discoverabilityTitle = localized("search.command.previous")
        return [find, next, prev]
    }

    @objc public func nextMatch() {
        guard !currentMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % currentMatches.count
        applyCurrentMatch()
    }

    @objc public func previousMatch() {
        guard !currentMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + currentMatches.count) % currentMatches.count
        applyCurrentMatch()
    }

    /// Runs the search for `query` against the current text: highlights matches,
    /// records them, and moves to the first one.
    private func runSearch(query: String) {
        guard let textView else { return }
        currentMatchIndex = 0
        // One regex pass: highlight returns the ranges it applied, reused as the match set.
        let ranges = textView.highlight(query: query, color: configuration.accentColor)
        currentMatches = ranges.map(MatchResult.init)
        if let first = ranges.first {
            textView.updateActiveMatch(to: first, among: ranges, color: configuration.accentColor)
            textView.scrollRangeToVisible(first)
        }
        updateResultsLabel()
    }

    private func applyCurrentMatch() {
        guard let textView, !currentMatches.isEmpty else { return }
        let ranges = currentMatches.map(\.range)
        let active = currentMatches[currentMatchIndex].range
        textView.updateActiveMatch(to: active, among: ranges, color: configuration.accentColor)
        textView.scrollRangeToVisible(active)
        updateResultsLabel()
    }

    // MARK: - Private

    @objc private func handleToggle() {
        if isActive { endSearch() } else { beginSearch() }
    }

    /// Collapse the bar programmatically — the counterpart to `beginSearch`.
    /// Restores the text view's editability, clears highlights, and animates closed.
    @objc public func endSearch() {
        guard isActive else { return }
        isActive = false
        currentMatches = []
        currentMatchIndex = 0
        searchField.text = ""
        textView?.highlight(query: "", color: configuration.accentColor)
        textView?.isEditable = wasEditable
        resultsLabel.isHidden = true
        toggleButton.accessibilityLabel = localized("search.open")

        morphIcon(to: "magnifyingglass")

        let animator = UIViewPropertyAnimator(duration: Constants.expandDuration, dampingRatio: Constants.expandDamping) {
            // Bring the spacer back so the collapsed bar pins the toggle to the
            // trailing edge again.
            self.spacer.isHidden = false
            [self.searchField, self.prevButton, self.nextButton].forEach {
                $0.alpha = 0
                $0.isHidden = true
            }
            self.layoutIfNeeded()
        }
        animator.addCompletion { _ in
            [self.searchField, self.prevButton, self.nextButton].forEach { $0.alpha = 1 }
        }
        animator.startAnimation()

        onActiveChange?(false)
        window?.endEditing(true)
    }

    private func updateResultsLabel() {
        let hasMatches = !currentMatches.isEmpty
        prevButton.isEnabled = hasMatches
        nextButton.isEnabled = hasMatches
        guard hasMatches, let query = searchField.text, !query.isEmpty else {
            resultsLabel.isHidden = true
            return
        }
        resultsLabel.isHidden = false
        let text = String(
            format: localized("search.results"),
            currentMatchIndex + 1,
            currentMatches.count
        )
        resultsLabel.text = text
        // Let VoiceOver users hear the updated position as they step through matches.
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    /// Spins the icon down to nothing, swaps the symbol, then springs back in.
    private func morphIcon(to systemName: String) {
        UIView.animate(withDuration: Constants.iconOutDuration, delay: 0, options: .curveEaseIn) {
            self.toggleButton.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                .rotated(by: Constants.iconRotation)
            self.toggleButton.alpha = 0
        } completion: { _ in
            self.toggleButton.setImage(Self.symbolImage(systemName), for: .normal)
            self.toggleButton.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                .rotated(by: -Constants.iconRotation)
            self.toggleButton.alpha = 1
            UIView.animate(
                withDuration: Constants.iconInDuration,
                delay: 0,
                usingSpringWithDamping: Constants.iconInDamping,
                initialSpringVelocity: Constants.iconInVelocity,
                options: []
            ) {
                self.toggleButton.transform = .identity
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension TextSearchBar: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        runSearch(query: searchText)
    }

    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        textView?.isEditable = false
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        window?.endEditing(true)
    }
}
