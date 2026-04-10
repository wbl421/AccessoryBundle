import SwiftUI

// MARK: - Card Frame Preference Key
struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
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
                                headerView
                                categoryGrid(geometry: geometry)
                            }
                            .padding(20)
                        }
                        .background(Color(.systemGroupedBackground))
                        
                        accessoryButton
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(.systemGroupedBackground))
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

struct CategoryCard: View {
    let category: Category
    var isIPad: Bool = false
    var cardWidth: CGFloat = 0
    var isDragging: Bool = false
    var isEditMode: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: isIPad ? 48 : 40))
                .foregroundStyle(.white)

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
                Image(systemName: category.icon)
                    .font(.system(size: isIPad ? 48 : 40))
                    .foregroundStyle(.white)
                
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

    private var isEditing: Bool { category != nil }

    private let icons = ["iphone", "ipad", "laptopcomputer", "applewatch", "desktopcomputer", "headphones", "airpods", "airpodpro", "airpodsmax", "keyboard", "mouse", "tv", "hifispeaker", "printer", "gamecontroller"]

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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("颜色") {
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
                }

                // 预览
                Section("预览") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
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
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedIcon = category.icon
                    selectedColorHex = category.colorHex
                }
            }
        }
    }

    private func saveCategory() {
        if let existingCategory = category {
            var updated = existingCategory
            updated.name = name
            updated.icon = selectedIcon
            updated.colorHex = selectedColorHex
            dataManager.updateCategory(updated)
        } else {
            let maxOrder = dataManager.categories.map(\.order).max() ?? -1
            let newCategory = Category(name: name, icon: selectedIcon, colorHex: selectedColorHex, order: maxOrder + 1)
            dataManager.addCategory(newCategory)
        }
        dismiss()
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

#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
}
