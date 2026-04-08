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
            List {
                Section("套餐信息") {
                    TextField("套餐名称", text: $name)
                        .focused($focusedField, equals: .name)
                    TextField("套餐价格", text: $priceText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .price)
                }
                
                // 已添加配件 - 按分类横向显示
                ForEach(groupedItems, id: \.category?.id) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // 分类名称
                        Text(group.category?.name ?? "未分类")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        
                        // 配件横向滚动
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(group.items) { item in
                                    accessoryItemCard(item)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button { showingAccessoryPicker = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加配件")
                        }
                        .foregroundStyle(.blue)
                    }
                } footer: {
                    if !selectedItems.isEmpty {
                        Text("共\(selectedItems.count)件配件")
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) { showingDeleteAlert = true } label: {
                            HStack {
                                Spacer()
                                Text("删除此套餐")
                                Spacer()
                            }
                        }
                    }
                }
                
                // 底部预留空间，防止键盘遮挡
                Section {
                    Color.clear
                        .frame(height: 400)
                }
                .listRowBackground(Color.clear)
            }
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

    private func accessoryItemCard(_ item: BundleAccessoryItem) -> some View {
        let accessory = dataManager.accessories.first { $0.id == item.accessoryId }
        return HStack(spacing: 10) {
            Group {
                if let imagePath = item.customImagePath ?? accessory?.imagePath,
                   let image = ImageStorage.shared.loadImage(filename: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(Color.gray.opacity(0.1))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.customName ?? accessory?.name ?? "未知配件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("¥\(item.customPrice ?? accessory?.price ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            // 删除按钮
            Button {
                removeItem(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.gray.opacity(0.6))
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
    
    private func quantityFor(_ accessory: Accessory) -> Int {
        selectedItems.filter { $0.accessoryId == accessory.id }.count
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
                List {
                    ForEach(filteredAccessories) { accessory in
                        Button {
                            addAccessory(accessory)
                        } label: {
                            HStack {
                                Group {
                                    if let imagePath = accessory.imagePath,
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
                                
                                // 添加状态显示
                                if isAdded(accessory) {
                                    let qty = quantityFor(accessory)
                                    HStack(spacing: 6) {
                                        if qty > 1 {
                                            Text("x\(qty)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.green)
                                        }
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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

    private func addAccessory(_ accessory: Accessory) {
        let newItem = BundleAccessoryItem(
            bundleId: UUID(),
            accessoryId: accessory.id,
            quantity: 1,
            order: selectedItems.count
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedItems.append(newItem)
            addedAccessoryIds.insert(accessory.id)
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
