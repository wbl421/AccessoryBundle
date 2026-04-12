import SwiftUI
import PhotosUI

// MARK: - Card Frame Preference Key
struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @StateObject private var appSettings = AppSettings.shared
    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var isEditMode = false
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?

    // 拖拽相关
    @State private var dragItem: Category?
    @State private var dragOffset: CGSize = .zero
    @State private var dragTargetIndex: Int?
    @State private var localCategories: [Category] = []
    @State private var cardFrames: [UUID: CGRect] = [:]  // 记录每个卡片的屏幕位置

    // 提示相关
    @State private var showWelcomeTip: Bool = false
    @State private var showAccessoryTip: Bool = false

    // Logo 编辑相关
    @State private var showLogoPicker = false
    @State private var selectedLogoImage: UIImage?
    @State private var showLogoEdit = false
    @State private var showDeleteLogoAlert = false
    
    // 判断是否是 iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 震动反馈生成器
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let geometryFrame = geometry.frame(in: .global)
                ZStack {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Logo 区域（有 Logo 时始终显示，编辑模式可操作）
                                if appSettings.logoImage != nil || isEditMode {
                                    logoSection
                                }

                                headerView

                                // 欢迎提示卡片
                                if showWelcomeTip {
                                    welcomeTipCard
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                categoryGrid(geometry: geometry)
                            }
                            .padding(20)
                        }
                        .background(Color(.systemGroupedBackground))

                        ZStack(alignment: .top) {
                            accessoryButton
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color(.systemGroupedBackground))

                            // 配件管理气泡提示
                            if showAccessoryTip {
                                VStack(spacing: 0) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(.orange)
                                        Text("点击这里管理所有配件商品")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                    // 小三角
                                    Triangle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 14, height: 8)
                                        .offset(y: -1)
                                }
                                .padding(.top, -50)
                                .transition(.opacity)
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showAccessoryTip = false
                                    }
                                    onboardingManager.completeTooltips()
                                }
                            }
                        }
                    }
                    
                    // 拖动中的卡片渲染在最上层（在ScrollView外）
                    // 只有当实际开始拖动（有偏移）时才显示 overlay
                    if let dragItem = dragItem, isEditMode, dragOffset != .zero, let frame = cardFrames[dragItem.id] {
                        // 使用 GeometryReader 来正确定位
                        GeometryReader { _ in
                            DragggingCardView(
                                category: dragItem,
                                isIPad: isIPad,
                                initialFrame: CGRect(
                                    x: frame.minX - geometryFrame.minX,
                                    y: frame.minY - geometryFrame.minY,
                                    width: frame.width,
                                    height: frame.height
                                ),
                                offset: dragOffset,
                                onDelete: {
                                    categoryToDelete = dragItem
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { isEditMode.toggle() } label: {
                            Text(isEditMode ? "完成" : "编辑")
                                .fontWeight(.medium)
                        }
                        Button { showingAddCategory = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryEditView(category: nil)
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditView(category: category)
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let category = categoryToDelete {
                        dataManager.deleteCategory(category.id)
                    }
                    categoryToDelete = nil
                }
            } message: {
                Text("确定要删除「\(categoryToDelete?.name ?? "")」吗？删除后该分类下的套餐也会被删除。")
            }
            .onAppear {
                localCategories = dataManager.categories.sorted { $0.order < $1.order }
                lightFeedback.prepare()
                mediumFeedback.prepare()
                // 首次启动显示提示
                if !onboardingManager.areTooltipsComplete {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showWelcomeTip = true
                    }
                }
            }
            .onChange(of: dataManager.categories) { _ in
                localCategories = dataManager.categories.sorted { $0.order < $1.order }
            }
            .navigationDestination(for: Category.self) { category in
                CategoryView(category: category)
            }
        }
    }

    private var headerView: some View {
        Text("会员优享套餐")
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(.top, 8)
    }

    // MARK: - Logo 区域（有 Logo 时始终显示）
    private var logoSection: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let actualWidth = min(appSettings.containerWidth, availableWidth)

            VStack(spacing: appSettings.bottomPadding) {
                if let logoImage = appSettings.logoImage {
                    // 已有图片
                    ZStack(alignment: .topLeading) {
                        if isEditMode {
                            // 编辑模式：可点击重新编辑
                            Button {
                                selectedLogoImage = logoImage
                                showLogoEdit = true
                            } label: {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: actualWidth * appSettings.imageScale, height: appSettings.containerHeight * appSettings.imageScale)
                                    .frame(width: actualWidth, height: appSettings.containerHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                            .buttonStyle(.plain)

                            // 删除按钮（仅编辑模式显示，放左边）
                            Button {
                                showDeleteLogoAlert = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                    .background(Circle().fill(.white))
                            }
                            .offset(x: -8, y: -8)
                        } else {
                            // 非编辑模式：只显示图片
                            Image(uiImage: logoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: actualWidth * appSettings.imageScale, height: appSettings.containerHeight * appSettings.imageScale)
                                .frame(width: actualWidth, height: appSettings.containerHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)  // 水平居中
                    .alert("删除图片", isPresented: $showDeleteLogoAlert) {
                        Button("取消", role: .cancel) {}
                        Button("删除", role: .destructive) {
                            appSettings.deleteLogo()
                        }
                    } message: {
                        Text("确定要删除已设置的图片吗？")
                    }
                } else if isEditMode {
                    // 没有 logo 且编辑模式 - 显示上传占位符
                    Button {
                        showLogoPicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("点击上传图片")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: actualWidth, height: appSettings.containerHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.tertiary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: appSettings.containerHeight + appSettings.bottomPadding + 20)
        .sheet(isPresented: $showLogoPicker) {
            ImagePicker(image: Binding(
                get: { selectedLogoImage ?? UIImage() },
                set: { newImage in
                    selectedLogoImage = newImage
                    if newImage.size.width > 0 {
                        // 选择图片后进入编辑界面
                        showLogoEdit = true
                    }
                }
            ))
        }
        .sheet(isPresented: $showLogoEdit) {
            if let image = selectedLogoImage {
                LogoEditView(settings: appSettings, image: image)
            }
        }
    }

    // 欢迎提示卡片
    private var welcomeTipCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("欢迎使用")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showWelcomeTip = false
                        showAccessoryTip = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "plus.circle.fill", color: .blue, text: "点击右上角 + 添加分类")
                tipRow(icon: "hand.draw", color: .purple, text: "编辑模式下长按拖拽排序")
                tipRow(icon: "bag.fill", color: .orange, text: "点击分类卡片查看套餐详情")
                tipRow(icon: "gearshape.fill", color: .green, text: "底部配件管理添加商品")
            }

            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    showWelcomeTip = false
                    showAccessoryTip = true
                }
            } label: {
                Text("我知道了")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            // 防止点击穿透
        }
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func categoryGrid(geometry: GeometryProxy) -> some View {
        let columns = isIPad ? 4 : 2
        let spacing: CGFloat = 16
        let cardWidth = (geometry.size.width - 40 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: 16) {
            ForEach(Array(localCategories.enumerated()), id: \.element.id) { index, category in
                if isEditMode {
                    // 编辑模式：拖拽排序
                    ZStack(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            CategoryCard(
                                category: category,
                                isIPad: isIPad,
                                cardWidth: cardWidth,
                                isDragging: false,
                                isEditMode: true
                            )
                            Button {
                                categoryToDelete = category
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                    .background(Circle().fill(.white).frame(width: 26, height: 26))
                            }
                            .buttonStyle(.plain)
                            .offset(x: -8, y: -8)
                        }
                        .opacity(dragItem?.id == category.id && dragOffset != .zero ? 0.01 : 1)
                        .scaleEffect(dragItem?.id == category.id ? 1.05 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragItem?.id)
                        .zIndex(dragItem?.id == category.id ? 100 : 0)
                        .offset(
                            x: dragItem != nil && dragItem?.id != category.id ? offsetForCategory(at: index, cardWidth: cardWidth, spacing: spacing).width : 0,
                            y: dragItem != nil && dragItem?.id != category.id ? offsetForCategory(at: index, cardWidth: cardWidth, spacing: spacing).height : 0
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragTargetIndex)
                        .overlay(
                            Group {
                                if isEditMode {
                                    GridGestureHandlingView(
                                        onLongPress: {
                                            if dragItem == nil {
                                                mediumFeedback.impactOccurred()
                                                dragItem = category
                                                dragTargetIndex = index
                                            }
                                        },
                                        onDragChanged: { translation in
                                            if dragItem?.id == category.id {
                                                dragOffset = translation
                                                let newIndex = calculateNewIndex(for: category, translation: translation, cardWidth: cardWidth, spacing: spacing)
                                                if newIndex != dragTargetIndex {
                                                    lightFeedback.impactOccurred()
                                                    dragTargetIndex = newIndex
                                                }
                                            }
                                        },
                                        onDragEnded: { _ in
                                            if dragItem?.id == category.id, let targetIndex = dragTargetIndex {
                                                let currentIndex = localCategories.firstIndex(where: { $0.id == category.id }) ?? 0
                                                
                                                if currentIndex != targetIndex {
                                                    let generator = UINotificationFeedbackGenerator()
                                                    generator.notificationOccurred(.success)
                                                    
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        let movedItem = localCategories.remove(at: currentIndex)
                                                        localCategories.insert(movedItem, at: targetIndex)
                                                    }
                                                    for (i, cat) in localCategories.enumerated() {
                                                        var updated = cat
                                                        updated.order = i
                                                        dataManager.updateCategory(updated)
                                                    }
                                                }
                                            }
                                            dragItem = nil
                                            dragOffset = .zero
                                            dragTargetIndex = nil
                                        }
                                    )
                                }
                            }
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        categoryToEdit = category
                    }
                    .background(
                        GeometryReader { cardGeometry in
                            Color.clear
                                .onAppear {
                                    cardFrames[category.id] = cardGeometry.frame(in: .global)
                                }
                                .onChange(of: cardGeometry.frame(in: .global)) { newFrame in
                                    cardFrames[category.id] = newFrame
                                }
                        }
                    )
                } else {
                    // 非编辑模式：NavigationLink 导航
                    NavigationLink(value: category) {
                        CategoryCard(
                            category: category,
                            isIPad: isIPad,
                            cardWidth: cardWidth,
                            isDragging: false,
                            isEditMode: false
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            categoryToEdit = category
                        } label: {
                            Label("编辑分类", systemImage: "pencil")
                        }
                    }
                    .background(
                        GeometryReader { cardGeometry in
                            Color.clear
                                .onAppear {
                                    cardFrames[category.id] = cardGeometry.frame(in: .global)
                                }
                                .onChange(of: cardGeometry.frame(in: .global)) { newFrame in
                                    cardFrames[category.id] = newFrame
                                }
                        }
                    )
                }
            }
        }
    }
    
    // 计算其他卡片的偏移量（让位动画）
    private func offsetForCategory(at index: Int, cardWidth: CGFloat, spacing: CGFloat) -> CGSize {
        guard let dragItem = dragItem,
              let dragIndex = localCategories.firstIndex(where: { $0.id == dragItem.id }),
              let targetIndex = dragTargetIndex else { return .zero }
        
        if dragIndex == targetIndex { return .zero }
        
        let columns = isIPad ? 4 : 2
        let cardHeight: CGFloat = isIPad ? 150 : 130
        
        // 向后拖动：dragIndex < targetIndex
        if dragIndex < targetIndex {
            if index > dragIndex && index <= targetIndex {
                // 这里的卡片需要往前移一位
                let srcRow = index / columns
                let srcCol = index % columns
                let dstIndex = index - 1
                let dstRow = dstIndex / columns
                let dstCol = dstIndex % columns
                let dx = CGFloat(dstCol - srcCol) * (cardWidth + spacing)
                let dy = CGFloat(dstRow - srcRow) * (cardHeight + spacing)
                return CGSize(width: dx, height: dy)
            }
        }
        // 向前拖动：dragIndex > targetIndex
        else if dragIndex > targetIndex {
            if index >= targetIndex && index < dragIndex {
                // 这里的卡片需要往后移一位
                let srcRow = index / columns
                let srcCol = index % columns
                let dstIndex = index + 1
                let dstRow = dstIndex / columns
                let dstCol = dstIndex % columns
                let dx = CGFloat(dstCol - srcCol) * (cardWidth + spacing)
                let dy = CGFloat(dstRow - srcRow) * (cardHeight + spacing)
                return CGSize(width: dx, height: dy)
            }
        }
        return .zero
    }
    
    // 根据拖拽偏移计算目标索引（支持斜向拖动）
    private func calculateNewIndex(for category: Category, translation: CGSize, cardWidth: CGFloat, spacing: CGFloat) -> Int {
        let currentIndex = localCategories.firstIndex(where: { $0.id == category.id }) ?? 0
        let columns = isIPad ? 4 : 2
        let cardHeight: CGFloat = isIPad ? 150 : 130
        
        let colOffset = Int(round(translation.width / (cardWidth + spacing)))
        let rowOffset = Int(round(translation.height / (cardHeight + spacing)))
        
        let currentRow = currentIndex / columns
        let currentCol = currentIndex % columns
        
        let newRow = currentRow + rowOffset
        let newCol = currentCol + colOffset
        
        // 确保在有效范围内
        guard newRow >= 0 && newCol >= 0 && newCol < columns else { return currentIndex }
        
        var newIndex = newRow * columns + newCol
        newIndex = max(0, min(localCategories.count - 1, newIndex))
        
        return newIndex
    }

    private var accessoryButton: some View {
        NavigationLink(destination: AccessoryListView()) {
            HStack {
                Image(systemName: "gearshape.fill")
                Text("配件管理")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Triangle Shape (三角形，用于气泡箭头)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct CategoryCard: View {
    let category: Category
    var isIPad: Bool = false
    var cardWidth: CGFloat = 0
    var isDragging: Bool = false
    var isEditMode: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            if let customPath = category.customIconPath,
               let image = ImageStorage.shared.loadImage(filename: customPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 40)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: isIPad ? 48 : 40))
                    .foregroundStyle(.white)
            }

            Text(category.name)
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(width: cardWidth > 0 ? cardWidth : nil, height: isIPad ? 150 : 130)
        .frame(maxWidth: cardWidth > 0 ? cardWidth : .infinity)
        .background(
            LinearGradient(colors: [category.color, category.color.opacity(0.7)],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: isDragging ? category.color.opacity(0.5) : category.color.opacity(0.3), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 6 : 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Dragging Card View (拖动中的卡片)
struct DragggingCardView: View {
    let category: Category
    let isIPad: Bool
    let initialFrame: CGRect
    let offset: CGSize
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 卡片
            VStack(spacing: 12) {
                if let customPath = category.customIconPath,
                   let image = ImageStorage.shared.loadImage(filename: customPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 40)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: isIPad ? 48 : 40))
                        .foregroundStyle(.white)
                }

                Text(category.name)
                    .font(isIPad ? .title3 : .headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: initialFrame.width, height: initialFrame.height)
            .background(
                LinearGradient(colors: [category.color, category.color.opacity(0.7)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            .scaleEffect(1.05)
            
            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .background(Circle().fill(.white).frame(width: 26, height: 26))
            }
            .buttonStyle(.plain)
            .offset(x: -8, y: -8)
        }
        // 使用 position 定位到全局坐标位置
        .position(x: initialFrame.midX + offset.width, y: initialFrame.midY + offset.height)
    }
}

// MARK: - Category Edit View
struct CategoryEditView: View {
    let category: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var selectedIcon = "iphone"
    @State private var selectedColorHex = "#007AFF"
    @State private var customIconImage: UIImage?
    @State private var customIconPath: String?
    @State private var showCustomColorPicker = false
    @State private var customColor: Color = .blue
    @State private var selectedIconItem: PhotosPickerItem?

    private var isEditing: Bool { category != nil }

    private let icons = ["iphone", "ipad", "laptopcomputer", "applewatch", "display", "headphones", "airpods", "airpodspro", "airpodsmax", "keyboard", "computermouse", "tv", "hifispeaker", "printer", "gamecontroller"]

    private let colors: [(name: String, hex: String)] = [
        ("蓝色", "#007AFF"),
        ("紫色", "#5856D6"),
        ("橙色", "#FF9500"),
        ("粉色", "#FF2D55"),
        ("绿色", "#34C759"),
        ("红色", "#FF3B30"),
        ("青色", "#5AC8FA"),
        ("黄色", "#FFCC00")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("分类名称") {
                    TextField("请输入名称", text: $name)
                }

                Section("图标") {
                    // 系统图标
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                customIconPath = nil
                                customIconImage = nil
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon && customIconPath == nil ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)

                    // 自定义图标上传
                    HStack {
                        if let customImage = customIconImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "plus")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            Text(customIconPath != nil ? "更换自定义图标" : "上传自定义图标")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        if customIconPath != nil {
                            Button {
                                customIconPath = nil
                                customIconImage = nil
                                selectedIcon = icons.first ?? "iphone"
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("颜色") {
                    // 预设颜色
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colors, id: \.hex) { color in
                            Button {
                                selectedColorHex = color.hex
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: color.hex) ?? .blue)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if selectedColorHex == color.hex {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(color.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)

                    // 自定义颜色选择
                    HStack {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            }
                            .overlay {
                                if selectedColorHex == customColorToHex() && !colors.contains(where: { $0.hex == selectedColorHex }) {
                                    Image(systemName: "checkmark")
                                        .font(.body)
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 1)
                                }
                            }
                        Button {
                            showCustomColorPicker = true
                        } label: {
                            Text("自定义颜色")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // 预览
                Section("预览") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let customImage = customIconImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .scaledToFit()
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(width: 120, height: 100)
                        .background(
                            LinearGradient(colors: [Color(hex: selectedColorHex) ?? .blue, (Color(hex: selectedColorHex) ?? .blue).opacity(0.7)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            dataManager.deleteCategory(category!.id)
                            dismiss()
                        } label: {
                            HStack { Spacer(); Text("删除此分类"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑分类" : "添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showCustomColorPicker) {
                CustomColorPickerView(selectedColorHex: $selectedColorHex, initialColor: Color(hex: selectedColorHex) ?? .blue)
            }
            .onChange(of: selectedIconItem) { newItem in
                guard let newItem else { return }
                newItem.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data):
                        if let data, let image = UIImage(data: data) {
                            let iconId = UUID()
                            if let path = ImageStorage.shared.saveImage(image, for: iconId) {
                                DispatchQueue.main.async {
                                    customIconPath = path
                                    customIconImage = image
                                }
                            }
                        }
                    case .failure:
                        break
                    }
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedIcon = category.icon
                    selectedColorHex = category.colorHex
                    customIconPath = category.customIconPath
                    if let path = category.customIconPath {
                        customIconImage = ImageStorage.shared.loadImage(filename: path)
                    }
                }
            }
        }
    }

    private func customColorToHex() -> String {
        let uiColor = UIColor(customColor)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return hex
    }

    private func saveCategory() {
        if let existingCategory = category {
            var updated = existingCategory
            updated.name = name
            updated.icon = selectedIcon
            updated.colorHex = selectedColorHex
            updated.customIconPath = customIconPath
            dataManager.updateCategory(updated)
        } else {
            let maxOrder = dataManager.categories.map(\.order).max() ?? -1
            let newCategory = Category(name: name, icon: selectedIcon, colorHex: selectedColorHex, customIconPath: customIconPath, order: maxOrder + 1)
            dataManager.addCategory(newCategory)
        }
        dismiss()
    }
}

// MARK: - Custom Color Picker View (自定义颜色选择器，类似PS色板)
struct CustomColorPickerView: View {
    @Binding var selectedColorHex: String
    @State private var currentColor: Color
    @Environment(\.dismiss) private var dismiss

    init(selectedColorHex: Binding<String>, initialColor: Color) {
        self._selectedColorHex = selectedColorHex
        self._currentColor = State(initialValue: initialColor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ColorPicker("选择颜色", selection: $currentColor, supportsOpacity: false)
                    .font(.headline)
                    .padding(.horizontal)

                // 预览
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(currentColor)
                        .frame(height: 100)
                        .overlay {
                            Text(colorToHex(currentColor))
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(isLightColor(currentColor) ? .black : .white)
                        }

                    // 色相光谱条
                    HueSpectrumBar(currentColor: $currentColor)

                    // 亮度变化条
                    BrightnessBar(currentColor: $currentColor)

                    // 饱和度变化条
                    SaturationBar(currentColor: $currentColor)
                    .padding(.horizontal)
                }
                .padding(.vertical)

                Spacer()
            }
            .padding()
            .navigationTitle("自定义颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        selectedColorHex = colorToHex(currentColor)
                        dismiss()
                    }
                }
            }
        }
    }

    private func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func isLightColor(_ color: Color) -> Bool {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else {
            return nil
        }
    }
}

// MARK: - Grid Gesture Handling View (UIKit) - 支持斜向拖动
struct GridGestureHandlingView: UIViewRepresentable {
    let onLongPress: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = GridGestureCoordinatorView()
        view.backgroundColor = .clear
        
        let longPressRecognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressRecognizer.minimumPressDuration = 0.3
        longPressRecognizer.allowableMovement = 100
        longPressRecognizer.delaysTouchesBegan = false
        longPressRecognizer.cancelsTouchesInView = true
        view.addGestureRecognizer(longPressRecognizer)
        context.coordinator.longPressRecognizer = longPressRecognizer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLongPress: onLongPress,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onLongPress: () -> Void
        var onDragChanged: (CGSize) -> Void
        var onDragEnded: (CGSize) -> Void
        
        var longPressRecognizer: UILongPressGestureRecognizer?
        private var hasTriggeredLongPress = false
        private var startTouchPoint: CGPoint = .zero
        
        init(onLongPress: @escaping () -> Void,
             onDragChanged: @escaping (CGSize) -> Void,
             onDragEnded: @escaping (CGSize) -> Void) {
            self.onLongPress = onLongPress
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
            super.init()
        }
        
        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                hasTriggeredLongPress = true
                startTouchPoint = recognizer.location(in: recognizer.view?.superview)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onLongPress()
                
            case .changed:
                if hasTriggeredLongPress {
                    let currentPoint = recognizer.location(in: recognizer.view?.superview)
                    let translation = CGSize(
                        width: currentPoint.x - startTouchPoint.x,
                        height: currentPoint.y - startTouchPoint.y
                    )
                    onDragChanged(translation)
                }
                
            case .ended, .cancelled:
                if hasTriggeredLongPress {
                    let currentPoint = recognizer.location(in: recognizer.view?.superview)
                    let translation = CGSize(
                        width: currentPoint.x - startTouchPoint.x,
                        height: currentPoint.y - startTouchPoint.y
                    )
                    onDragEnded(translation)
                }
                hasTriggeredLongPress = false
                
            default:
                break
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return !hasTriggeredLongPress
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return hasTriggeredLongPress
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldReceive touch: UITouch) -> Bool {
            return true
        }
    }
}

class GridGestureCoordinatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return bounds.contains(point) ? self : nil
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.contains(point)
    }
}

// MARK: - Hue Spectrum Bar
struct HueSpectrumBar: View {
    @Binding var currentColor: Color
    private let hues: [Double] = {
        var arr: [Double] = []
        for i in 0..<12 { arr.append(Double(i) / 12.0) }
        return arr
    }()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(hues, id: \.self) { hue in
                Circle()
                    .fill(Color(hue: hue, saturation: 1, brightness: 1))
                    .frame(width: 28, height: 28)
                    .onTapGesture {
                        currentColor = Color(hue: hue, saturation: 1, brightness: 1)
                    }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Brightness Bar
struct BrightnessBar: View {
    @Binding var currentColor: Color
    private let steps: [Double] = {
        var arr: [Double] = []
        for i in 0..<8 { arr.append(Double(i) / 7.0) }
        return arr
    }()

    private func hsbOfCurrent() -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let uiColor = UIColor(currentColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    var body: some View {
        let hsb = hsbOfCurrent()
        HStack(spacing: 2) {
            ForEach(steps, id: \.self) { brightness in
                Circle()
                    .fill(Color(hue: hsb.h, saturation: hsb.s, brightness: brightness))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    .onTapGesture {
                        currentColor = Color(hue: hsb.h, saturation: hsb.s, brightness: brightness)
                    }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Saturation Bar
struct SaturationBar: View {
    @Binding var currentColor: Color
    private let steps: [Double] = {
        var arr: [Double] = []
        for i in 0..<8 { arr.append(Double(i) / 7.0) }
        return arr
    }()

    private func hsbOfCurrent() -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let uiColor = UIColor(currentColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    var body: some View {
        let hsb = hsbOfCurrent()
        HStack(spacing: 2) {
            ForEach(steps, id: \.self) { saturation in
                Circle()
                    .fill(Color(hue: hsb.h, saturation: saturation, brightness: hsb.b))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    .onTapGesture {
                        currentColor = Color(hue: hsb.h, saturation: saturation, brightness: hsb.b)
                    }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 图片选择器
#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
}
