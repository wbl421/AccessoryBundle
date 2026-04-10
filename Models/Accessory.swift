import Foundation

// 配件分类（如：保护壳类、膜类、充电类等）
struct AccessoryCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String // SF Symbol 名称
    var customIconPath: String? // 自定义上传图标的路径
    var order: Int

    init(id: UUID = UUID(), name: String, icon: String = "folder.fill", customIconPath: String? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.customIconPath = customIconPath
        self.order = order
    }

    // 自定义 CodingKeys 兼容旧数据
    enum CodingKeys: String, CodingKey {
        case id, name, icon, customIconPath, order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "folder.fill"
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    static let defaults: [AccessoryCategory] = [
        AccessoryCategory(name: "保护壳类", icon: "iphone.gen3.radiowaves.left.and.right", order: 0),
        AccessoryCategory(name: "膜类", icon: "square.split.1x2", order: 1),
        AccessoryCategory(name: "充电类", icon: "bolt.fill", order: 2),
        AccessoryCategory(name: "数据线类", icon: "cable.connector", order: 3),
        AccessoryCategory(name: "音频类", icon: "headphones", order: 4),
        AccessoryCategory(name: "其他", icon: "folder.fill", order: 5)
    ]
}

// 配件商品（类似淘宝商品）
struct Accessory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var categoryId: UUID?
    var price: Int
    var imagePath: String? // 旧字段，保留兼容
    var imagePaths: [String]? // 多张缩略图
    var description: String?
    var detailImages: [String]?
    var order: Int

    init(id: UUID = UUID(), name: String, categoryId: UUID? = nil, price: Int, imagePath: String? = nil, imagePaths: [String]? = nil, description: String? = nil, detailImages: [String]? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.categoryId = categoryId
        self.price = price
        self.imagePath = imagePath
        self.imagePaths = imagePaths
        self.description = description
        self.detailImages = detailImages
        self.order = order
    }

    // 获取所有缩略图路径（优先用 imagePaths，兼容旧 imagePath）
    var thumbnailPaths: [String] {
        if let paths = imagePaths, !paths.isEmpty {
            return paths
        }
        if let path = imagePath {
            return [path]
        }
        return []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price, imagePath, imagePaths, description, order
        case categoryId, detailImages
        case images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        price = try container.decode(Int.self, forKey: .price)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        imagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0

        if let detail = try container.decodeIfPresent([String].self, forKey: .detailImages) {
            detailImages = detail
        } else if let oldImages = try container.decodeIfPresent([String].self, forKey: .images) {
            detailImages = oldImages
        } else {
            detailImages = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encodeIfPresent(imagePaths, forKey: .imagePaths)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(detailImages, forKey: .detailImages)
        try container.encode(order, forKey: .order)
    }
}

// 套餐配件明细（每一条都是一个独立的配件实例）
struct BundleAccessoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var bundleId: UUID
    var accessoryId: UUID // 关联的配件模板
    var customName: String? // 自定义名称（可覆盖配件名称）
    var customPrice: Int? // 自定义价格（可覆盖配件价格）
    var customImagePath: String? // 自定义图片
    var quantity: Int
    var order: Int // 排序

    init(
        id: UUID = UUID(),
        bundleId: UUID,
        accessoryId: UUID,
        customName: String? = nil,
        customPrice: Int? = nil,
        customImagePath: String? = nil,
        quantity: Int = 1,
        order: Int = 0
    ) {
        self.id = id
        self.bundleId = bundleId
        self.accessoryId = accessoryId
        self.customName = customName
        self.customPrice = customPrice
        self.customImagePath = customImagePath
        self.quantity = quantity
        self.order = order
    }

    // 兼容旧数据
    enum CodingKeys: String, CodingKey {
        case id, bundleId, accessoryId, customName, customPrice, customImagePath, quantity, order
        case variantId // 旧字段，忽略
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bundleId = try container.decode(UUID.self, forKey: .bundleId)
        accessoryId = try container.decode(UUID.self, forKey: .accessoryId)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        customPrice = try container.decodeIfPresent(Int.self, forKey: .customPrice)
        customImagePath = try container.decodeIfPresent(String.self, forKey: .customImagePath)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bundleId, forKey: .bundleId)
        try container.encode(accessoryId, forKey: .accessoryId)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encodeIfPresent(customPrice, forKey: .customPrice)
        try container.encodeIfPresent(customImagePath, forKey: .customImagePath)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(order, forKey: .order)
    }
}
