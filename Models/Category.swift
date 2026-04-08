import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var order: Int

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String, order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static let defaults: [Category] = [
        Category(name: "iPhone", icon: "iphone", colorHex: "#007AFF", order: 0),
        Category(name: "iPad", icon: "ipad", colorHex: "#5856D6", order: 1),
        Category(name: "Mac", icon: "laptopcomputer", colorHex: "#FF9500", order: 2),
        Category(name: "Watch", icon: "applewatch", colorHex: "#FF2D55", order: 3)
    ]
}
