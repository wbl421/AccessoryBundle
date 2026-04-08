import Foundation

struct Bundle: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var price: Int
    var categoryId: UUID
    var order: Int

    init(id: UUID = UUID(), name: String, price: Int, categoryId: UUID, order: Int = 0) {
        self.id = id
        self.name = name
        self.price = price
        self.categoryId = categoryId
        self.order = order
    }
}

// 套餐配件分组（按配件类型分组，包含多个明细）
struct BundleAccessoryGroup: Identifiable, Equatable {
    let id: UUID // accessoryId
    var accessory: Accessory
    var items: [AccessoryDetail]

    var totalCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var totalPrice: Int {
        items.reduce(0) { $0 + $1.displayPrice * $1.quantity }
    }

    // 单个明细
    struct AccessoryDetail: Identifiable, Equatable {
        let id: UUID
        let accessoryId: UUID
        var displayName: String
        var displayPrice: Int
        var displayImagePath: String?
        var quantity: Int
        var order: Int
    }
}
