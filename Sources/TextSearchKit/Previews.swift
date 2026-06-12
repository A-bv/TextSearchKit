#if DEBUG
import UIKit
import SwiftUI

private final class PreviewViewController: UIViewController {

    private enum Constants {
        static let outerPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
    }

    private let searchBar = TextSearchBar(configuration: .init(accentColor: .systemIndigo))

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textContainerInset = UIEdgeInsets(
            top: Constants.outerPadding,
            left: Constants.outerPadding,
            bottom: Constants.outerPadding,
            right: Constants.outerPadding
        )
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.text = """
            The quick brown fox jumps over the lazy dog.
            Pack my box with five dozen liquor jugs.
            How vexingly quick daft zebras jump!
            The five boxing wizards jump quickly.
            Sphinx of black quartz, judge my vow.
            """
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        searchBar.attach(to: textView)

        // Spacer pushes the bar to the trailing edge.
        // When the bar expands, the spacer shrinks — the bar grows leftward.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [spacer, searchBar])
        header.axis = .horizontal

        let stack = UIStackView(arrangedSubviews: [header, textView, searchBar.resultsLabel])
        stack.axis = .vertical
        stack.spacing = Constants.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safe.topAnchor, constant: Constants.outerPadding),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Constants.outerPadding),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -Constants.outerPadding),
            stack.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -Constants.outerPadding),
        ])
    }
}

private struct PreviewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PreviewViewController {
        PreviewViewController()
    }
    func updateUIViewController(_ vc: PreviewViewController, context: Context) {}
}

#Preview("TextSearchBar") {
    PreviewRepresentable().edgesIgnoringSafeArea(.all)
}
#endif
