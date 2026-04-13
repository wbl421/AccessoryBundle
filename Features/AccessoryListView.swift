import SwiftUI
import PhotosUI

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
        // 优先 JPEG，失败则用 PNG
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "\(id.uuidString).jpg"
            let url = imagesDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                return filename
            } catch {
                // JPEG 写入失败，尝试 PNG
            }
        }
        if let data = image.pngData() {
            let filename = "\(id.uuidString).png"
            let url = imagesDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                return filename
            } catch {
                return nil
            }
        }
        return nil
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

// MARK: - Image Carousel View (图片轮播，类似苹果官网效果)
struct ImageCarouselView: View {
    let images: [UIImage]
    var cornerRadius: CGFloat = 16
    var imageHeight: CGFloat = 300

    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            // 图片区域
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(height: imageHeight)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // 小点指示器（只有多张图才显示）
            if images.count > 1 {
                HStack(spacing: 8) {
                    ForEach(images.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(
                                width: index == currentIndex ? 20 : 8,
                                height: 8
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentIndex)
                    }
                }
            }
        }
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

    // 批量导入相关
    @State private var showingDocumentPicker = false
    @State private var parsedResult: ParsedImportResult?
    @State private var showingTemplateShare = false
    @State private var importErrorMessage: String?

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

    var body: some View {
        ZStack {
            // 主页面
            ScrollView {
                VStack(spacing: 12) {
                    // 全部配件概览（不参与排序）
                    CategorySectionView(
                        category: nil,
                        categoryName: "全部配件",
                        categoryIcon: "cube.box.fill",
                        categoryColor: .blue,
                        accessoryCount: dataManager.accessories.count,
                        onTap: { withAnimation { showAllAccessories = true } },
                        onAddAccessory: { showingAddSheet = true }
                    )

                    // 分类列表（可拖拽排序）
                    CategoryDragListView(
                        categories: currentCategories,
                        dragItem: dragItem,
                        dragOffset: dragOffset,
                        dragTargetIndex: dragTargetIndex,
                        longPressItem: longPressItem,
                        onSelectCategory: { withAnimation { selectedCategoryId = $0 } },
                        onDragStart: startDrag,
                        onDragUpdate: updateDrag,
                        onDragEnd: endDrag,
                        onLongPress: { longPressItem = $0 }
                    )
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))

            // 全屏配件列表（从右边滑入）
            if showAllAccessories {
                CategoryAccessoriesSheet(
                    categoryName: "全部配件",
                    allAccessories: allAccessories,
                    onAddAccessory: { showingAddSheet = true },
                    onDismiss: { withAnimation { showAllAccessories = false } }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }

            // 分类配件列表（从右边滑入）
            if let categoryId = selectedCategoryId {
                let category = sortedCategories.first { $0.id == categoryId }
                CategoryAccessoriesSheet(
                    categoryName: category?.name ?? "配件",
                    categoryId: categoryId,
                    onAddAccessory: { showingAddSheet = true },
                    onDismiss: { withAnimation { selectedCategoryId = nil } }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .navigationTitle("配件库管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingAddSheet = true } label: {
                        Label("添加配件", systemImage: "plus")
                    }
                    Button { showingDocumentPicker = true } label: {
                        Label("批量导入", systemImage: "square.and.arrow.down")
                    }
                    Button { showingTemplateShare = true } label: {
                        Label("下载模板", systemImage: "doc.text")
                    }
                    Button { showingCategoryManagement = true } label: {
                        Label("管理分类", systemImage: "folder.badge.gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("导入失败", isPresented: .constant(importErrorMessage != nil)) {
            Button("确定") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView { url in
                // 延迟执行，让 sheet 先关闭再打开 fullScreenCover，避免冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    parseImportFile(url: url)
                }
            }
        }
        .fullScreenCover(item: $parsedResult) { result in
            ImportPreviewView(result: result)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingTemplateShare) {
            if let templateURL = TemplateManager.shared.getTemplateURL() {
                ShareLink(item: templateURL, subject: Text("配件导入模板")) {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text("配件导入模板")
                            .font(.headline)
                        Text("点击分享或保存模板文件")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
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
        .onAppear { localCategories = sortedCategories }
        .onChange(of: sortedCategories) { localCategories = $0 }
    }
    
    private func categoryColor(for category: AccessoryCategory) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan, .red, .indigo]
        let index = abs(category.id.hashValue) % colors.count
        return colors[index]
    }
    
    // MARK: - 批量导入
    private func parseImportFile(url: URL) {
        let parser = ExcelParser()
        let result = parser.parseXLSX(at: url, existingCategories: dataManager.accessoryCategories)

        if result.accessories.isEmpty && !result.errors.isEmpty {
            importErrorMessage = result.errors.first?.message ?? "无法读取文件"
            return
        }

        if result.accessories.isEmpty {
            importErrorMessage = "文件中没有有效数据"
            return
        }

        parsedResult = result
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
    var categoryId: UUID? = nil
    var allAccessories: [Accessory]? = nil // 全部配件场景
    let onAddAccessory: () -> Void
    var onDismiss: () -> Void = {}
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false

    // 动态获取最新配件数据，编辑后自动刷新
    private var accessories: [Accessory] {
        if let categoryId = categoryId {
            return dataManager.accessories.filter { $0.categoryId == categoryId }.sorted { $0.order < $1.order }
        }
        if let all = allAccessories { return all }
        return dataManager.accessories.sorted { $0.order < $1.order }
    }

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
                            showingAddSheet = true
                        } label: {
                            Text("添加配件")
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(accessories) { accessory in
                        NavigationLink(destination: AccessoryDetailView(accessoryId: accessory.id)) {
                            AccessoryCompactRow(accessory: accessory)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    }
                }
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AccessoryEditView(accessory: nil, defaultCategoryId: categoryId)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .transition(.move(edge: .trailing))
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
        HStack(spacing: 8) {
            // 缩略图
            if let imagePath = accessory.thumbnailPaths.first,
               let image = ImageStorage.shared.loadImage(filename: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(accessory.price)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .offset(x: 8)
        }
        .padding(.trailing, 8)
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
            if let imagePath = accessory.thumbnailPaths.first,
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
    let accessoryId: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditAccessory = false

    private var accessory: Accessory? {
        dataManager.accessories.first(where: { $0.id == accessoryId })
    }

    var body: some View {
        Group {
            if let accessory = accessory {
                ScrollView {
                    VStack(spacing: 16) {
                        // 商品主图和基本信息
                        productHeaderCard(accessory)

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
            } else {
                Text("商品不存在")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func productHeaderCard(_ accessory: Accessory) -> some View {
        VStack(spacing: 16) {
            // 缩略图轮播
            let paths = accessory.thumbnailPaths
            let loadedImages = paths.compactMap { ImageStorage.shared.loadImage(filename: $0) }
            if loadedImages.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }
            } else {
                ImageCarouselView(images: loadedImages, cornerRadius: 12)
            }

            // 名称和价格
            HStack {
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

            // 竖向排列详情图，无缝拼接
            VStack(spacing: 0) {
                ForEach(imagePaths.indices, id: \.self) { index in
                    if let image = ImageStorage.shared.loadImage(filename: imagePaths[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func deleteAccessory() {
        guard let accessory = accessory else { return }
        // 删除所有图片
        for path in accessory.thumbnailPaths {
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
    var defaultCategoryId: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var selectedCategoryId: UUID?
    @State private var priceText = ""
    @State private var description = ""
    @State private var thumbnailImages: [UIImage] = []
    @State private var thumbnailImagePaths: [String?] = [] // 对应每张缩略图的文件路径，nil=新图片
    @State private var detailImages: [UIImage] = []
    @State private var detailImagePaths: [String?] = [] // 对应每张详情图的文件路径，nil=新图片
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
                MultiPhotoPicker(selectedImages: $thumbnailImages, isPresented: $showThumbnailPicker)
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
                    // 加载缩略图（兼容旧的 imagePath 和新的 imagePaths）
                    for path in accessory.thumbnailPaths {
                        if let img = ImageStorage.shared.loadImage(filename: path) {
                            thumbnailImages.append(img)
                            thumbnailImagePaths.append(path) // 已有路径，保存时不需要重新写入
                        }
                    }
                    // 加载详情图片
                    if let imgPaths = accessory.detailImages {
                        for path in imgPaths {
                            if let img = ImageStorage.shared.loadImage(filename: path) {
                                detailImages.append(img)
                                detailImagePaths.append(path) // 已有路径
                            }
                        }
                    }
                } else {
                    // 新建时，使用传入的默认分类
                    selectedCategoryId = defaultCategoryId
                }
            }
            .onChange(of: thumbnailImages) { newValue in
                // 新增的图片（picker添加的），路径标记为nil
                while thumbnailImagePaths.count < newValue.count {
                    thumbnailImagePaths.append(nil)
                }
            }
            .onChange(of: detailImages) { newValue in
                while detailImagePaths.count < newValue.count {
                    detailImagePaths.append(nil)
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
                if !thumbnailImages.isEmpty {
                    Button {
                        focusedField = nil
                        showThumbnailPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                }
            }

            if thumbnailImages.isEmpty {
                Button {
                    focusedField = nil
                    showThumbnailPicker = true
                } label: {
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
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(thumbnailImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: thumbnailImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button {
                                    thumbnailImagePaths.remove(at: index)
                                    thumbnailImages.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, .red)
                                }
                                .padding(4)
                            }
                        }

                        // 添加按钮
                        Button {
                            focusedField = nil
                            showThumbnailPicker = true
                        } label: {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                        Text("添加")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
                // 竖向排列预览，无缝拼接，每张图可单独删除
                VStack(spacing: 0) {
                    ForEach(detailImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: detailImages[index])
                                .resizable()
                                .scaledToFit()
                            
                            Button {
                                detailImagePaths.remove(at: index)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveAccessory() {
        // 保存缩略图：已有路径的直接复用，新图片才写入磁盘
        var savedThumbnailPaths: [String] = []
        for i in thumbnailImages.indices {
            if let existingPath = thumbnailImagePaths[i] {
                // 已有路径，不需要重新保存
                savedThumbnailPaths.append(existingPath)
            } else {
                // 新图片，保存到磁盘
                let imgId = UUID()
                if let path = ImageStorage.shared.saveImage(thumbnailImages[i], for: imgId) {
                    savedThumbnailPaths.append(path)
                }
            }
        }

        // 保存详情图片：同理
        var savedDetailPaths: [String] = []
        for i in detailImages.indices {
            if let existingPath = detailImagePaths[i] {
                savedDetailPaths.append(existingPath)
            } else {
                let imgId = UUID()
                if let path = ImageStorage.shared.saveImage(detailImages[i], for: imgId) {
                    savedDetailPaths.append(path)
                }
            }
        }

        if let existingAccessory = accessory {
            // 删除被移除的旧缩略图文件
            let oldThumbnailPaths = existingAccessory.thumbnailPaths
            for oldPath in oldThumbnailPaths {
                if !savedThumbnailPaths.contains(oldPath) {
                    ImageStorage.shared.deleteImage(filename: oldPath)
                }
            }
            // 删除被移除的旧详情图文件
            if let oldDetailPaths = existingAccessory.detailImages {
                for oldPath in oldDetailPaths {
                    if !savedDetailPaths.contains(oldPath) {
                        ImageStorage.shared.deleteImage(filename: oldPath)
                    }
                }
            }

            var updated = existingAccessory
            updated.name = name
            updated.categoryId = selectedCategoryId
            updated.price = price
            updated.imagePath = savedThumbnailPaths.first // 兼容旧字段
            updated.imagePaths = savedThumbnailPaths.isEmpty ? nil : savedThumbnailPaths
            updated.description = description.isEmpty ? nil : description
            updated.detailImages = savedDetailPaths.isEmpty ? nil : savedDetailPaths
            dataManager.updateAccessory(updated)
        } else {
            let maxOrder = dataManager.accessories.map(\.order).max() ?? -1
            let newAccessory = Accessory(
                name: name,
                categoryId: selectedCategoryId,
                price: price,
                imagePath: savedThumbnailPaths.first,
                imagePaths: savedThumbnailPaths.isEmpty ? nil : savedThumbnailPaths,
                description: description.isEmpty ? nil : description,
                detailImages: savedDetailPaths.isEmpty ? nil : savedDetailPaths,
                order: maxOrder + 1
            )
            dataManager.addAccessory(newAccessory)
        }
        dismiss()
    }
}

// MARK: - Multi Photo Picker (支持多选)
struct MultiPhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0  // 0 = 不限制，支持多选
        config.filter = .images
        config.selection = .ordered  // 显示选择顺序，类似微信
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoPicker

        init(_ parent: MultiPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                parent.isPresented = false
                return
            }

            let group = DispatchGroup()
            var imageDict: [Int: UIImage] = [:]

            for (index, result) in results.enumerated() {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    // 使用 loadDataRepresentation 获取原始图片数据，更可靠
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        if let data = data, let image = UIImage(data: data) {
                            // 确保 UIImage 有 CGImage（能正确 jpegData/pngData）
                            if image.cgImage != nil {
                                imageDict[index] = image
                            } else {
                                // CGImage 为 nil，通过重绘来生成有效的 UIImage
                                UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
                                image.draw(in: CGRect(origin: .zero, size: image.size))
                                if let redrawn = UIGraphicsGetImageFromCurrentImageContext() {
                                    imageDict[index] = redrawn
                                }
                                UIGraphicsEndImageContext()
                            }
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) { [self] in
                let sortedImages = imageDict.sorted(by: { $0.key < $1.key }).map(\.value)
                self.parent.selectedImages.append(contentsOf: sortedImages)
                self.parent.isPresented = false
            }
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
