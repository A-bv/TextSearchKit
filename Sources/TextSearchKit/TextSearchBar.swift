import UIKit

/// A drop-in search bar for any `UITextView`. Starts collapsed as a magnifying-glass
/// button and expands leftward into the full search UI when tapped.
///
/// Minimum setup:
/// ```swift
/// let bar = TextSearchBar()
/// bar.attach(to: textView)
/// // place bar and bar.resultsLabel anywhere in your layout
/// ```
public final class TextSearchBar: UIStackView {

    /// Customizable strings and accent color, injectable for localization and branding.
    public struct Configuration {
        public var placeholder: String
        /// Tints the buttons and the match highlight.
        public var accentColor: UIColor
        /// Keyboard shown for the search field. Defaults to `.default`.
        public var keyboardType: UIKeyboardType

        public init(
            placeholder: String = "Search …",
            accentColor: UIColor = .systemBlue,
            keyboardType: UIKeyboardType = .default
        ) {
            self.placeholder = placeholder
            self.accentColor = accentColor
            self.keyboardType = keyboardType
        }
    }

    private enum Constants {
        static let buttonSide: CGFloat = 28
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

    // Always-visible toggle: magnifyingglass when idle, xmark.circle.fill when active
    private lazy var toggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = "Search"
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
        btn.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = "Previous match"
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(previousMatch), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        btn.tintColor = configuration.accentColor
        btn.accessibilityLabel = "Next match"
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(nextMatch), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var lockButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.accessibilityLabel = "Lock editing"
        btn.addTarget(self, action: #selector(toggleLock), for: .touchUpInside)
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
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private weak var textView: UITextView?
    private var isActive = false
    private var isLocked = true
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
        [spacer, searchField, prevButton, nextButton, lockButton, toggleButton].forEach(addArrangedSubview)
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
        lockButton.isHidden = true

        let side = Constants.buttonSide
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: side),
            toggleButton.heightAnchor.constraint(equalToConstant: side),
            prevButton.widthAnchor.constraint(equalToConstant: side),
            prevButton.heightAnchor.constraint(equalToConstant: side),
            nextButton.widthAnchor.constraint(equalToConstant: side),
            nextButton.heightAnchor.constraint(equalToConstant: side),
            lockButton.widthAnchor.constraint(equalToConstant: side),
            lockButton.heightAnchor.constraint(equalToConstant: side),
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
        isLocked = true
        updateLockAppearance()
        textView?.isEditable = false
        textView?.setCursorPositionAtStart()
        toggleButton.accessibilityLabel = "Close search"

        morphIcon(to: "xmark.circle.fill")

        [searchField, prevButton, nextButton, lockButton].forEach { $0.alpha = 0 }
        let animator = UIViewPropertyAnimator(duration: Constants.expandDuration, dampingRatio: Constants.expandDamping) {
            [self.searchField, self.prevButton, self.nextButton, self.lockButton].forEach {
                $0.isHidden = false
                $0.alpha = 1
            }
            self.layoutIfNeeded()
        }
        animator.addCompletion { _ in self.searchField.becomeFirstResponder() }
        animator.startAnimation()

        onActiveChange?(true)
    }

    // MARK: - Navigation

    /// Key commands to include in your view controller's `keyCommands`.
    /// Cmd+F opens search, Cmd+G steps forward, Cmd+Shift+G steps backward.
    /// ```swift
    /// override var keyCommands: [UIKeyCommand]? { searchBar.searchKeyCommands }
    /// ```
    public var searchKeyCommands: [UIKeyCommand] {
        let find = UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(beginSearch))
        find.discoverabilityTitle = "Find"
        let next = UIKeyCommand(input: "g", modifierFlags: .command, action: #selector(nextMatch))
        next.discoverabilityTitle = "Next Match"
        let prev = UIKeyCommand(input: "g", modifierFlags: [.command, .shift], action: #selector(previousMatch))
        prev.discoverabilityTitle = "Previous Match"
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

    private func endSearch() {
        guard isActive else { return }
        isActive = false
        currentMatches = []
        currentMatchIndex = 0
        searchField.text = ""
        textView?.highlight(query: "", color: configuration.accentColor)
        textView?.isEditable = true
        isLocked = true
        resultsLabel.isHidden = true
        toggleButton.accessibilityLabel = "Search"

        morphIcon(to: "magnifyingglass")

        let animator = UIViewPropertyAnimator(duration: Constants.expandDuration, dampingRatio: Constants.expandDamping) {
            [self.searchField, self.prevButton, self.nextButton, self.lockButton].forEach {
                $0.alpha = 0
                $0.isHidden = true
            }
            self.layoutIfNeeded()
        }
        animator.addCompletion { _ in
            [self.searchField, self.prevButton, self.nextButton, self.lockButton].forEach { $0.alpha = 1 }
        }
        animator.startAnimation()

        onActiveChange?(false)
        window?.endEditing(true)
    }

    @objc private func toggleLock() {
        isLocked.toggle()
        updateLockAppearance()
        if isLocked {
            textView?.isEditable = false
            searchField.becomeFirstResponder()
        } else {
            textView?.isEditable = true
            window?.endEditing(true)
            textView?.becomeFirstResponder()
        }
    }

    private func updateLockAppearance() {
        let imageName = isLocked ? "lock.fill" : "lock.open.fill"
        let tint: UIColor = isLocked ? configuration.accentColor : .secondaryLabel
        lockButton.setImage(UIImage(systemName: imageName), for: .normal)
        lockButton.tintColor = tint
        lockButton.accessibilityLabel = isLocked ? "Unlock editing" : "Lock editing"
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
        resultsLabel.text = "\(currentMatchIndex + 1) of \(currentMatches.count)"
    }

    /// Spins the icon down to nothing, swaps the symbol, then springs back in.
    private func morphIcon(to systemName: String) {
        UIView.animate(withDuration: Constants.iconOutDuration, delay: 0, options: .curveEaseIn) {
            self.toggleButton.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                .rotated(by: Constants.iconRotation)
            self.toggleButton.alpha = 0
        } completion: { _ in
            self.toggleButton.setImage(UIImage(systemName: systemName), for: .normal)
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
        guard let textView else { return }
        currentMatchIndex = 0
        // One regex pass: highlight returns the ranges it applied, reused as the match set.
        let ranges = textView.highlight(query: searchText, color: configuration.accentColor)
        currentMatches = ranges.map(MatchResult.init)
        if let first = ranges.first {
            textView.updateActiveMatch(to: first, among: ranges, color: configuration.accentColor)
            textView.scrollRangeToVisible(first)
        }
        updateResultsLabel()
    }

    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isLocked = true
        updateLockAppearance()
        textView?.isEditable = false
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        window?.endEditing(true)
    }
}
