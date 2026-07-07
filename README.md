# TextSearchKit

Find-and-highlight for `UITextView`. `TextSearchBar` is a drop-in search bar: attach it to any text view and it highlights every match as you type, counts them, and steps through them, without disturbing the text's existing formatting.

[![CI](https://github.com/A-bv/TextSearchKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TextSearchKit/actions/workflows/ci.yml)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![iOS 13+](https://img.shields.io/badge/iOS-13%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

Start a search from the magnifying-glass button or in code. The bar expands into a search field, matches highlight live as you type, and a counter shows the current position. Step through matches with the on-screen chevrons or keyboard shortcuts. Editing pauses while searching and is restored when you close. Every action is available programmatically too.

<p align="center">
  <img src=".github/demo.gif" alt="Typing a query in a text view and stepping through the highlighted matches" width="380">
</p>

## Why this exists

iOS 16 added a built-in find bar for `UITextView` ([`UIFindInteraction`](https://developer.apple.com/documentation/uikit/uifindinteraction)). TextSearchKit predates it. It is the in-app search that shipped inside an older app, extracted into its own package rather than deleted, so projects that still target **iOS 13 to 15** keep a working find-and-highlight bar for versions that have no native equivalent. On **iOS 16+**, prefer the system find bar unless you want this one's look. In **SwiftUI**, this package is not the right fit.

## Install

Swift Package Manager. In Xcode, **File ▸ Add Package Dependencies…** and paste the URL:

```
https://github.com/A-bv/TextSearchKit
```

or declare it in `Package.swift`:

```swift
.package(url: "https://github.com/A-bv/TextSearchKit.git", from: "1.3.1")
```

## Usage

`TextSearchBar` is a `UIStackView`. Create one, attach it to your text view, and place it (with its results label) in your layout.

```swift
import UIKit
import TextSearchKit

final class ViewController: UIViewController {
    private let textView = UITextView()
    private let searchBar = TextSearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.attach(to: textView)

        let stack = UIStackView(arrangedSubviews: [searchBar, textView, searchBar.resultsLabel])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}
```

The bar starts collapsed as a magnifying-glass button and expands when tapped. To drive it in code, call `beginSearch()` and `endSearch()`, for example from a navigation-bar button. `onActiveChange` fires with `true` when search opens and `false` when it closes.

### Keyboard shortcuts

Expose the built-in key commands from your view controller:

```swift
override var keyCommands: [UIKeyCommand]? {
    searchBar.searchKeyCommands
}
```

- `Cmd+F` opens search
- `Cmd+G` next match
- `Cmd+Shift+G` previous match

### Highlight without the bar

The matching engine is a `UITextView` extension you can use on its own:

```swift
textView.highlight(query: "swift")     // highlight every match, returns the ranges
textView.matchPositions(for: "swift")  // every case-insensitive match
textView.scrollToFirstMatch(of: "swift")
```

## Customization

```swift
let searchBar = TextSearchBar(configuration: .init(
    placeholder: "Find",
    accentColor: .systemIndigo,
    keyboardType: .default
))
```

The accent color tints the buttons and the match highlight.

## Localization

The built-in strings (accessibility labels, key-command titles, the "X of Y" counter) are resolved through the package bundle. English ships by default; add an `<lang>.lproj/Localizable.strings` to your app to provide more languages.

## Behavior

- **Matching is literal and case-insensitive.** Special characters match verbatim, not as a regex, and a whitespace-only query highlights nothing.
- **Your formatting is kept.** Fonts, colors, and links stay put under a highlight, and clearing the search (an empty query) restores the original styling exactly.
- **Editing pauses while searching.** The text view is made non-editable during a search and its previous state is restored on close, so a read-only text view stays read-only.
- **The active match scrolls into view** as you step through, without jumping your layout.

## Accessibility

- Every control meets the 44pt minimum tap target.
- Controls and the counter scale with Dynamic Type.
- VoiceOver announces the "X of Y" position as you move between matches.
- Right-to-left layouts mirror correctly.

## Implementation

The matching engine lives in a `UITextView` extension, separate from the bar, so you can highlight text without the UI. Highlights are written to the text view's storage and back up the original styling first, so they restore exactly when cleared. The bar is `@MainActor` throughout, and the package builds clean under Swift 6 strict concurrency with no dependencies.

## Layout

```text
Package.swift     ┐
Sources/          │  the package: what SPM builds and ships
Tests/            ┘

README.md         ┐
LICENSE           ┘  essential docs, kept at root by convention

.gitignore           tooling config

.github/          CI workflow and demo GIF
```

## License

MIT. See [LICENSE](LICENSE).
