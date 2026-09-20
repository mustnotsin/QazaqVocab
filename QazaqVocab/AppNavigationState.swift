import SwiftUI
import Combine

public enum AppTab: Hashable {
    case words
    case saved
}

/// Central observable navigation state supporting tab switching and deep linking to the featured word.
public final class AppNavigationState: ObservableObject {
    public static let shared = AppNavigationState()
    
    @Published public var selectedTab: AppTab = .words
    @Published public var scrollToFeaturedTrigger: UUID = UUID()
    @Published public var dismissDetailsTrigger: UUID = UUID()
    
    public init() {}
    
    /// Switches to the Words tab, dismisses any open details, and triggers scrolling to the top featured daily word.
    public func navigateToFeaturedWord() {
        DispatchQueue.main.async {
            self.selectedTab = .words
            self.dismissDetailsTrigger = UUID()
            self.scrollToFeaturedTrigger = UUID()
        }
    }
}
