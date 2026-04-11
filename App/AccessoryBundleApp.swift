import SwiftUI

@main
struct AccessoryBundleApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(onboardingManager)
        }
    }
}
