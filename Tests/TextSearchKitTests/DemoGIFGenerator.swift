#if DEBUG
import XCTest
import ImageIO
@testable import TextSearchKit

/// Renders the real `TextSearchBar` through its states in an offscreen window
/// and writes an animated GIF into `Docs/`. Not a real test: it only runs when
/// `GENERATE_DEMO_GIF` is set, so normal test runs and CI skip it.
///
/// Run with:
/// GENERATE_DEMO_GIF=1 xcodebuild test -scheme TextSearchKit \
///   -destination 'id=<sim-udid>' -only-testing:TextSearchKitTests/DemoGIFGeneratorTests
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

        // 1) Collapsed magnifying glass.
        forceCollapsed(); capture()

        // 2) Expanded, empty.
        bar.beginSearch(); forceExpanded(); capture()

        // 3) Query typed: matches highlighted, first one active.
        field.text = "quick"
        bar.searchBar(field, textDidChange: "quick")
        forceExpanded(); capture()

        // 4-5) Step through the matches.
        bar.nextMatch(); forceExpanded(); capture()
        bar.nextMatch(); forceExpanded(); capture()

        // 6) Closed again.
        bar.endSearch(); forceCollapsed(); capture()

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
        // Locate the repo root relative to this source file: the simulator can
        // write to the host filesystem, so the GIF lands in the repo's Docs/.
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
        print("Wrote demo GIF to \(outputURL.path)")
    }
}
#endif
