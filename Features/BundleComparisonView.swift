import SwiftUI

// MARK: - Bundle Comparison View
struct BundleComparisonView: View {
    let bundleIds: [UUID]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedBundleId: IdentifiableUUID?

    // 获取所有套餐数据（按价格从低到高排序）
    private var bundlesData: [(bundle: Bundle, groups: [BundleAccessoryGroup])] {
        bundleIds.compactMap { bundleId in
            dataManager.bundleWithAccessoryGroups(for: bundleId)
        }.sorted { $0.bundle.price < $1.bundle.price }
    }

    // 获取套餐涉及的分类（去重）
    private func getCategories(for bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> [AccessoryCategory] {
        var categorySet = Set<UUID>()
        var categories: [AccessoryCategory] = []

        for group in bundleData.groups {
            guard let categoryId = group.accessory.categoryId,
                  !categorySet.contains(categoryId),
                  let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else { continue }
            categorySet.insert(categoryId)
            categories.append(category)
        }

        return categories.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(bundlesData, id: \.bundle.id) { data in
                        BundleComparisonCard(
                            bundle: data.bundle,
                            categories: getCategories(for: data),
                            onTap: {
                                selectedBundleId = IdentifiableUUID(id: data.bundle.id)
                            }
                        )
                    }
                }
                .padding(16)
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

// MARK: - Bundle Comparison Card
struct BundleComparisonCard: View {
    let bundle: Bundle
    let categories: [AccessoryCategory]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 套餐名称
                Text(bundle.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                // 价格
                Text("¥\(bundle.price)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 12)

                // 品类列表
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(categories) { category in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.green)
                                .frame(width: 18)

                            Text(category.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity)
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
