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

    // 获取所有涉及的分类
    private var allCategories: [AccessoryCategory] {
        var categorySet = Set<UUID>()
        var categories: [AccessoryCategory] = []

        for (_, groups) in bundlesData {
            for group in groups {
                guard let categoryId = group.accessory.categoryId,
                      !categorySet.contains(categoryId),
                      let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else { continue }
                categorySet.insert(categoryId)
                categories.append(category)
            }
        }

        return categories.sorted { $0.name < $1.name }
    }

    // 检查某个套餐是否包含某个分类
    private func hasCategory(_ category: AccessoryCategory, in bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> Bool {
        bundleData.groups.contains { $0.accessory.categoryId == category.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 套餐头部信息
                    HStack(spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // 分类对比表格
                    VStack(spacing: 0) {
                        // 表头 - 套餐价格
                        HStack(spacing: 0) {
                            Text("品类")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                                .padding(.leading, 16)

                            ForEach(bundlesData, id: \.bundle.id) { data in
                                Text("¥\(data.bundle.price)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))

                        Divider()

                        // 分类对比行
                        ForEach(Array(allCategories.enumerated()), id: \.element.id) { index, category in
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    // 分类名称
                                    Text(category.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 16)

                                    // 各套餐是否包含
                                    ForEach(bundlesData, id: \.bundle.id) { bundleData in
                                        if hasCategory(category, in: bundleData) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.green)
                                                .frame(maxWidth: .infinity)
                                        } else {
                                            Image(systemName: "xmark.circle")
                                                .font(.title2)
                                                .foregroundStyle(.gray.opacity(0.3))
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                                .padding(.vertical, 14)
                                .background(Color(.systemBackground))

                                if index < allCategories.count - 1 {
                                    Divider()
                                        .padding(.leading, 96)
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    Spacer()
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
            VStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.red)
                    .clipShape(Circle())

                Text(bundle.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("¥\(bundle.price)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.red)

                Text("\(groups.count)件配件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BundleComparisonView(bundleIds: [])
        .environmentObject(DataManager.shared)
}
