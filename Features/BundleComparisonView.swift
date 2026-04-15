import SwiftUI

// MARK: - Bundle Comparison View
struct BundleComparisonView: View {
    let bundleIds: [UUID]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedBundleId: IdentifiableUUID?

    // 获取所有套餐数据
    private var bundlesData: [(bundle: Bundle, groups: [BundleAccessoryGroup])] {
        bundleIds.compactMap { bundleId in
            dataManager.bundleWithAccessoryGroups(for: bundleId)
        }
    }

    // 获取所有分类及其配件（按分类分组）
    private var categoriesWithAccessories: [(category: AccessoryCategory, accessories: [Accessory])] {
        var categoryMap: [UUID: (category: AccessoryCategory, accessories: [Accessory])] = [:]

        for (_, groups) in bundlesData {
            for group in groups {
                guard let categoryId = group.accessory.categoryId,
                      let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else { continue }

                if categoryMap[categoryId] == nil {
                    categoryMap[categoryId] = (category, [])
                }
                // 添加配件（避免重复）
                if !categoryMap[categoryId]!.accessories.contains(where: { $0.id == group.accessory.id }) {
                    categoryMap[categoryId]!.accessories.append(group.accessory)
                }
            }
        }

        return Array(categoryMap.values).sorted { $0.category.name < $1.category.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 套餐头部信息
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(bundlesData, id: \.bundle.id) { data in
                            BundleHeaderCard(
                                bundle: data.bundle,
                                groups: data.groups,
                                onTap: {
                                    selectedBundleId = IdentifiableUUID(id: data.bundle.id)
                                }
                            )
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))

                    Divider()

                    // 配件对比列表（按分类）
                    VStack(alignment: .leading, spacing: 0) {
                        Text("配件对比")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGroupedBackground))

                        LazyVStack(spacing: 0) {
                            ForEach(categoriesWithAccessories, id: \.category.id) { item in
                                CategoryComparisonSection(
                                    category: item.category,
                                    accessories: item.accessories,
                                    bundlesData: bundlesData
                                )
                            }
                        }
                        .background(Color(.systemBackground))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("套餐对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedBundleId) { identifiableId in
                BundleDetailView(bundleId: identifiableId.id)
            }
        }
    }
}

// MARK: - Bundle Header Card
struct BundleHeaderCard: View {
    let bundle: Bundle
    let groups: [BundleAccessoryGroup]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "bag.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text(bundle.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("¥\(bundle.price)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.red)

                Text("\(groups.count)件配件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Comparison Section
struct CategoryComparisonSection: View {
    let category: AccessoryCategory
    let accessories: [Accessory]
    let bundlesData: [(bundle: Bundle, groups: [BundleAccessoryGroup])]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分类标题
            HStack {
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            Divider()
                .padding(.leading, 16)

            // 该分类下的配件对比
            ForEach(Array(accessories.enumerated()), id: \.element.id) { index, accessory in
                AccessoryComparisonRow(
                    accessory: accessory,
                    bundlesData: bundlesData
                )

                if index < accessories.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }
}

// MARK: - Accessory Comparison Row
struct AccessoryComparisonRow: View {
    let accessory: Accessory
    let bundlesData: [(bundle: Bundle, groups: [BundleAccessoryGroup])]

    private func hasAccessory(in bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> Bool {
        bundleData.groups.contains { $0.accessory.id == accessory.id }
    }

    private func getGroup(in bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> BundleAccessoryGroup? {
        bundleData.groups.first { $0.accessory.id == accessory.id }
    }

    private func accessoryDetail(for group: BundleAccessoryGroup) -> String {
        if group.items.count == 1 {
            return group.items.first?.displayName ?? ""
        }
        return "\(group.items.count)款可选"
    }

    var body: some View {
        HStack(spacing: 0) {
            // 配件名称
            Text(accessory.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
                .padding(.leading, 16)

            // 各套餐的配件状态
            ForEach(bundlesData, id: \.bundle.id) { bundleData in
                VStack(spacing: 2) {
                    if hasAccessory(in: bundleData) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        if let group = getGroup(in: bundleData) {
                            Text(accessoryDetail(for: group))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                            .foregroundStyle(.gray.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

#Preview {
    BundleComparisonView(bundleIds: [])
        .environmentObject(DataManager.shared)
}
