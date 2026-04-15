import SwiftUI

// UUID 的 Identifiable 包装器
struct IdentifiableUUID: Identifiable {
    let id: UUID
}

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

    // 合并所有配件名称，用于横向对比
    private var allAccessoryNames: [String] {
        var names = Set<String>()
        for (_, groups) in bundlesData {
            for group in groups {
                names.insert(group.accessory.name)
            }
        }
        return names.sorted()
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
                                isSelected: false,
                                onTap: {
                                    selectedBundleId = IdentifiableUUID(id: data.bundle.id)
                                }
                            )
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))

                    Divider()

                    // 配件对比列表
                    VStack(alignment: .leading, spacing: 0) {
                        Text("配件对比")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGroupedBackground))

                        VStack(spacing: 0) {
                            ForEach(allAccessoryNames, id: \.self) { accessoryName in
                                AccessoryComparisonRow(
                                    accessoryName: accessoryName,
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
    let isSelected: Bool
    let onTap: () -> Void

    private var totalPrice: Int {
        groups.reduce(0) { $0 + $1.totalPrice }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .frame(height: 32)

                Text(bundle.name)
                    .font(.subheadline.weight(.semibold))
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
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accessory Comparison Row
struct AccessoryComparisonRow: View {
    let accessoryName: String
    let bundlesData: [(bundle: Bundle, groups: [BundleAccessoryGroup])]

    private func hasAccessory(in bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> Bool {
        bundleData.groups.contains { $0.accessory.name == accessoryName }
    }

    private func accessoryDetails(in bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])) -> String? {
        guard let group = bundleData.groups.first(where: { $0.accessory.name == accessoryName }) else {
            return nil
        }
        if group.items.count == 1 {
            return group.items.first?.displayName
        }
        return "\(group.items.count)款可选"
    }

    var body: some View {
        HStack(spacing: 12) {
            // 配件名称
            Text(accessoryName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)

            Divider()

            // 各套餐的配件状态
            ForEach(bundlesData, id: \.bundle.id) { bundleData in
                if hasAccessory(in: bundleData) {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        if let detail = accessoryDetails(in: bundleData) {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.gray.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    BundleComparisonView(bundleIds: [])
        .environmentObject(DataManager.shared)
}
