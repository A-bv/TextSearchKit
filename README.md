# TextSearchKit

A drop-in search bar for any `UITextView`. Starts as a magnifying-glass button and expands leftward into a full search UI. Live highlighting, next/previous navigation, results counter, edit lock. iOS 13+, no dependencies.

## Installation

**File → Add Package Dependencies** in Xcode, then paste the repo URL.

## Setup

Add `TextSearchBar` and `resultsLabel` to your view controller's layout:

```swift
import UIKit
import TextSearchKit

class MyViewController: UIViewController {

    private let searchBar = TextSearchBar()
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.attach(to: textView)

        // searchBar collapses to a 🔍 button when idle
        // resultsLabel is a plain UILabel — place it anywhere
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

## Keyboard shortcuts (iPad + hardware keyboard only)

```swift
override var keyCommands: [UIKeyCommand]? {
    searchBar.searchKeyCommands
}
```

| Shortcut | Action |
|---|---|
| Cmd+F | Open search |
| Cmd+G | Next match |
| Cmd+Shift+G | Previous match |

## Nav bar button

```swift
navigationItem.rightBarButtonItem = UIBarButtonItem(
    barButtonSystemItem: .search,
    target: searchBar,
    action: #selector(TextSearchBar.beginSearch)
)
```

## Edit lock

While searching the text view is locked (read-only). The **lock icon** in the bar toggles editing on/off without closing search.

## Custom color

```swift
let searchBar = TextSearchBar(configuration: .init(
    placeholder: "Find…",
    accentColor: .systemIndigo
))
```

## Callback

```swift
searchBar.onActiveChange = { isActive in
    self.navigationItem.rightBarButtonItem?.isEnabled = !isActive
}
```
