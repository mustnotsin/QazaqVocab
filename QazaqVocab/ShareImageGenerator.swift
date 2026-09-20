import SwiftUI
import UIKit
import LinkPresentation

@MainActor
public struct ShareImageGenerator {
    public static func renderCard(for word: WordItem) -> UIImage? {
        let cardView = ShareCardView(word: word)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

public class ShareCardActivityItemSource: NSObject, UIActivityItemSource {
    public let image: UIImage
    public let title: String
    
    public init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        super.init()
    }
    
    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
    
    public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        // Ensure no external URLs or app store links are attached during private TestFlight
        metadata.originalURL = nil
        metadata.url = nil
        return metadata
    }
}

public struct SharePresenter {
    @MainActor
    public static func presentShareSheet(word: WordItem) {
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
