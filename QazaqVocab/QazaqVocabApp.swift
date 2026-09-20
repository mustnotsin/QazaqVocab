//
//  QazaqVocabApp.swift
//  QazaqVocab
//
//  Created by Beksultan Mussin on 26.08.2026.
//

import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        DailyReminderManager.shared.syncWithLearnerState()
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let destination = userInfo[ExperienceEngine.notificationDestinationKey] as? String
        let identifier = response.notification.request.identifier
        
        if destination == ExperienceEngine.featuredWordDestination ||
            identifier == ExperienceEngine.dailyReminderIdentifier {
            AppNavigationState.shared.navigateToFeaturedWord()
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct QazaqVocabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if ExperienceEngine.isFeaturedWordDeepLink(url) {
                        AppNavigationState.shared.navigateToFeaturedWord()
                    } else if ExperienceEngine.isSettingsDeepLink(url) {
                        AppNavigationState.shared.isSettingsPresented = true
                    }
                }
        }
    }
}
