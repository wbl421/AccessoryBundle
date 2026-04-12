import SwiftUI

// MARK: - 应用设置（Logo、门店信息等）
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // 存储键
    private let logoPathKey = "app_logo_path"
    private let containerWidthKey = "app_logo_container_width"
    private let containerHeightKey = "app_logo_container_height"
    private let imageScaleKey = "app_logo_image_scale"
    private let bottomPaddingKey = "app_logo_bottom_padding"

    // Logo 图片路径
    @Published var logoPath: String? {
        didSet {
            if let path = logoPath {
                UserDefaults.standard.set(path, forKey: logoPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: logoPathKey)
            }
        }
    }

    // 容器宽度（默认 200）
    @Published var containerWidth: Double {
        didSet { UserDefaults.standard.set(containerWidth, forKey: containerWidthKey) }
    }

    // 容器高度（默认 120）
    @Published var containerHeight: Double {
        didSet { UserDefaults.standard.set(containerHeight, forKey: containerHeightKey) }
    }

    // 图片缩放比例（默认 1.0，范围 0.3 ~ 2.0）
    @Published var imageScale: Double {
        didSet { UserDefaults.standard.set(imageScale, forKey: imageScaleKey) }
    }

    // 下边距（与标题的距离，默认 0）
    @Published var bottomPadding: Double {
        didSet { UserDefaults.standard.set(bottomPadding, forKey: bottomPaddingKey) }
    }

    // 加载 Logo 图片
    var logoImage: UIImage? {
        guard let path = logoPath else { return nil }
        return ImageStorage.shared.loadImage(filename: path)
    }

    private init() {
        self.logoPath = UserDefaults.standard.string(forKey: logoPathKey)

        let savedWidth = UserDefaults.standard.double(forKey: containerWidthKey)
        self.containerWidth = savedWidth > 0 ? savedWidth : 200

        let savedHeight = UserDefaults.standard.double(forKey: containerHeightKey)
        self.containerHeight = savedHeight > 0 ? savedHeight : 120

        let savedScale = UserDefaults.standard.double(forKey: imageScaleKey)
        self.imageScale = savedScale > 0 ? savedScale : 1.0

        self.bottomPadding = UserDefaults.standard.double(forKey: bottomPaddingKey)
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
        // 删除后重置为默认值
        containerWidth = 200
        containerHeight = 120
        imageScale = 1.0
        bottomPadding = 0
    }
}
