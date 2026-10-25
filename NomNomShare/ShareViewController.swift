import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Einstieg der Teilen-Erweiterung: holt Link/Text aus dem Teilen-Menü und zeigt die SwiftUI-Oberfläche.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareImportView(
            loadInput: { [weak self] in await self?.sharedInput() ?? ShareInput(url: nil, text: nil, images: []) },
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
        var images: [Data] = []

        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let found = item as? URL, !found.isFileURL {
                url = found
            }
            // Fotos und Screenshots: kommen je nach App als Datei-URL, Data oder UIImage
            if images.count < RecipeImporter.maxPhotos, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) {
                if let file = item as? URL, let data = try? Data(contentsOf: file) {
                    images.append(data)
                } else if let data = item as? Data {
                    images.append(data)
                } else if let image = item as? UIImage, let data = image.pngData() {
                    images.append(data)
                }
                continue
            }
            if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                text = item as? String
            }
        }
        return ShareInput(url: url ?? text.flatMap(RecipeImporter.firstURL(in:)), text: text, images: images)
    }
}

struct ShareInput: Sendable {
    let url: URL?
    let text: String?
    /// Geteilte Fotos/Screenshots als Rohdaten (UIImage erst in der Oberfläche)
    let images: [Data]
}
