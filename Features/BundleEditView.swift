import SwiftUI

struct BundleEditView: View {
    let categoryId: UUID
    let bundle: Bundle?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var priceText = ""
    @State private var selectedItems: [BundleAccessoryItem] = []
    @State private var showingAccessoryPicker = false
    @State private var showingDeleteAlert = false
    @State private var expandedCategories: Set<UUID?> = []
    @FocusState private var focusedField: Field?
    
    private enum Field: Int, Hashable {
        case name, price
    }

    private var isEditing: Bool { bundle != nil }
    private var price: Int { Int(priceText) ?? 0 }
    
    // 按分类分组已选配件
    private var groupedItems: [(category: AccessoryCategory?, items: [BundleAccessoryItem])] {
        var groups: [UUID?: [BundleAccessoryItem]] = [:]
        
        for item in selectedItems {
            let accessory = dataManager.accessories.first { $0.id == item.accessoryId }
            let catId = accessory?.categoryId
            groups[catId, default: []].append(item)
        }
        
        return groups.map { (catId, items) in
            let category = catId.flatMap { id in
                dataManager.accessoryCategories.first { $0.id == id }
            }
            return (category, items)
        }.sorted { a, b in
            let orderA = a.category?.order ?? Int.max
            let orderB = b.category?.order ?? Int.max
            return orderA < orderB
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 套餐信息
                    VStack(spacing: 0) {
                        HStack {
                            Text("套餐信息")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        VStack(spacing: 0) {
                            HStack {
                                Text("套餐名称")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("请输入名称", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .name)
                            }
                            .padding(16)

                            Divider().padding(.leading, 16)

                            HStack {
                                Text("套餐价格")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("元", text: $priceText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .price)
                            }
                            .padding(16)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // 已添加配件 - 按分类折叠显示
                    VStack(spacing: 0) {
                        HStack {
                            Text("已添加配件")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !selectedItems.isEmpty {
                                Text("共\(selectedItems.count)件配件，\(groupedItems.count)个分类")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        if selectedItems.isEmpty {
                            Text("暂无配件，点击下方添加")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(groupedItems, id: \.category?.id) { category, items in
                                    categorySection(category: category, items: items)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }

                    // 添加配件按钮
                    Button {
                        showingAccessoryPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加配件")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    // 删除按钮
                    if isEditing {
                        Button(role: .destructive) { showingDeleteAlert = true } label: {
                            Text("删除此套餐")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 300)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "编辑套餐" : "新建套餐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveBundle() }
                        .disabled(name.isEmpty || price <= 0)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .sheet(isPresented: $showingAccessoryPicker) {
                AccessoryPickerSheet(selectedItems: $selectedItems)
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { deleteBundle() }
            } message: {
                Text("确定要删除这个套餐吗？")
            }
            .onAppear { loadData() }
        }
    }

    private func categorySection(category: AccessoryCategory?, items: [BundleAccessoryItem]) -> some View {
        let catId = category?.id as UUID?
        let isExpanded = expandedCategories.contains(catId)
        
        return VStack(spacing: 0) {
            // 分类标题行 - 点击展开/折叠
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedCategories.remove(catId)
                    } else {
                        expandedCategories.insert(catId)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(category?.name ?? "未分类")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("(\(items.count))")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            // 展开的配件列表
            if isExpanded {
                Divider().padding(.leading, 16)
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        accessoryItemRow(item)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func accessoryItemRow(_ item: BundleAccessoryItem) -> some View {
        let accessory = dataManager.accessories.first { $0.id == item.accessoryId }
        return HStack(spacing: 14) {
            Group {
                if let imagePath = item.customImagePath ?? accessory?.thumbnailPaths.first,
                   let image = ImageStorage.shared.loadImage(filename: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.customName ?? accessory?.name ?? "未知配件")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text("¥\(item.customPrice ?? accessory?.price ?? 0)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 删除按钮
            Button {
                removeItem(item)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private func removeItemsAtOffsets(at offsets: IndexSet) {
        selectedItems.remove(atOffsets: offsets)
    }

    private func loadData() {
        if let bundle = bundle {
            name = bundle.name
            priceText = String(bundle.price)
            selectedItems = dataManager.items(for: bundle.id)
        }
    }

    private func removeItem(_ item: BundleAccessoryItem) {
        selectedItems.removeAll { $0.id == item.id }
    }

    private func saveBundle() {
        if var existingBundle = bundle {
            existingBundle.name = name
            existingBundle.price = price
            dataManager.updateBundle(existingBundle)
            dataManager.deleteAllItems(for: existingBundle.id)
            for (index, item) in selectedItems.enumerated() {
                dataManager.addItem(BundleAccessoryItem(
                    bundleId: existingBundle.id,
                    accessoryId: item.accessoryId,
                    customName: item.customName,
                    customPrice: item.customPrice,
                    customImagePath: item.customImagePath,
                    quantity: item.quantity,
                    order: index
                ))
            }
        } else {
            let maxOrder = dataManager.bundles(for: categoryId).map(\.order).max() ?? -1
            let newBundle = Bundle(name: name, price: price, categoryId: categoryId, order: maxOrder + 1)
            dataManager.addBundle(newBundle)
            for (index, item) in selectedItems.enumerated() {
                dataManager.addItem(BundleAccessoryItem(
                    bundleId: newBundle.id,
                    accessoryId: item.accessoryId,
                    customName: item.customName,
                    customPrice: item.customPrice,
                    customImagePath: item.customImagePath,
                    quantity: item.quantity,
                    order: index
                ))
            }
        }
        dismiss()
    }

    private func deleteBundle() {
        if let bundle = bundle {
            dataManager.deleteBundle(bundle.id)
        }
        dismiss()
    }
}

// MARK: - Accessory Picker Sheet
struct AccessoryPickerSheet: View {
    @Binding var selectedItems: [BundleAccessoryItem]
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var addedAccessoryIds: Set<UUID> = []

    private var categories: [AccessoryCategory] {
        dataManager.accessoryCategories.sorted { $0.order < $1.order }
    }

    private var filteredAccessories: [Accessory] {
        var result = dataManager.accessories.sorted { $0.order < $1.order }
        
        // 先按分类筛选
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.categoryId == categoryId }
        }
        
        // 再按搜索文本筛选
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    private func isAdded(_ accessory: Accessory) -> Bool {
        addedAccessoryIds.contains(accessory.id) || selectedItems.contains { $0.accessoryId == accessory.id }
    }

    // 检查当前筛选的配件是否全部已选
    private var isAllFilteredSelected: Bool {
        !filteredAccessories.isEmpty && filteredAccessories.allSatisfy { isAdded($0) }
    }
    
    // 全选/取消全选当前筛选的配件
    private func toggleSelectAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isAllFilteredSelected {
                // 取消全选：移除当前筛选的配件
                let filteredIds = Set(filteredAccessories.map { $0.id })
                selectedItems.removeAll { filteredIds.contains($0.accessoryId) }
                addedAccessoryIds.subtract(filteredIds)
            } else {
                // 全选：添加当前筛选的所有未选配件
                for accessory in filteredAccessories where !isAdded(accessory) {
                    let newItem = BundleAccessoryItem(
                        bundleId: UUID(),
                        accessoryId: accessory.id,
                        quantity: 1,
                        order: selectedItems.count
                    )
                    selectedItems.append(newItem)
                    addedAccessoryIds.insert(accessory.id)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterChip(
                            title: "全部",
                            isSelected: selectedCategoryId == nil,
                            onTap: { selectedCategoryId = nil }
                        )
                        
                        ForEach(categories) { category in
                            CategoryFilterChip(
                                title: category.name,
                                isSelected: selectedCategoryId == category.id,
                                onTap: { selectedCategoryId = category.id }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // 配件列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAccessories) { accessory in
                            Button {
                                toggleAccessory(accessory)
                            } label: {
                                HStack {
                                    Group {
                                        if let imagePath = accessory.thumbnailPaths.first,
                                           let image = ImageStorage.shared.loadImage(filename: imagePath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Image(systemName: "photo")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .background(Color.gray.opacity(0.1))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(accessory.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)

                                        Text("¥\(accessory.price)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    
                                    // 选中/未选中状态
                                    if isAdded(accessory) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .font(.title2)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(.plain)
                            
                            Divider().padding(.leading, 78)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索配件")
            .navigationTitle("选择配件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        toggleSelectAll()
                    } label: {
                        if filteredAccessories.isEmpty {
                            Text("全选")
                                .foregroundStyle(.gray)
                        } else {
                            Text(isAllFilteredSelected ? "取消全选" : "全选")
                        }
                    }
                    .disabled(filteredAccessories.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成(\(selectedItems.count))") { dismiss() }
                }
            }
        }
    }

    private func toggleAccessory(_ accessory: Accessory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isAdded(accessory) {
                // 已选中 → 取消选中
                selectedItems.removeAll { $0.accessoryId == accessory.id }
                addedAccessoryIds.remove(accessory.id)
            } else {
                // 未选中 → 选中
                let newItem = BundleAccessoryItem(
                    bundleId: UUID(),
                    accessoryId: accessory.id,
                    quantity: 1,
                    order: selectedItems.count
                )
                selectedItems.append(newItem)
                addedAccessoryIds.insert(accessory.id)
            }
        }
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BundleEditView(categoryId: UUID(), bundle: nil)
        .environmentObject(DataManager.shared)
}
