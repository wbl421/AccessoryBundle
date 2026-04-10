import Foundation

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var categories: [Category] = []
    @Published var bundles: [Bundle] = []
    @Published var accessories: [Accessory] = []
    @Published var accessoryCategories: [AccessoryCategory] = []
    @Published var bundleAccessoryItems: [BundleAccessoryItem] = []

    private let categoriesKey = "categories"
    private let bundlesKey = "bundles"
    private let accessoriesKey = "accessories"
    private let accessoryCategoriesKey = "accessoryCategories"
    private let bundleAccessoryItemsKey = "bundleAccessoryItems"
    private let initializedKey = "data_initialized"
    private let accessoryCategoriesInitializedKey = "accessory_categories_initialized"

    private init() {
        loadData()
        if !UserDefaults.standard.bool(forKey: initializedKey) {
            seedDefaultData()
            UserDefaults.standard.set(true, forKey: initializedKey)
        }
        if !UserDefaults.standard.bool(forKey: accessoryCategoriesInitializedKey) {
            seedAccessoryCategories()
            UserDefaults.standard.set(true, forKey: accessoryCategoriesInitializedKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
        }
        if let data = UserDefaults.standard.data(forKey: bundlesKey),
           let decoded = try? JSONDecoder().decode([Bundle].self, from: data) {
            bundles = decoded
        }
        if let data = UserDefaults.standard.data(forKey: accessoriesKey),
           let decoded = try? JSONDecoder().decode([Accessory].self, from: data) {
            accessories = decoded
        }
        if let data = UserDefaults.standard.data(forKey: accessoryCategoriesKey),
           let decoded = try? JSONDecoder().decode([AccessoryCategory].self, from: data) {
            accessoryCategories = decoded
        }
        if let data = UserDefaults.standard.data(forKey: bundleAccessoryItemsKey),
           let decoded = try? JSONDecoder().decode([BundleAccessoryItem].self, from: data) {
            bundleAccessoryItems = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
        if let encoded = try? JSONEncoder().encode(bundles) {
            UserDefaults.standard.set(encoded, forKey: bundlesKey)
        }
        if let encoded = try? JSONEncoder().encode(accessories) {
            UserDefaults.standard.set(encoded, forKey: accessoriesKey)
        }
        if let encoded = try? JSONEncoder().encode(accessoryCategories) {
            UserDefaults.standard.set(encoded, forKey: accessoryCategoriesKey)
        }
        if let encoded = try? JSONEncoder().encode(bundleAccessoryItems) {
            UserDefaults.standard.set(encoded, forKey: bundleAccessoryItemsKey)
        }
    }

    private func seedAccessoryCategories() {
        accessoryCategories = AccessoryCategory.defaults
        save()
    }

    private func seedDefaultData() {
        categories = Category.defaults

        guard let iphone = categories.first(where: { $0.name == "iPhone" }) else { return }

        bundles = [
            Bundle(name: "基础套餐", price: 299, categoryId: iphone.id, order: 0)
        ]

        accessories = []

        save()
    }

    // MARK: - Bundle Operations
    func bundles(for categoryId: UUID) -> [Bundle] {
        bundles.filter { $0.categoryId == categoryId }.sorted { $0.order < $1.order }
    }

    func bundleWithAccessoryGroups(for bundleId: UUID) -> (bundle: Bundle, groups: [BundleAccessoryGroup])? {
        guard let bundle = bundles.first(where: { $0.id == bundleId }) else { return nil }

        let items = bundleAccessoryItems.filter { $0.bundleId == bundleId }.sorted { $0.order < $1.order }

        // 按 categoryId 分组（同一分类的配件合并显示）
        var groupsDict: [UUID?: [BundleAccessoryItem]] = [:]
        for item in items {
            let accessory = accessories.first(where: { $0.id == item.accessoryId })
            let categoryId = accessory?.categoryId
            if groupsDict[categoryId] == nil {
                groupsDict[categoryId] = []
            }
            groupsDict[categoryId]?.append(item)
        }

        // 创建分组
        var groups: [BundleAccessoryGroup] = []
        for (categoryId, categoryItems) in groupsDict {
            // 取第一个配件作为显示基础
            guard let firstItem = categoryItems.first,
                  let firstAccessory = accessories.first(where: { $0.id == firstItem.accessoryId }) else { continue }

            let details = categoryItems.map { item -> BundleAccessoryGroup.AccessoryDetail in
                let accessory = accessories.first(where: { $0.id == item.accessoryId })
                return BundleAccessoryGroup.AccessoryDetail(
                    id: item.id,
                    accessoryId: item.accessoryId,
                    displayName: item.customName ?? accessory?.name ?? "",
                    displayPrice: item.customPrice ?? accessory?.price ?? 0,
                    displayImagePath: item.customImagePath ?? accessory?.thumbnailPaths.first,
                    quantity: item.quantity,
                    order: item.order
                )
            }

            // 使用 categoryId 作为分组ID（没有分类的用特定ID）
            let groupId = categoryId ?? UUID()
            groups.append(BundleAccessoryGroup(
                id: groupId,
                accessory: firstAccessory,
                items: details
            ))
        }

        groups.sort { $0.items.first?.order ?? 0 < $1.items.first?.order ?? 0 }
        return (bundle, groups)
    }

    func addBundle(_ bundle: Bundle) {
        bundles.append(bundle)
        save()
    }

    func updateBundle(_ bundle: Bundle) {
        if let index = bundles.firstIndex(where: { $0.id == bundle.id }) {
            bundles[index] = bundle
            save()
        }
    }

    func deleteBundle(_ bundleId: UUID) {
        bundles.removeAll { $0.id == bundleId }
        bundleAccessoryItems.removeAll { $0.bundleId == bundleId }
        save()
    }

    // 更新套餐顺序
    func updateBundleOrders(categoryId: UUID, orderedBundles: [Bundle]) {
        for (index, var bundle) in orderedBundles.enumerated() {
            bundle.order = index
            if let existingIndex = bundles.firstIndex(where: { $0.id == bundle.id }) {
                bundles[existingIndex] = bundle
            }
        }
        save()
    }

    // MARK: - BundleAccessoryItem Operations
    func items(for bundleId: UUID) -> [BundleAccessoryItem] {
        bundleAccessoryItems.filter { $0.bundleId == bundleId }.sorted { $0.order < $1.order }
    }

    func addItem(_ item: BundleAccessoryItem) {
        bundleAccessoryItems.append(item)
        save()
    }

    func updateItem(_ item: BundleAccessoryItem) {
        if let index = bundleAccessoryItems.firstIndex(where: { $0.id == item.id }) {
            bundleAccessoryItems[index] = item
            save()
        }
    }

    // 更新分组顺序（更新每个分组中第一个item的order）
    func updateGroupOrders(bundleId: UUID, groups: [BundleAccessoryGroup]) {
        for (index, group) in groups.enumerated() {
            // 更新该分组所有item的order
            for detail in group.items {
                if let existingItem = bundleAccessoryItems.first(where: { $0.id == detail.id }),
                   let existingIndex = bundleAccessoryItems.firstIndex(where: { $0.id == detail.id }) {
                    bundleAccessoryItems[existingIndex] = BundleAccessoryItem(
                        id: existingItem.id,
                        bundleId: existingItem.bundleId,
                        accessoryId: existingItem.accessoryId,
                        customName: existingItem.customName,
                        customPrice: existingItem.customPrice,
                        customImagePath: existingItem.customImagePath,
                        quantity: existingItem.quantity,
                        order: index
                    )
                }
            }
        }
        save()
    }

    func deleteItem(_ itemId: UUID) {
        bundleAccessoryItems.removeAll { $0.id == itemId }
        save()
    }
    
    func deleteBundleAccessoryGroup(groupId: UUID) {
        // 删除该分组下的所有 item
        bundleAccessoryItems.removeAll { $0.id == groupId }
        save()
    }

    func deleteAllItems(for bundleId: UUID) {
        bundleAccessoryItems.removeAll { $0.bundleId == bundleId }
        save()
    }

    func reorderItems(_ items: [BundleAccessoryItem]) {
        for (index, item) in items.enumerated() {
            if let idx = bundleAccessoryItems.firstIndex(where: { $0.id == item.id }) {
                bundleAccessoryItems[idx].order = index
            }
        }
        save()
    }

    // MARK: - Accessory Operations
    func accessories(for categoryId: UUID) -> [Accessory] {
        accessories.filter { $0.categoryId == categoryId }.sorted { $0.order < $1.order }
    }

    func addAccessory(_ accessory: Accessory) {
        accessories.append(accessory)
        save()
    }

    func updateAccessory(_ accessory: Accessory) {
        if let index = accessories.firstIndex(where: { $0.id == accessory.id }) {
            accessories[index] = accessory
            save()
        }
    }

    func deleteAccessory(_ accessoryId: UUID) {
        accessories.removeAll { $0.id == accessoryId }
        bundleAccessoryItems.removeAll { $0.accessoryId == accessoryId }
        save()
    }

    // MARK: - Category Operations
    func addCategory(_ category: Category) {
        categories.append(category)
        save()
    }

    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            save()
        }
    }

    func deleteCategory(_ categoryId: UUID) {
        categories.removeAll { $0.id == categoryId }
        let bundleIdsToDelete = bundles.filter { $0.categoryId == categoryId }.map(\.id)
        for bundleId in bundleIdsToDelete {
            deleteBundle(bundleId)
        }
        save()
    }

    // MARK: - Accessory Category Operations
    func addAccessoryCategory(_ category: AccessoryCategory) {
        accessoryCategories.append(category)
        save()
    }

    func updateAccessoryCategory(_ category: AccessoryCategory) {
        if let index = accessoryCategories.firstIndex(where: { $0.id == category.id }) {
            accessoryCategories[index] = category
            save()
        }
    }
    
    func updateAccessoryCategoryOrders(categories: [AccessoryCategory]) {
        for (index, var category) in categories.enumerated() {
            category.order = index
            if let idx = accessoryCategories.firstIndex(where: { $0.id == category.id }) {
                accessoryCategories[idx] = category
            }
        }
        save()
    }

    func deleteAccessoryCategory(_ categoryId: UUID) {
        accessoryCategories.removeAll { $0.id == categoryId }
        for i in accessories.indices {
            if accessories[i].categoryId == categoryId {
                accessories[i] = Accessory(
                    id: accessories[i].id,
                    name: accessories[i].name,
                    categoryId: nil,
                    price: accessories[i].price,
                    imagePath: accessories[i].imagePath,
                    imagePaths: accessories[i].imagePaths,
                    description: accessories[i].description,
                    detailImages: accessories[i].detailImages,
                    order: accessories[i].order
                )
            }
        }
        save()
    }
}
