import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var customIconPath: String? // 自定义上传图标的路径
    var order: Int

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String, customIconPath: String? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.customIconPath = customIconPath
        self.order = order
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, customIconPath, order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    static let defaults: [Category] = [
        Category(name: "iPhone", icon: "iphone", colorHex: "#007AFF", order: 0),
        Category(name: "iPad", icon: "ipad", colorHex: "#5856D6", order: 1),
        Category(name: "Mac", icon: "laptopcomputer", colorHex: "#FF9500", order: 2),
        Category(name: "Watch", icon: "applewatch", colorHex: "#FF2D55", order: 3)
    ]
}
