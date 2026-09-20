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
    @Published public var isSettingsPresented: Bool = false
    
    public init() {}
    
    /// Switches to the Words tab, dismisses any open details or settings, and triggers scrolling to the top featured daily word.
    public func navigateToFeaturedWord() {
        DispatchQueue.main.async {
            let wasNotWords = self.selectedTab != .words
            self.selectedTab = .words
            self.dismissDetailsTrigger = UUID()
            self.isSettingsPresented = false
            self.scrollToFeaturedTrigger = UUID()
            
            if wasNotWords {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.scrollToFeaturedTrigger = UUID()
                }
            }
        }
    }
}
