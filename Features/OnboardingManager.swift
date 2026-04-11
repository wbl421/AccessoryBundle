import SwiftUI

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    private let tooltipsKey = "tooltips_completed"

    @Published var areTooltipsComplete: Bool

    private init() {
        self.areTooltipsComplete = UserDefaults.standard.bool(forKey: tooltipsKey)
    }

    func completeTooltips() {
        areTooltipsComplete = true
        UserDefaults.standard.set(true, forKey: tooltipsKey)
    }
}
