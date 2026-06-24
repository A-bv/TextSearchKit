# Demo GIF

Best path: create a small iOS demo app and add this package with Swift Package
Manager. A Swift package alone does not produce an installable app, so there is
nothing reliable to run and record directly from the package.

## Recommended Setup

1. Create a new iOS app in Xcode.
2. Add `https://github.com/A-bv/TextSearchKit.git` with Swift Package Manager.
3. Build a single screen with a `UITextView` and `TextSearchBar`.
4. Run it in Simulator.
5. Record the simulator.

## Record

```sh
xcrun simctl io booted recordVideo demo.mp4
```

Use the search bar, then stop recording with `Ctrl+C`.

## Convert To GIF

With `ffmpeg`:

```sh
ffmpeg -i demo.mp4 -vf "fps=12,scale=720:-1:flags=lanczos" demo.gif
```

Then add the GIF to the README:

```md
![TextSearchKit demo](Docs/demo.gif)
```
