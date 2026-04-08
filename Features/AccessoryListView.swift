import SwiftUI

// MARK: - Image Storage
class ImageStorage {
    static let shared = ImageStorage()

    private var imagesDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documents.appendingPathComponent("Images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        return imagesDir
    }

    func saveImage(_ image: UIImage, for id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(id.uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    func loadImage(filename: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteImage(filename: String) {
        let url = imagesDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Accessory List View (分类列表风格)
struct AccessoryListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var showingAddSheet = false
    @State private var showingCategoryManagement = false
    @State private var showAllAccessories = false
    @State private var dragItem: AccessoryCategory?
    @State private var dragOffset: CGFloat = 0
    @State private var dragTargetIndex: Int?
    @State private var localCategories: [AccessoryCategory] = []
    @State private var longPressItem: AccessoryCategory?

    private var sortedCategories: [AccessoryCategory] {
        dataManager.accessoryCategories.sorted { $0.order < $1.order }
    }
    
    private var currentCategories: [AccessoryCategory] {
        localCategories.isEmpty ? sortedCategories : localCategories
    }

    private func accessories(for categoryId: UUID) -> [Accessory] {
        dataManager.accessories.filter { $0.categoryId == categoryId }.sorted { $0.order < $1.order }
    }

    private var allAccessories: [Accessory] {
        dataManager.accessories.sorted { $0.order < $1.order }
    }

    private var unassignedAccessories: [Accessory] {
        dataManager.accessories.filter { $0.categoryId == nil }.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 全部配件概览（不参与排序）
                CategorySectionView(
                    category: nil,
                    categoryName: "全部配件",
                    categoryIcon: "cube.box.fill",
                    categoryColor: .blue,
                    accessoryCount: dataManager.accessories.count,
                    onTap: { showAllAccessories = true },
                    onAddAccessory: { showingAddSheet = true }
                )

                // 分类列表（可拖拽排序）
                CategoryDragListView(
                    categories: currentCategories,
                    dragItem: dragItem,
                    dragOffset: dragOffset,
                    dragTargetIndex: dragTargetIndex,
                    longPressItem: longPressItem,
                    onSelectCategory: { selectedCategoryId = $0 },
                    onDragStart: startDrag,
                    onDragUpdate: updateDrag,
                    onDragEnd: endDrag,
                    onLongPress: { longPressItem = $0 }
                )

                // 未分类配件（不参与排序）
                if !unassignedAccessories.isEmpty {
                    CategorySectionView(
                        category: nil,
                        categoryName: "未分类",
                        categoryIcon: "tray.fill",
                        categoryColor: .gray,
                        accessoryCount: unassignedAccessories.count,
                        onTap: { 
                            selectedCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
                        },
                        onAddAccessory: { showingAddSheet = true }
                    )
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("配件库管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingAddSheet = true } label: {
                        Label("添加配件", systemImage: "plus")
                    }
                    Button { showingCategoryManagement = true } label: {
                        Label("管理分类", systemImage: "folder.badge.gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AccessoryEditView(accessory: nil)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            AccessoryCategoryManagementView()
        }
        .sheet(isPresented: $showAllAccessories) {
            CategoryAccessoriesSheet(
                categoryName: "全部配件",
                accessories: allAccessories,
                onAddAccessory: { showingAddSheet = true }
            )
        }
        .sheet(item: Binding(
            get: { selectedCategoryId.flatMap { IdentifiableUUID(id: $0) } },
            set: { selectedCategoryId = $0?.id }
        )) { identifiableId in
            let category = sortedCategories.first { $0.id == identifiableId.id }
            let unassignedId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
            
            if identifiableId.id == unassignedId {
                CategoryAccessoriesSheet(
                    categoryName: "未分类",
                    accessories: unassignedAccessories,
                    onAddAccessory: { showingAddSheet = true }
                )
            } else if let category = category {
                CategoryAccessoriesSheet(
                    categoryName: category.name,
                    accessories: accessories(for: category.id),
                    onAddAccessory: { showingAddSheet = true }
                )
            }
        }
        .onAppear { localCategories = sortedCategories }
        .onChange(of: sortedCategories) { localCategories = $0 }
    }
    
    private func categoryColor(for category: AccessoryCategory) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan, .red, .indigo]
        let index = abs(category.id.hashValue) % colors.count
        return colors[index]
    }
    
    private func startDrag(_ category: AccessoryCategory, _ index: Int, _ categories: [AccessoryCategory]) {
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        dragItem = category
        dragTargetIndex = index
        localCategories = categories.isEmpty ? sortedCategories : categories
        longPressItem = nil
    }
    
    private func updateDrag(_ offset: CGFloat, _ targetIndex: Int?) {
        dragOffset = offset
        if let targetIndex = targetIndex {
            dragTargetIndex = targetIndex
        }
    }
    
    private func endDrag(_ category: AccessoryCategory, _ currentIndex: Int, _ newIndex: Int) {
        if currentIndex != newIndex {
            // 位置改变时的震动反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let movedItem = localCategories.remove(at: currentIndex)
                localCategories.insert(movedItem, at: newIndex)
            }
            dataManager.updateAccessoryCategoryOrders(categories: localCategories)
        }
        
        longPressItem = nil
        dragItem = nil
        dragOffset = 0
        dragTargetIndex = nil
    }
}

// Helper for identifiable UUID
struct IdentifiableUUID: Identifiable {
    let id: UUID
}

// MARK: - Category Drag List View (容器视图，避免编译器超时)
struct CategoryDragListView: View {
    let categories: [AccessoryCategory]
    let dragItem: AccessoryCategory?
    let dragOffset: CGFloat
    let dragTargetIndex: Int?
    let longPressItem: AccessoryCategory?
    let onSelectCategory: (UUID) -> Void
    let onDragStart: (AccessoryCategory, Int, [AccessoryCategory]) -> Void
    let onDragUpdate: (CGFloat, Int?) -> Void
    let onDragEnd: (AccessoryCategory, Int, Int) -> Void
    let onLongPress: (AccessoryCategory) -> Void
    
    private func categoryColor(for category: AccessoryCategory) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan, .red, .indigo]
        let index = abs(category.id.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
            DraggableCategoryRow(
                category: category,
                index: index,
                dragItem: dragItem,
                dragOffset: dragOffset,
                dragTargetIndex: dragTargetIndex,
                longPressItem: longPressItem,
                localCategories: categories,
                categoryColor: categoryColor(for: category),
                onTap: { onSelectCategory(category.id) },
                onDragStart: onDragStart,
                onDragUpdate: onDragUpdate,
                onLongPress: onLongPress,
                onDragEnd: onDragEnd
            )
        }
    }
}

// MARK: - Draggable Category Row
struct DraggableCategoryRow: View {
    let category: AccessoryCategory
    let index: Int
    let dragItem: AccessoryCategory?
    let dragOffset: CGFloat
    let dragTargetIndex: Int?
    let longPressItem: AccessoryCategory?
    let localCategories: [AccessoryCategory]
    let categoryColor: Color
    let onTap: () -> Void
    let onDragStart: (AccessoryCategory, Int, [AccessoryCategory]) -> Void
    let onDragUpdate: (CGFloat, Int?) -> Void
    let onLongPress: (AccessoryCategory) -> Void
    let onDragEnd: (AccessoryCategory, Int, Int) -> Void
    
    @State private var pressStartTime: Date?
    @State private var hasTriggeredLongPress = false
    
    private var isDraggingThis: Bool { dragItem?.id == category.id }
    private var isLongPressed: Bool { longPressItem?.id == category.id && dragItem == nil }
    
    // 动态 zIndex：被拖拽或长按的元素显示在最上层
    private var dynamicZIndex: Double {
        if isDraggingThis || isLongPressed {
            return Double(localCategories.count) + 1
        }
        return Double(index)
    }
    
    private var rowOffset: CGFloat {
        guard let dragItem = dragItem,
              let dragIndex = localCategories.firstIndex(where: { $0.id == dragItem.id }),
              let targetIndex = dragTargetIndex else { return 0 }
        let rowHeight: CGFloat = 72
        if dragIndex < targetIndex {
            if index > dragIndex && index <= targetIndex { return -rowHeight }
        } else if dragIndex > targetIndex {
            if index >= targetIndex && index < dragIndex { return rowHeight }
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                if let customPath = category.customIconPath,
                   let customImage = ImageStorage.shared.loadImage(filename: customPath) {
                    Image(uiImage: customImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(categoryColor)
                }
            }

            // 标题和数量
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .offset(y: isDraggingThis ? dragOffset : rowOffset)
        .zIndex(dynamicZIndex)
        .opacity(isDraggingThis ? 0.9 : 1)
        .scaleEffect(isDraggingThis || isLongPressed ? 1.02 : 1)
        .shadow(color: isDraggingThis ? .black.opacity(0.2) : .clear, radius: 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragItem != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragTargetIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: longPressItem != nil)
        .contentShape(Rectangle())
        // 长按手势 - 用于放大效果
        .onLongPressGesture(minimumDuration: 0.3) {
            if dragItem == nil {
                pressStartTime = Date()
                hasTriggeredLongPress = true
                onLongPress(category)
            }
        }
        // 点击手势 - 用于导航
        .onTapGesture {
            onTap()
        }
        // 拖拽手势 - 移动超过 15px 才触发
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    // 如果已经长按或正在拖拽，继续处理
                    if hasTriggeredLongPress || dragItem?.id == category.id {
                        if dragItem == nil {
                            onDragStart(category, index, localCategories)
                        }
                        if isDraggingThis {
                            let rowHeight: CGFloat = 72
                            let currentIndex = localCategories.firstIndex(where: { $0.id == category.id }) ?? 0
                            let moveOffset = Int(round(value.translation.height / rowHeight))
                            let newIndex = max(0, min(localCategories.count - 1, currentIndex + moveOffset))
                            onDragUpdate(value.translation.height, newIndex != dragTargetIndex ? newIndex : nil)
                        }
                    }
                }
                .onEnded { value in
                    if isDraggingThis {
                        let rowHeight: CGFloat = 72
                        let currentIndex = localCategories.firstIndex(where: { $0.id == category.id }) ?? 0
                        let moveOffset = Int(round(value.translation.height / rowHeight))
                        let newIndex = max(0, min(localCategories.count - 1, currentIndex + moveOffset))
                        onDragEnd(category, currentIndex, newIndex)
                    }
                    pressStartTime = nil
                    hasTriggeredLongPress = false
                }
        )
    }
}

// MARK: - Category Section View (简洁版 - 不可拖拽)
struct CategorySectionView: View {
    let category: AccessoryCategory?
    let categoryName: String
    let categoryIcon: String
    let categoryColor: Color
    var customIconPath: String? = nil
    let accessoryCount: Int
    let onTap: () -> Void
    let onAddAccessory: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    if let customPath = customIconPath,
                       let customImage = ImageStorage.shared.loadImage(filename: customPath) {
                        Image(uiImage: customImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: categoryIcon)
                            .font(.title3)
                            .foregroundStyle(categoryColor)
                    }
                }

                // 标题和数量
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(accessoryCount == 0 ? "暂无配件" : "\(accessoryCount) 件配件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Category Accessories Sheet (底部弹出的配件列表)
struct CategoryAccessoriesSheet: View {
    let categoryName: String
    let accessories: [Accessory]
    let onAddAccessory: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if accessories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("暂无配件")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Button {
                            dismiss()
                            onAddAccessory()
                        } label: {
                            Text("添加配件")
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(accessories) { accessory in
                        NavigationLink(destination: AccessoryDetailView(accessory: accessory)) {
                            AccessoryCompactRow(accessory: accessory)
                        }
                    }
                }
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        onAddAccessory()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Accessory Compact Row
struct AccessoryCompactRow: View {
    let accessory: Accessory
    @EnvironmentObject var dataManager: DataManager

    private var categoryName: String? {
        guard let categoryId = accessory.categoryId else { return nil }
        return dataManager.accessoryCategories.first(where: { $0.id == categoryId })?.name
    }

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            if let imagePath = accessory.imagePath,
               let image = ImageStorage.shared.loadImage(filename: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let category = categoryName {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(accessory.price)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Accessory Product Row (淘宝商品行)
struct AccessoryProductRow: View {
    let accessory: Accessory
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            if let imagePath = accessory.imagePath,
               let image = ImageStorage.shared.loadImage(filename: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                // 商品名称
                Text(accessory.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // 分类标签
                if let categoryId = accessory.categoryId,
                   let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) {
                    Text(category.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(accessory.price)")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Accessory Detail View (商品详情页)
struct AccessoryDetailView: View {
    let accessory: Accessory
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditAccessory = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 商品主图和基本信息
                productHeaderCard

                // 商品简介
                if let description = accessory.description, !description.isEmpty {
                    descriptionCard(description)
                }

                // 详情图片
                if let detailImages = accessory.detailImages, !detailImages.isEmpty {
                    detailImagesSection(detailImages)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("商品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEditAccessory = true } label: {
                        Label("编辑商品", systemImage: "pencil")
                    }
                    Button(role: .destructive) { deleteAccessory() } label: {
                        Label("删除商品", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditAccessory) {
            AccessoryEditView(accessory: accessory)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var productHeaderCard: some View {
        HStack(spacing: 16) {
            // 商品主图
            if let imagePath = accessory.imagePath,
               let image = ImageStorage.shared.loadImage(filename: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(accessory.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("¥\(accessory.price)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

                if let categoryId = accessory.categoryId,
                   let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) {
                    Text(category.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func descriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("商品简介")
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailImagesSection(_ imagePaths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("商品详情")
                .font(.headline)
                .padding(.horizontal, 4)

            // 竖向排列详情图（类似淘宝详情页）
            VStack(spacing: 8) {
                ForEach(imagePaths.indices, id: \.self) { index in
                    if let image = ImageStorage.shared.loadImage(filename: imagePaths[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func deleteAccessory() {
        // 删除所有图片
        if let path = accessory.imagePath {
            ImageStorage.shared.deleteImage(filename: path)
        }
        accessory.detailImages?.forEach { ImageStorage.shared.deleteImage(filename: $0) }
        dataManager.deleteAccessory(accessory.id)
        dismiss()
    }
}

// MARK: - Accessory Category Management View
struct AccessoryCategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddCategory = false
    @State private var categoryToEdit: AccessoryCategory?

    var body: some View {
        NavigationStack {
            List {
                ForEach(dataManager.accessoryCategories.sorted { $0.order < $1.order }) { category in
                    Button {
                        categoryToEdit = category
                    } label: {
                        HStack {
                            // 显示图标
                            if let customPath = category.customIconPath,
                               let customImage = ImageStorage.shared.loadImage(filename: customPath) {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28, height: 28)
                            }

                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            let count = dataManager.accessories.filter { $0.categoryId == category.id }.count
                            Text("\(count)个配件")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    let sorted = dataManager.accessoryCategories.sorted { $0.order < $1.order }
                    for index in indexSet {
                        dataManager.deleteAccessoryCategory(sorted[index].id)
                    }
                }
            }
            .navigationTitle("管理分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddCategory = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AccessoryCategoryEditView(category: nil)
            }
            .sheet(item: $categoryToEdit) { category in
                AccessoryCategoryEditView(category: category)
            }
        }
    }
}

// MARK: - Accessory Category Edit View
struct AccessoryCategoryEditView: View {
    let category: AccessoryCategory?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var customIconImage: UIImage?
    @State private var showIconPicker = false
    @State private var showPhotoPicker = false

    private var isEditing: Bool { category != nil }

    var body: some View {
        NavigationStack {
            Form {
                // 预览
                Section {
                    HStack {
                        Spacer()
                        HStack(spacing: 12) {
                            // 图标预览
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 50, height: 50)

                                if let customImage = customIconImage {
                                    Image(uiImage: customImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 30, height: 30)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: selectedIcon)
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                            }

                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.headline)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } header: {
                    Text("预览")
                }

                Section("分类名称") {
                    TextField("请输入分类名称", text: $name)
                }

                Section {
                    // 选择系统图标
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            if let customImage = customIconImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text("自定义图标")
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: selectedIcon)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                Text("选择系统图标")
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 上传自定义图标
                    Button {
                        showPhotoPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            Text("上传自定义图标")
                                .foregroundStyle(.primary)
                            Spacer()
                            if customIconImage != nil {
                                Text("已上传")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text("图标设置")
                } footer: {
                    Text("可以选择系统图标或上传自己的图标")
                }
            }
            .navigationTitle(isEditing ? "编辑分类" : "添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCategory() }
                        .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon, customIconImage: $customIconImage)
            }
            .fullScreenCover(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $customIconImage, isPresented: $showPhotoPicker)
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedIcon = category.icon
                    if let customPath = category.customIconPath {
                        customIconImage = ImageStorage.shared.loadImage(filename: customPath)
                    }
                }
            }
        }
    }

    private func saveCategory() {
        var customIconPath: String? = nil

        // 保存自定义图标
        if let customImage = customIconImage {
            let iconId = category?.id ?? UUID()
            customIconPath = ImageStorage.shared.saveImage(customImage, for: iconId)
        }

        if let existingCategory = category {
            var updated = existingCategory
            updated.name = name
            updated.icon = selectedIcon
            updated.customIconPath = customIconPath
            dataManager.updateAccessoryCategory(updated)
        } else {
            let maxOrder = dataManager.accessoryCategories.map(\.order).max() ?? -1
            let newCategory = AccessoryCategory(
                name: name,
                icon: selectedIcon,
                customIconPath: customIconPath,
                order: maxOrder + 1
            )
            dataManager.addAccessoryCategory(newCategory)
        }
        dismiss()
    }
}

// MARK: - Icon Picker Sheet
struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    @Binding var customIconImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker = false

    // 数码3C相关图标列表（确定存在的 SF Symbol，50个凑成10行）
    private let commonIcons = [
        // 手机平板
        "iphone", "iphone.circle.fill", "ipad", "apple.logo", "gear",
        // 电脑
        "laptopcomputer", "desktopcomputer", "externaldrive.fill", "internaldrive", "opticaldisc",
        // 耳机音响
        "headphones", "speaker.wave.2", "music.note", "mic.fill", "mic",
        // 充电相关
        "bolt.fill", "bolt", "battery.100", "cable.connector", "wifi",
        // 数据存储
        "externaldrive", "opticaldisc.fill", "icloud.fill", "icloud", "square.and.arrow.down",
        // 外设配件
        "keyboard", "keyboard.fill", "wrench.and.screwdriver.fill", "printer.fill", "printer",
        // 显示器电视
        "tv", "tv.fill", "video.fill", "play.fill", "play.circle.fill",
        // 相机摄影
        "camera", "camera.fill", "photo", "photo.fill", "video",
        // 游戏娱乐
        "gamecontroller", "gamecontroller.fill", "gift.fill", "star.fill", "sparkles",
        // 其他常用
        "folder.fill", "folder", "cube.box", "shippingbox", "bag.fill"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 上传自定义图标
                    Button {
                        showPhotoPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                            Text("上传自定义图标")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // 系统图标
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(commonIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                customIconImage = nil // 清除自定义图标
                                dismiss()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon && customIconImage == nil ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        .frame(width: 56, height: 56)

                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(selectedIcon == icon && customIconImage == nil ? .blue : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $customIconImage, isPresented: $showPhotoPicker)
            }
            .onChange(of: customIconImage) { _ in
                if customIconImage != nil {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Accessory Edit View (淘宝商家后台编辑风格)
struct AccessoryEditView: View {
    let accessory: Accessory?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var selectedCategoryId: UUID?
    @State private var priceText = ""
    @State private var description = ""
    @State private var thumbnailImage: UIImage?
    @State private var detailImages: [UIImage] = []
    @State private var showThumbnailPicker = false
    @State private var showDetailImagePicker = false
    @FocusState private var focusedField: Field?
    
    private enum Field: Int, Hashable {
        case name, price, description
    }

    private var isEditing: Bool { accessory != nil }
    private var price: Int { Int(priceText) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 缩略图区域
                    thumbnailSection

                    // 基本信息
                    basicInfoSection

                    // 商品简介
                    descriptionSection

                    // 详情图片
                    detailImagesSection
                    
                    // 底部预留空间，防止键盘遮挡
                    Color.clear
                        .frame(height: 400)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "编辑商品" : "添加商品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAccessory() }
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
            .fullScreenCover(isPresented: $showThumbnailPicker) {
                PhotoPicker(selectedImage: $thumbnailImage, isPresented: $showThumbnailPicker)
            }
            .fullScreenCover(isPresented: $showDetailImagePicker) {
                MultiPhotoPicker(selectedImages: $detailImages, isPresented: $showDetailImagePicker)
            }
            .onAppear {
                if let accessory = accessory {
                    name = accessory.name
                    selectedCategoryId = accessory.categoryId
                    priceText = String(accessory.price)
                    description = accessory.description ?? ""
                    // 加载缩略图
                    if let mainPath = accessory.imagePath,
                       let mainImage = ImageStorage.shared.loadImage(filename: mainPath) {
                        thumbnailImage = mainImage
                    }
                    // 加载详情图片
                    if let imagePaths = accessory.detailImages {
                        for path in imagePaths {
                            if let img = ImageStorage.shared.loadImage(filename: path) {
                                detailImages.append(img)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 缩略图区域
    private var thumbnailSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("商品缩略图")
                    .font(.headline)
                Spacer()
            }

            Button {
                focusedField = nil
                showThumbnailPicker = true
            } label: {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .frame(width: 120, height: 120)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title)
                                Text("添加缩略图")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 基本信息
    private var basicInfoSection: some View {
        VStack(spacing: 0) {
            // 商品名称
            HStack {
                Text("商品名称")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("请输入名称", text: $name)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .name)
            }
            .padding(16)
            Divider().padding(.leading, 16)

            // 分类选择
            HStack {
                Text("商品分类")
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button {
                        selectedCategoryId = nil
                    } label: {
                        HStack {
                            Text("无分类")
                            if selectedCategoryId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(dataManager.accessoryCategories.sorted { $0.order < $1.order }) { category in
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            HStack {
                                Text(category.name)
                                if selectedCategoryId == category.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let categoryId = selectedCategoryId,
                           let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) {
                            Text(category.name)
                        } else {
                            Text("选择分类")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            Divider().padding(.leading, 16)

            // 价格
            HStack {
                Text("参考价格")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("元", text: $priceText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .focused($focusedField, equals: .price)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 商品简介
    private var descriptionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("商品简介")
                    .font(.headline)
                Spacer()
            }

            TextEditor(text: $description)
                .frame(minHeight: 100)
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("请输入商品简介描述...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 详情图片（竖向排列）
    private var detailImagesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("详情图片")
                    .font(.headline)
                Text("（竖向排列）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    focusedField = nil
                    showDetailImagePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.subheadline)
                }
            }

            if detailImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无详情图片")
                        .foregroundStyle(.secondary)
                    Text("添加详情图片将显示在商品详情页")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // 竖向排列预览
                VStack(spacing: 8) {
                    ForEach(detailImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: detailImages[index])
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                detailImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, .red)
                            }
                            .padding(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveAccessory() {
        // 保存缩略图
        var imagePath: String? = nil
        if let thumbnail = thumbnailImage {
            let mainId = accessory?.id ?? UUID()
            imagePath = ImageStorage.shared.saveImage(thumbnail, for: mainId)
        }

        // 保存详情图片
        var detailImagePaths: [String] = []
        for image in detailImages {
            let imgId = UUID()
            if let path = ImageStorage.shared.saveImage(image, for: imgId) {
                detailImagePaths.append(path)
            }
        }

        if let existingAccessory = accessory {
            // 删除旧图片
            if let oldPath = existingAccessory.imagePath, oldPath != imagePath {
                ImageStorage.shared.deleteImage(filename: oldPath)
            }
            existingAccessory.detailImages?.forEach { ImageStorage.shared.deleteImage(filename: $0) }

            var updated = existingAccessory
            updated.name = name
            updated.categoryId = selectedCategoryId
            updated.price = price
            updated.imagePath = imagePath
            updated.description = description.isEmpty ? nil : description
            updated.detailImages = detailImagePaths.isEmpty ? nil : detailImagePaths
            dataManager.updateAccessory(updated)
        } else {
            let maxOrder = dataManager.accessories.map(\.order).max() ?? -1
            let newAccessory = Accessory(
                name: name,
                categoryId: selectedCategoryId,
                price: price,
                imagePath: imagePath,
                description: description.isEmpty ? nil : description,
                detailImages: detailImagePaths.isEmpty ? nil : detailImagePaths,
                order: maxOrder + 1
            )
            dataManager.addAccessory(newAccessory)
        }
        dismiss()
    }
}

// MARK: - Multi Photo Picker
struct MultiPhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MultiPhotoPicker

        init(_ parent: MultiPhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImages.append(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

#Preview {
    NavigationStack {
        AccessoryListView()
            .environmentObject(DataManager.shared)
    }
}
