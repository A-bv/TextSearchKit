# TextSearchKit

A drop-in search bar for any `UITextView`: live match highlighting, scroll-to-match, a results counter, and an edit lock so typing can't mangle the text mid-search.

Built as a self-contained alternative to `UIFindInteraction` for apps that support iOS 13–15 (or want full control over the search UI).

## Usage

```swift
let searchBar = TextSearchBar(configuration: .init(resultsSuffix: "results"))
stack.addArrangedSubview(searchBar)          // place the bar above your text view
stack.addArrangedSubview(textView)
stack.addArrangedSubview(searchBar.resultsLabel) // place the counter anywhere

searchBar.attach(to: textView)
searchBar.beginSearch()                      // e.g. from a menu action
```

Programmatic highlighting (no bar involved):

```swift
textView.highlightColorsForSearchedWords(keyword: ["#sunset"])
textView.scrollToSubstring(substring: "#sunset")
```

All UI strings are injectable via `TextSearchBar.Configuration` for localization.
