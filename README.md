# TextSearchKit

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-13%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CI](https://github.com/A-bv/TextSearchKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TextSearchKit/actions/workflows/ci.yml)

Search UI for `UITextView`.

- iOS 13+
- Swift Package Manager
- No dependencies
- Highlights matches without destroying existing text attributes

## Install

Use Swift Package Manager:
[A-bv/TextSearchKit.git](https://github.com/A-bv/TextSearchKit.git)

```swift
.package(url: "https://github.com/A-bv/TextSearchKit.git", from: "1.1.0")
```

## Usage

```swift
import UIKit
import TextSearchKit

final class ViewController: UIViewController {
    private let textView = UITextView()
    private let searchBar = TextSearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.attach(to: textView)

        let stack = UIStackView(arrangedSubviews: [
            searchBar,
            textView,
            searchBar.resultsLabel
        ])
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

## Configuration

```swift
let searchBar = TextSearchBar(configuration: .init(
    placeholder: "Find",
    accentColor: .systemIndigo,
    keyboardType: .default
))
```

## Keyboard Shortcuts

```swift
override var keyCommands: [UIKeyCommand]? {
    searchBar.searchKeyCommands
}
```

- `Cmd+F`: open search
- `Cmd+G`: next match
- `Cmd+Shift+G`: previous match

## API

Use `TextSearchBar` for the full search UI. `UITextView` also exposes lower-level
highlighting helpers if you only need match highlighting.

## Test

```sh
xcodebuild test -scheme TextSearchKit -destination 'platform=iOS Simulator,name=<device>'
```

## Demo

See [Docs/demo-gif.md](Docs/demo-gif.md).

## License

MIT
