import SwiftUI
import UIKit
import LinkPresentation

@MainActor
struct ShareImageGenerator {
    static func renderCard(for word: WordItem) -> UIImage? {
        let cardView = ShareCardView(word: word)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

class ShareCardActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    
    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

struct SharePresenter {
    @MainActor
    static func presentShareSheet(word: WordItem) {
        guard let image = ShareImageGenerator.renderCard(for: word) else { return }
        
        let itemSource = ShareCardActivityItemSource(
            image: image,
            title: "QazaqVocab: \(word.kazakh.capitalized)"
        )
        
        let activityVC = UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
        
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        var topController = rootVC
        while let presentedVC = topController.presentedViewController {
            topController = presentedVC
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityVC, animated: true)
    }
}
