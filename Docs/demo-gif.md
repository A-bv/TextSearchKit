# Demo GIF

`demo.gif` in this folder is the image shown in the README. It is a committed
artifact — the code that produces it is kept here as a reference rather than in
the test target, since it generates a doc asset and is not a real test.

## Regenerate the committed GIF

1. Create `Tests/TextSearchKitTests/DemoGIFGenerator.swift` with the source in
   the [Generator source](#generator-source) section below.
2. Pick a simulator and run only that test, passing the env var through the test
   runner (a plain shell env var does not reach the simulator process):

   ```sh
   UDID=$(xcrun simctl list devices available --json \
     | python3 -c "import sys,json;ds=json.load(sys.stdin)['devices'];print([d for rt in sorted(ds) if 'iOS' in rt for d in ds[rt] if d.get('isAvailable') and 'iPhone' in d['name']][-1]['udid'])")

   TEST_RUNNER_GENERATE_DEMO_GIF=1 xcodebuild test \
     -scheme TextSearchKit -destination "id=$UDID" \
     -only-testing:TextSearchKitTests/DemoGIFGeneratorTests
   ```

3. Delete the file again once `Docs/demo.gif` is written.

The generator renders with `CALayer.render(in:)` so it works in a host-less test
bundle, and applies the expand/collapse animation end states directly because
those animations can't run without a display link. It has no system keyboard or
caret — that content lives in separate windows and can't be captured in process.

## Alternative: record a real app (higher fidelity)

For a clip with the live keyboard, caret, and real animations:

1. Create a new iOS app in Xcode and add this package with Swift Package Manager.
2. Build a screen with a `UITextView` and `TextSearchBar`, run it in Simulator.
3. Record and convert:

   ```sh
   xcrun simctl io booted recordVideo demo.mp4
   ffmpeg -i demo.mp4 -vf "fps=12,scale=720:-1:flags=lanczos" demo.gif
   ```

## Generator source

```swift
#if DEBUG
import XCTest
import ImageIO
@testable import TextSearchKit

/// Renders the real `TextSearchBar` through its states in an offscreen window
/// and writes an animated GIF into `Docs/`. Not a real test: it only runs when
/// `GENERATE_DEMO_GIF` is set, so normal test runs and CI skip it.
@MainActor
final class DemoGIFGeneratorTests: XCTestCase {

    func testGenerateDemoGIF() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GENERATE_DEMO_GIF"] != nil,
            "Set GENERATE_DEMO_GIF to render the demo GIF."
        )

        let size = CGSize(width: 390, height: 200)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.backgroundColor = .systemBackground
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()

        let bar = TextSearchBar(configuration: .init(accentColor: .systemIndigo))
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isEditable = true
        textView.text = """
            The quick brown fox jumps over the lazy dog.
            How quick can a fox be? Stay quick, stay sharp.
            """
        bar.attach(to: textView)

        let stack = UIStackView(arrangedSubviews: [bar, textView, bar.resultsLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: root.view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: root.view.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: root.view.bottomAnchor, constant: -8),
        ])
        window.layoutIfNeeded()

        // arrangedSubviews order: [spacer, searchField, prev, next, lock, toggle].
        let field = bar.arrangedSubviews[1] as! UISearchBar
        let toggle = bar.arrangedSubviews.last as? UIButton

        // Hostless tests can't run the reveal/collapse animations (no display
        // link), so apply their end states directly for a clean render.
        func forceExpanded() {
            for view in bar.arrangedSubviews { view.alpha = 1; view.isHidden = false }
            toggle?.transform = .identity
            toggle?.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            layoutAndDraw()
        }
        func forceCollapsed() {
            for (index, view) in bar.arrangedSubviews.enumerated() {
                let isChrome = index == 0 || view === toggle
                view.alpha = 1
                view.isHidden = !isChrome
            }
            toggle?.transform = .identity
            toggle?.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
            layoutAndDraw()
        }
        func layoutAndDraw() {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            textView.layoutManager.ensureLayout(for: textView.textContainer)
        }

        var frames: [CGImage] = []
        func capture() { layoutAndDraw(); frames.append(snapshot(of: window)) }

        forceCollapsed(); capture()                                   // collapsed
        bar.beginSearch(); forceExpanded(); capture()                 // expanded, empty
        field.text = "quick"
        bar.searchBar(field, textDidChange: "quick")
        forceExpanded(); capture()                                    // 1 of 3
        bar.nextMatch(); forceExpanded(); capture()                   // 2 of 3
        bar.nextMatch(); forceExpanded(); capture()                   // 3 of 3
        bar.endSearch(); forceCollapsed(); capture()                  // collapsed

        try writeGIF(frames: frames, secondsPerFrame: 0.9)
    }

    private func snapshot(of window: UIWindow) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        // layer.render(in:) is CPU-based, so it works without a render server.
        let image = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
        return image.cgImage!
    }

    private func writeGIF(frames: [CGImage], secondsPerFrame: Double) throws {
        // The simulator can write to the host filesystem, so locate the repo
        // root relative to this source file and drop the GIF in Docs/.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TextSearchKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
        let docs = repoRoot.appendingPathComponent("Docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let outputURL = docs.appendingPathComponent("demo.gif")

        // GIF uniform type identifier (avoids UTType, which is iOS 14+).
        let gifUTI = "com.compuserve.gif" as CFString
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            outputURL as CFURL, gifUTI, frames.count, nil
        ))
        let fileProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)
        let frameProps = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: secondsPerFrame]
        ]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProps as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        print("Wrote demo GIF to \\(outputURL.path)")
    }
}
#endif
```
