import SwiftUI

// MARK: - 应用设置（Logo、门店信息等）
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let logoPathKey = "app_logo_path"
    private let logoScaleKey = "app_logo_scale"

    @Published var logoPath: String? {
        didSet {
            if let path = logoPath {
                UserDefaults.standard.set(path, forKey: logoPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: logoPathKey)
            }
        }
    }

    @Published var logoScale: Double {
        didSet {
            UserDefaults.standard.set(logoScale, forKey: logoScaleKey)
        }
    }

    var logoImage: UIImage? {
        guard let path = logoPath else { return nil }
        return ImageStorage.shared.loadImage(filename: path)
    }

    private init() {
        self.logoPath = UserDefaults.standard.string(forKey: logoPathKey)
        let savedScale = UserDefaults.standard.double(forKey: logoScaleKey)
        self.logoScale = savedScale > 0 ? savedScale : 1.0
    }

    func saveLogo(_ image: UIImage) {
        // 删除旧 logo
        if let oldPath = logoPath {
            ImageStorage.shared.deleteImage(filename: oldPath)
        }
        // 保存新 logo
        let id = UUID()
        if let path = ImageStorage.shared.saveImage(image, for: id) {
            logoPath = path
        }
    }

    func deleteLogo() {
        if let path = logoPath {
            ImageStorage.shared.deleteImage(filename: path)
        }
        logoPath = nil
        logoScale = 1.0
    }
}
