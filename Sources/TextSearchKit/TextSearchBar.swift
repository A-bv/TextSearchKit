import UIKit

/// A drop-in search bar for any `UITextView`: live match highlighting,
/// scroll-to-match, a results counter, and an edit lock so typing can't
/// mangle the text mid-search.
///
/// Place the bar above the text view, put `resultsLabel` wherever the match
/// count should appear, then `attach(to:)` the text view.
public final class TextSearchBar: UIStackView {

    /// UI strings, injectable for localization.
    public struct Configuration {
        public var placeholder: String
        public var editTitle: String
        public var doneTitle: String
        public var resultsSuffix: String
        public var lockedSymbol: String
        public var unlockedSymbol: String

        public init(
            placeholder: String = "Search ...",
            editTitle: String = "Edit",
            doneTitle: String = "Done",
            resultsSuffix: String = "results",
            lockedSymbol: String = "\u{1F512}",
            unlockedSymbol: String = "\u{1F513}"
        ) {
            self.placeholder = placeholder
            self.editTitle = editTitle
            self.doneTitle = doneTitle
            self.resultsSuffix = resultsSuffix
            self.lockedSymbol = lockedSymbol
            self.unlockedSymbol = unlockedSymbol
        }
    }

    private enum Constants {
        static let buttonSide: CGFloat = 30
    }

    private let configuration: Configuration

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = configuration.placeholder
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.keyboardType = .twitter
        searchBar.smartDashesType = .no
        searchBar.smartQuotesType = .no
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private lazy var lockLabel: UILabel = {
        let label = UILabel()
        label.text = configuration.unlockedSymbol
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(configuration.editTitle, for: .normal)
        button.addTarget(self, action: #selector(unlockEditing), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(configuration.doneTitle, for: .normal)
        button.addTarget(self, action: #selector(endSearch), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// The match counter. Not part of the bar's own layout so the host can
    /// place it independently (e.g. below the text view).
    public let resultsLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private weak var textView: UITextView?

    /// Fired when search mode starts (true) or ends (false).
    public var onActiveChange: ((Bool) -> Void)?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 2
        alignment = .center
        distribution = .fill
        translatesAutoresizingMaskIntoConstraints = false

        [searchBar, lockLabel, editButton, doneButton].forEach(addArrangedSubview)
        searchBar.delegate = self

        NSLayoutConstraint.activate([
            editButton.heightAnchor.constraint(equalToConstant: Constants.buttonSide),
            editButton.widthAnchor.constraint(equalTo: editButton.heightAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: Constants.buttonSide),
            doneButton.widthAnchor.constraint(equalTo: doneButton.heightAnchor),
        ])
    }

    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - API

    public func attach(to textView: UITextView) {
        self.textView = textView
        isHidden = true
        resultsLabel.isHidden = true
    }

    public func beginSearch() {
        isHidden = false
        textView?.setCursorPositionAtStart()
        searchBar.becomeFirstResponder()
        onActiveChange?(true)
    }

    @objc private func endSearch() {
        searchBar.text = ""
        textView?.highlightColorsForSearchedWords(keyword: [""])
        isHidden = true
        resultsLabel.isHidden = true
        textView?.isEditable = true
        onActiveChange?(false)
        window?.endEditing(true)
    }

    @objc private func unlockEditing() {
        textView?.isEditable = true
        lockLabel.text = configuration.unlockedSymbol
        window?.endEditing(true)
        editButton.isEnabled = false
        textView?.becomeFirstResponder()
    }
}

// MARK: - UISearchBarDelegate

extension TextSearchBar: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard let textView else { return }
        textView.highlightColorsForSearchedWords(keyword: [searchText])
        textView.scrollToSubstring(substring: searchText)
        let matches = textView.getEveryHighlightedWordPosition(word: searchBar.text ?? "")
        if searchBar.text?.isEmpty == false {
            resultsLabel.isHidden = false
            resultsLabel.text = "\(matches.count) " + configuration.resultsSuffix
        }
    }

    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        lockLabel.text = configuration.lockedSymbol
        editButton.isEnabled = true
        textView?.isEditable = false
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        window?.endEditing(true)
    }
}
