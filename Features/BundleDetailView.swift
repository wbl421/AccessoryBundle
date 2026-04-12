import SwiftUI

// 用于传递详情数据的包装类型
struct DetailDisplayData: Identifiable {
    let id = UUID()
    let accessoryId: UUID
    let detail: BundleAccessoryGroup.AccessoryDetail
}

// 用于传递款式选择数据
struct StyleSelectData: Identifiable {
    let id = UUID()
    let group: BundleAccessoryGroup
}

struct BundleDetailView: View {
    let bundleId: UUID
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEdit = false
    @State private var showingPoster = false
    @State private var detailToDisplay: DetailDisplayData?
    @State private var styleSelectData: StyleSelectData?
    @State private var dragItem: BundleAccessoryGroup?
    @State private var dragOffset: CGFloat = 0
    @State private var dragTargetIndex: Int?
    @State private var localGroups: [BundleAccessoryGroup] = []
    @State private var longPressItem: BundleAccessoryGroup?
    @State private var isEditMode = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: BundleAccessoryGroup?

    private var bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])? {
        dataManager.bundleWithAccessoryGroups(for: bundleId)
    }

    var body: some View {
        ScrollView {
            if let data = bundleData {
                VStack(spacing: 20) {
                    priceComparisonSection(bundle: data.bundle, groups: data.groups)
                    accessoryListSection(groups: localGroups.isEmpty ? data.groups : localGroups)
                }
                .padding(16)
            } else {
                Text("加载中...")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(bundleData?.bundle.name ?? "套餐详情")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button { isEditMode.toggle() } label: {
                        Text(isEditMode ? "完成" : "编辑")
                            .fontWeight(.medium)
                    }
                    Button { showingPoster = true } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingEdit) {
            if let data = bundleData {
                BundleEditView(categoryId: data.bundle.categoryId, bundle: data.bundle)
            }
        }
        .sheet(isPresented: $showingPoster) {
            PosterStyleSelectView(bundleId: bundleId)
                .environmentObject(dataManager)
        }
        .sheet(item: $detailToDisplay) { data in
            AccessoryDetailPopupNew(accessoryId: data.accessoryId, detail: data.detail)
        }
        .sheet(item: $styleSelectData) { data in
            StyleSelectSheetTransform(group: data.group)
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                groupToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                }
                groupToDelete = nil
            }
        } message: {
            Text("确定要删除这个配件吗？")
        }
        .onAppear {
            if let data = bundleData {
                localGroups = data.groups
            }
        }
        .onChange(of: bundleData?.groups) { newValue in
            localGroups = newValue ?? []
        }
    }
    
    private func deleteGroup(_ group: BundleAccessoryGroup) {
        dataManager.deleteBundleAccessoryGroup(groupId: group.id)
        localGroups.removeAll { $0.id == group.id }
    }

    // 计算原价：每个分组只取一个商品的价格（客户只选一款）
    private func calculateOriginalPrice(_ groups: [BundleAccessoryGroup]) -> Int {
        groups.reduce(0) { $0 + ($1.items.first?.displayPrice ?? 0) }
    }

    private func priceComparisonSection(bundle: Bundle, groups: [BundleAccessoryGroup]) -> some View {
        let originalPrice = calculateOriginalPrice(groups)
        let bundlePrice = bundle.price
        let savings = originalPrice - bundlePrice
        let discount = originalPrice > 0 ? Double(bundlePrice) / Double(originalPrice) : 1.0

        return VStack(spacing: 16) {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("商品原价")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("¥\(originalPrice)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Text("套餐价")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Text("¥\(bundlePrice)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Text("立省")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("¥\(savings)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }

            if savings > 0 {
                HStack(spacing: 8) {
                    Spacer()
                    Text("约\(String(format: "%.1f", discount * 10))折")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    Spacer()
                }
            }
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func accessoryListSection(groups: [BundleAccessoryGroup]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("配件列表")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 4)

            if groups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "box.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无配件")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("点击右上角编辑按钮添加配件")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { idx, group in
                DraggableAccessoryGroupRow(
                    group: group,
                    index: idx,
                    dragItem: dragItem,
                    dragOffset: dragOffset,
                    dragTargetIndex: dragTargetIndex,
                    longPressItem: longPressItem,
                    localGroups: localGroups,
                    isEditMode: isEditMode,
                    onTap: {
                        if group.items.count == 1, let detail = group.items.first {
                            detailToDisplay = DetailDisplayData(accessoryId: detail.accessoryId, detail: detail)
                        } else {
                            styleSelectData = StyleSelectData(group: group)
                        }
                    },
                    onDragStart: { group, index, groups in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        dragItem = group
                        dragTargetIndex = index
                        localGroups = groups
                        longPressItem = nil
                    },
                    onDragUpdate: { offset, targetIndex in
                        dragOffset = offset
                        if let targetIndex = targetIndex {
                            if dragTargetIndex != targetIndex {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            dragTargetIndex = targetIndex
                        }
                    },
                    onDragEnd: { group, currentIndex, newIndex in
                        if currentIndex != newIndex {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                let movedItem = localGroups.remove(at: currentIndex)
                                localGroups.insert(movedItem, at: newIndex)
                            }
                            if let bundleId = bundleData?.bundle.id {
                                dataManager.updateGroupOrders(bundleId: bundleId, groups: localGroups)
                            }
                        }
                        longPressItem = nil
                        dragItem = nil
                        dragOffset = 0
                        dragTargetIndex = nil
                    },
                    onLongPress: { longPressItem = $0 },
                    onDelete: {
                        groupToDelete = group
                        showDeleteAlert = true
                    }
                )
            }
            }
        }
    }
}

// MARK: - Draggable Accessory Group Row
struct DraggableAccessoryGroupRow: View {
    let group: BundleAccessoryGroup
    let index: Int
    let dragItem: BundleAccessoryGroup?
    let dragOffset: CGFloat
    let dragTargetIndex: Int?
    let longPressItem: BundleAccessoryGroup?
    let localGroups: [BundleAccessoryGroup]
    var isEditMode: Bool = false
    let onTap: () -> Void
    let onDragStart: (BundleAccessoryGroup, Int, [BundleAccessoryGroup]) -> Void
    let onDragUpdate: (CGFloat, Int?) -> Void
    let onDragEnd: (BundleAccessoryGroup, Int, Int) -> Void
    let onLongPress: (BundleAccessoryGroup) -> Void
    let onDelete: () -> Void
    
    @State private var pressStartTime: Date?
    @State private var hasTriggeredLongPress = false
    
    private var isDraggingThis: Bool { dragItem?.id == group.id }
    private var isLongPressed: Bool { longPressItem?.id == group.id && dragItem == nil }
    
    // 动态 zIndex：被拖拽或长按的元素显示在最上层
    private var dynamicZIndex: Double {
        if isDraggingThis || isLongPressed {
            return Double(localGroups.count) + 1
        }
        return Double(index)
    }
    
    private var rowOffset: CGFloat {
        guard let dragItem = dragItem,
              let dragIndex = localGroups.firstIndex(where: { $0.id == dragItem.id }),
              let targetIndex = dragTargetIndex else { return 0 }
        let rowHeight: CGFloat = 86
        if dragIndex < targetIndex {
            if index > dragIndex && index <= targetIndex { return -rowHeight }
        } else if dragIndex > targetIndex {
            if index >= targetIndex && index < dragIndex { return rowHeight }
        }
        return 0
    }
    
    private func calculateNewIndex(translation: CGFloat) -> Int {
        let rowHeight: CGFloat = 86
        let currentIndex = localGroups.firstIndex(where: { $0.id == group.id }) ?? 0
        let moveOffset = Int(round(translation / rowHeight))
        return max(0, min(localGroups.count - 1, currentIndex + moveOffset))
    }

    var body: some View {
        Group {
            if isEditMode {
                // 编辑模式：使用 UIKit 手势实现长按+拖拽+滚动并存
                AccessoryGroupRow(group: group, isDragging: isDraggingThis || isLongPressed, isEditMode: isEditMode, onDelete: onDelete)
                    .offset(y: isDraggingThis ? dragOffset : rowOffset)
                    .zIndex(dynamicZIndex)
                    .opacity(isDraggingThis ? 0.9 : 1)
                    .scaleEffect(isDraggingThis || isLongPressed ? 1.02 : 1)
                    .shadow(color: isDraggingThis ? .black.opacity(0.2) : .clear, radius: 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragItem != nil)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragTargetIndex)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: longPressItem != nil)
                    .overlay(
                        GestureHandlingView(
                            onLongPress: {
                                if dragItem == nil {
                                    hasTriggeredLongPress = true
                                    onLongPress(group)
                                }
                            },
                            onDragChanged: { translation in
                                if hasTriggeredLongPress || dragItem?.id == group.id {
                                    if dragItem == nil {
                                        onDragStart(group, index, localGroups)
                                    }
                                    if isDraggingThis {
                                        let newIndex = calculateNewIndex(translation: translation)
                                        onDragUpdate(translation, newIndex != dragTargetIndex ? newIndex : nil)
                                    }
                                }
                            },
                            onDragEnded: { translation in
                                if isDraggingThis {
                                    let currentIndex = localGroups.firstIndex(where: { $0.id == group.id }) ?? 0
                                    let newIndex = calculateNewIndex(translation: translation)
                                    onDragEnd(group, currentIndex, newIndex)
                                }
                                hasTriggeredLongPress = false
                            }
                        )
                    )
                    // 删除按钮放在最顶层，确保可点击
                    .overlay(alignment: .leading) {
                        Button(action: onDelete) {
                            Color.clear
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .padding(.leading, 12)
                    }
            } else {
                // 非编辑模式：只能点击查看详情，ScrollView 正常滚动
                AccessoryGroupRow(group: group, isDragging: false)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap()
                    }
            }
        }
    }
}

// MARK: - Accessory Group Row
struct AccessoryGroupRow: View {
    let group: BundleAccessoryGroup
    var isDragging: Bool = false
    var isEditMode: Bool = false
    var onDelete: () -> Void = {}
    @EnvironmentObject var dataManager: DataManager

    private var categoryName: String {
        guard let categoryId = group.accessory.categoryId,
              let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else {
            return "未分类"
        }
        return category.name
    }

    // 获取分组中第一个有图片的配件图片
    private var displayImage: UIImage? {
        for item in group.items {
            if let imagePath = item.displayImagePath,
               let image = ImageStorage.shared.loadImage(filename: imagePath) {
                return image
            }
        }
        return nil
    }

    // 显示第一个明细的价格
    private var displayPrice: Int {
        group.items.first?.displayPrice ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // 编辑模式左侧显示删除图标（纯占位，实际点击在最外层overlay）
            if isEditMode {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
            }
            
            Group {
                if let image = displayImage {
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
                Text(categoryName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(displayPrice)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

                if !isEditMode {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 方案3: Style Select Sheet Transform (变形过渡 - 无缝切换)
struct StyleSelectSheetTransform: View {
    let group: BundleAccessoryGroup
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDetail: BundleAccessoryGroup.AccessoryDetail?

    private var categoryName: String {
        guard let categoryId = group.accessory.categoryId,
              let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else {
            return "选择款式"
        }
        return category.name
    }

    var body: some View {
        NavigationStack {
            Group {
                if let detail = selectedDetail {
                    // 详情视图
                    DetailContentView(accessoryId: detail.accessoryId, detail: detail)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                } else {
                    // 款式选择网格
                    ScrollView {
                        VStack(spacing: 16) {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(group.items) { detail in
                                    StyleCard(detail: detail) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            selectedDetail = detail
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selectedDetail == nil ? categoryName : "商品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .buttonStyle(.plain)
                }
                if selectedDetail != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedDetail = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 方案1: Style Select Sheet Parallel (并行过渡)
struct StyleSelectSheetParallel: View {
    let group: BundleAccessoryGroup
    let onDetailSelected: (BundleAccessoryGroup.AccessoryDetail) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    private var categoryName: String {
        guard let categoryId = group.accessory.categoryId,
              let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else {
            return "选择款式"
        }
        return category.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(group.items) { detail in
                            StyleCard(detail: detail) {
                                onDetailSelected(detail)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 方案2: Style Select Sheet (内部导航 - 内部切换详情)
struct StyleSelectSheet: View {
    let group: BundleAccessoryGroup
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDetail: BundleAccessoryGroup.AccessoryDetail?

    private var categoryName: String {
        guard let categoryId = group.accessory.categoryId,
              let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) else {
            return "选择款式"
        }
        return category.name
    }

    var body: some View {
        NavigationStack {
            Group {
                if let detail = selectedDetail {
                    // 详情视图
                    DetailContentView(accessoryId: detail.accessoryId, detail: detail)
                } else {
                    // 款式选择网格
                    ScrollView {
                        VStack(spacing: 16) {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(group.items) { detail in
                                    StyleCard(detail: detail) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedDetail = detail
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selectedDetail == nil ? categoryName : "商品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
                if selectedDetail != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDetail = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Detail Content View (详情内容视图)
struct DetailContentView: View {
    let accessoryId: UUID
    let detail: BundleAccessoryGroup.AccessoryDetail
    @EnvironmentObject var dataManager: DataManager

    private var accessory: Accessory? {
        dataManager.accessories.first(where: { $0.id == accessoryId })
    }

    private var displayImages: [UIImage] {
        if let accessory = accessory, !accessory.thumbnailPaths.isEmpty {
            return accessory.thumbnailPaths.compactMap { ImageStorage.shared.loadImage(filename: $0) }
        }
        if let imagePath = detail.displayImagePath,
           let image = ImageStorage.shared.loadImage(filename: imagePath) {
            return [image]
        }
        return []
    }

    private var categoryName: String? {
        guard let categoryId = accessory?.categoryId else { return nil }
        return dataManager.accessoryCategories.first(where: { $0.id == categoryId })?.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. 分类标签、名称、价格
                VStack(alignment: .leading, spacing: 12) {
                    if let category = categoryName {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(detail.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("¥\(detail.displayPrice)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // 2. 缩略图轮播
                if displayImages.isEmpty {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        }
                } else {
                    ImageCarouselView(images: displayImages, cornerRadius: 16)
                }

                // 3. 商品简介
                if let description = accessory?.description, !description.isEmpty {
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

                // 4. 商品详情图片
                if let detailImages = accessory?.detailImages, !detailImages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("商品详情")
                            .font(.headline)

                        VStack(spacing: 0) {
                            ForEach(detailImages.indices, id: \.self) { index in
                                if let image = ImageStorage.shared.loadImage(filename: detailImages[index]) {
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
            }
            .padding(16)
        }
    }
}

// MARK: - Style Card (款式卡片)
struct StyleCard: View {
    let detail: BundleAccessoryGroup.AccessoryDetail
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // 缩略图
                Group {
                    if let imagePath = detail.displayImagePath,
                       let image = ImageStorage.shared.loadImage(filename: imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(Color(.systemGray6))

                // 名称
                Text(detail.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)

                // 价格
                Text("¥\(detail.displayPrice)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect Blur View
struct VisualEffectBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Accessory Detail Popup New
struct AccessoryDetailPopupNew: View {
    let accessoryId: UUID
    let detail: BundleAccessoryGroup.AccessoryDetail
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    private var accessory: Accessory? {
        dataManager.accessories.first(where: { $0.id == accessoryId })
    }

    private var displayImages: [UIImage] {
        if let accessory = accessory, !accessory.thumbnailPaths.isEmpty {
            return accessory.thumbnailPaths.compactMap { ImageStorage.shared.loadImage(filename: $0) }
        }
        if let imagePath = detail.displayImagePath,
           let image = ImageStorage.shared.loadImage(filename: imagePath) {
            return [image]
        }
        return []
    }

    private var categoryName: String? {
        guard let categoryId = accessory?.categoryId else { return nil }
        return dataManager.accessoryCategories.first(where: { $0.id == categoryId })?.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 分类标签、名称、价格
                    VStack(alignment: .leading, spacing: 12) {
                        // 分类标签
                        if let category = categoryName {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        // 商品名称
                        Text(detail.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        // 价格
                        Text("¥\(detail.displayPrice)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.red)

                        if detail.quantity > 1 {
                            Text("数量: \(detail.quantity)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 2. 缩略图轮播
                    if displayImages.isEmpty {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                            }
                    } else {
                        ImageCarouselView(images: displayImages, cornerRadius: 16)
                    }

                    // 3. 商品简介
                    if let description = accessory?.description, !description.isEmpty {
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

                    // 4. 商品详情图片
                    if let detailImages = accessory?.detailImages, !detailImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("商品详情")
                                .font(.headline)

                            VStack(spacing: 0) {
                                ForEach(detailImages.indices, id: \.self) { index in
                                    if let image = ImageStorage.shared.loadImage(filename: detailImages[index]) {
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
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("商品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BundleDetailView(bundleId: UUID())
            .environmentObject(DataManager.shared)
    }
}
