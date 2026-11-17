import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
    private let snippetID = UUID()
    private var sourceLoaded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Save to KeyFlow"
        placeholder = "Leave out passwords, PINs, and payment details."

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let textProviders = providers.filter { $0.canLoadObject(ofClass: NSString.self) }
        if textProviders.count == 1, let provider = textProviders.first {
            provider.loadObject(ofClass: NSString.self) { [weak self] text, _ in
                DispatchQueue.main.async {
                    self?.loadText(text as? String)
                }
            }
        } else if items.count == 1, textProviders.isEmpty {
            loadText(items.first?.attributedContentText?.string)
        } else {
            loadText(nil)
        }
    }

    override func isContentValid() -> Bool {
        sourceLoaded && !((contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    override func didSelectPost() {
        guard isContentValid(), let text = contentText else { return }
        do {
            try SharedSnippetStore().add(text, id: snippetID)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            let alert = UIAlertController(
                title: "Couldn’t save to KeyFlow",
                message: "Try sharing the text again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    override func configurationItems() -> [Any]! {
        guard let item = SLComposeSheetConfigurationItem() else { return [] }
        item.title = "Next step"
        item.value = "Review in KeyFlow History"
        return [item]
    }

    private func loadText(_ text: String?) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            placeholder = "This app didn’t share a single text selection."
            return
        }
        sourceLoaded = true
        textView.text = text
        validateContent()
    }
}
