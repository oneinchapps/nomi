import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Einstieg der Teilen-Erweiterung: holt Link/Text aus dem Teilen-Menü und zeigt die SwiftUI-Oberfläche.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareImportView(
            loadInput: { [weak self] in await self?.sharedInput() ?? ShareInput(url: nil, text: nil) },
            close: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        )
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    /// Instagram und Safari teilen eine URL, TikTok oft Text mit Link darin.
    private func sharedInput() async -> ShareInput {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        var url: URL?
        var text = items.compactMap { $0.attributedContentText?.string }.first

        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let found = item as? URL, !found.isFileURL {
                url = found
            }
            if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                text = item as? String
            }
        }
        return ShareInput(url: url ?? text.flatMap(RecipeImporter.firstURL(in:)), text: text)
    }
}

struct ShareInput: Sendable {
    let url: URL?
    let text: String?
}
