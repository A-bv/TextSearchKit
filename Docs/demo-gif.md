# Demo GIF

`demo.gif` in this folder is generated from the package itself — no separate app
or screen recording needed.

## Regenerate

A gated test renders the real `TextSearchBar` through its states in an offscreen
window and writes `Docs/demo.gif`. It is skipped on normal test runs and in CI;
set `TEST_RUNNER_GENERATE_DEMO_GIF` to run it:

```sh
UDID=$(xcrun simctl list devices available --json \
  | python3 -c "import sys,json;ds=json.load(sys.stdin)['devices'];print([d for rt in sorted(ds) if 'iOS' in rt for d in ds[rt] if d.get('isAvailable') and 'iPhone' in d['name']][-1]['udid'])")

TEST_RUNNER_GENERATE_DEMO_GIF=1 xcodebuild test \
  -scheme TextSearchKit -destination "id=$UDID" \
  -only-testing:TextSearchKitTests/DemoGIFGeneratorTests
```

The generator (`Tests/TextSearchKitTests/DemoGIFGenerator.swift`) renders with
`CALayer.render(in:)` so it works in a host-less test bundle, and applies the
expand/collapse animation end states directly since those animations can't run
without a display link.

## Alternative: record a real app

For a higher-fidelity clip (live keyboard, real animations):

1. Create a new iOS app in Xcode and add this package with Swift Package Manager.
2. Build a screen with a `UITextView` and `TextSearchBar`.
3. Run it in Simulator and record:

```sh
xcrun simctl io booted recordVideo demo.mp4
```

4. Convert with `ffmpeg`:

```sh
ffmpeg -i demo.mp4 -vf "fps=12,scale=720:-1:flags=lanczos" demo.gif
```
