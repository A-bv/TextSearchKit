# TextSearchKit

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platform](https://img.shields.io/badge/iOS-13%2B-blue.svg)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)

**Add a search bar to any text view in one line.** It sits as a small 🔍 button,
opens into a search box when tapped, highlights every match, jumps between them,
counts them, and locks the text so you don't change it by accident.

- ✨ One line to set up: `searchBar.attach(to: textView)`
- 🎨 Keeps your text's original fonts, colors, and links
- ⌨️ iPad keyboard shortcuts: ⌘F, ⌘G, ⌘⇧G
- 📦 Pure Swift, no dependencies, iOS 13+

## Demo

> 📹 _Add a short GIF here_ — the bar opening from 🔍 and highlighting matches.

## Install

Swift Package Manager — in Xcode: **File → Add Package Dependencies…** and paste
the repo URL. Or in `Package.swift`:

```swift
.package(url: "https://github.com/<you>/TextSearchKit.git", from: "1.1.0")
```

## Use it

Create the bar, attach it, and drop it in your layout. The bar keeps itself at
the right edge and grows leftward on its own — no spacer or extra setup.

```swift
import UIKit
import TextSearchKit

final class MyViewController: UIViewController {
    private let searchBar = TextSearchBar()
    private let textView  = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.attach(to: textView)

        let stack = UIStackView(arrangedSubviews: [searchBar, textView, searchBar.resultsLabel])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        // …pin `stack` to your view as usual.
    }
}
```

`resultsLabel` is the “1 of 7” count — a plain label you can place anywhere, or
leave out.

## What you see

| When | What happens |
|---|---|
| At rest | A single 🔍 button. |
| You tap it | It opens into a search box with up / down arrows and a 🔒 lock. The text becomes read-only and the keyboard appears. |
| You type | Every match lights up, the current one stands out and scrolls into view, and the count shows `1 of 7`. |
| You close it | Highlights clear, your text looks normal again, and you can edit it. |

Search ignores case and looks for your text exactly as typed, so symbols like
`$` `.` `(` are treated as plain characters. The arrows loop around at the ends.

## Open it from elsewhere

A navigation-bar button:

```swift
navigationItem.rightBarButtonItem = UIBarButtonItem(
    barButtonSystemItem: .search, target: searchBar,
    action: #selector(TextSearchBar.beginSearch)
)
```

iPad keyboard shortcuts — add this to your view controller:

```swift
override var keyCommands: [UIKeyCommand]? { searchBar.searchKeyCommands }
```

| ⌘F | ⌘G | ⌘⇧G |
|---|---|---|
| Open | Next match | Previous match |

## Lock the text

While searching, the text is read-only so you can't change it by accident. Tap
the lock to switch editing on (🔓) or off (🔒) without closing search.

## Settings

```swift
TextSearchBar(configuration: .init(
    placeholder: "Find…",
    accentColor: .systemIndigo,
    keyboardType: .default
))
```

| Setting | Default | What it does |
|---|---|---|
| `placeholder` | `"Search …"` | Hint text in the search box. |
| `accentColor` | `.systemBlue` | Colors the buttons and the highlight. |
| `keyboardType` | `.default` | Keyboard used for typing the search. |

Highlighted text turns black or white automatically — whichever reads better on
your color.

## Know when it opens or closes

```swift
searchBar.onActiveChange = { [weak self] isActive in
    self?.navigationItem.rightBarButtonItem?.isEnabled = !isActive
}
```

## API

**`TextSearchBar`**

| Member | What it does |
|---|---|
| `attach(to:)` | Connect the bar to a text view. Call once before layout. |
| `beginSearch()` | Open search from your own code. |
| `nextMatch()` / `previousMatch()` | Go to the next / previous match (loops). |
| `searchKeyCommands` | The ⌘F / ⌘G / ⌘⇧G shortcuts. |
| `resultsLabel` | The label showing the count. |
| `onActiveChange` | Called when search opens or closes. |

You can also highlight text yourself with `UITextView.highlight(query:)` and find
matches with `matchPositions(for:)`. Highlighting only recolors the matches;
clearing it leaves your text exactly as it was.

## Contributing

Bug or feature request? [Open an issue](https://github.com/<you>/TextSearchKit/issues).
PRs welcome. Run the tests on an iOS simulator (plain `swift build` won't work —
the package needs iOS):

```sh
xcodebuild test -scheme TextSearchKit -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

No license has been chosen yet, so all rights are reserved for now. To open it
up, add a `LICENSE` file (MIT is a common, simple choice) and note it here.
