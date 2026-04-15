import SwiftUI

struct CategoryView: View {
    let category: Category
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddBundle = false
    @State private var showDeleteAlert = false
    @State private var bundleToDelete: Bundle?
    @State private var isEditMode = false

    // 对比模式
    @State private var isComparisonMode = false
    @State private var selectedBundleIds: Set<UUID> = []
    @State private var showingComparison = false

    var body: some View {
        BundleListView(
            category: category,
            isEditMode: isEditMode,
            isComparisonMode: isComparisonMode,
            selectedBundleIds: selectedBundleIds,
            onDeleteBundle: { bundle in
                bundleToDelete = bundle
                showDeleteAlert = true
            },
            onToggleSelection: { bundleId in
                if selectedBundleIds.contains(bundleId) {
                    selectedBundleIds.remove(bundleId)
                } else if selectedBundleIds.count < 3 {
                    selectedBundleIds.insert(bundleId)
                }
            }
        )
        .fullScreenCover(isPresented: $showingAddBundle) {
            BundleEditView(categoryId: category.id, bundle: nil)
        }
        .sheet(isPresented: $showingComparison) {
            if selectedBundleIds.count >= 2 {
                BundleComparisonView(bundleIds: Array(selectedBundleIds))
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                bundleToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let bundle = bundleToDelete {
                    dataManager.deleteBundle(bundle.id)
                }
                bundleToDelete = nil
            }
        } message: {
            Text("确定要删除「\(bundleToDelete?.name ?? "")」吗？")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if isComparisonMode {
                        Button {
                            isComparisonMode = false
                            selectedBundleIds.removeAll()
                        } label: {
                            Text("取消")
                                .fontWeight(.medium)
                        }
                        if selectedBundleIds.count >= 2 {
                            Button {
                                showingComparison = true
                            } label: {
                                Text("对比")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Button { isEditMode.toggle() } label: {
                            Text(isEditMode ? "完成" : "编辑")
                                .fontWeight(.medium)
                        }
                        Button { showingAddBundle = true } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            isComparisonMode = true
                        } label: {
                            Image(systemName: "rectangle.on.rectangle")
                        }
                    }
                }
            }
        }
        .onChange(of: isComparisonMode) { newValue in
            if !newValue {
                selectedBundleIds.removeAll()
            }
        }
    }
}

// MARK: - Bundle List View
struct BundleListView: View {
    let category: Category
    var isEditMode: Bool = false
    var isComparisonMode: Bool = false
    var selectedBundleIds: Set<UUID> = []
    let onDeleteBundle: (Bundle) -> Void
    let onToggleSelection: (UUID) -> Void

    @EnvironmentObject var dataManager: DataManager
    @State private var dragItem: Bundle?
    @State private var dragOffset: CGFloat = 0
    @State private var dragTargetIndex: Int?
    @State private var localBundles: [Bundle] = []
    @State private var longPressItem: Bundle?

    // 震动反馈生成器（提前创建）
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)

    private var bundles: [Bundle] {
        dataManager.bundles(for: category.id)
    }

    var body: some View {
        ScrollView {
            if localBundles.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    Image(systemName: "bag")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("暂无套餐")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("点击右上角 + 添加套餐")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(localBundles.enumerated()), id: \.element.id) { offset, element in
                        DraggableBundleRow(
                            bundle: element,
                            index: offset,
                            dragItem: dragItem,
                            dragOffset: dragOffset,
                            dragTargetIndex: dragTargetIndex,
                            longPressItem: longPressItem,
                            localBundles: localBundles,
                            isEditMode: isEditMode,
                            isComparisonMode: isComparisonMode,
                            isSelected: selectedBundleIds.contains(element.id),
                            onDragStart: { startDrag($0, $1, $2) },
                            onDragUpdate: { updateDrag($0, $1) },
                            onDragEnd: { endDrag($0, $1, $2) },
                            onLongPress: { longPressItem = $0 },
                            onDelete: { onDeleteBundle($0) },
                            onToggleSelection: { onToggleSelection($0) }
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(category.name)套餐")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            localBundles = bundles
            // 预准备震动反馈器
            lightFeedback.prepare()
            mediumFeedback.prepare()
        }
        .onChange(of: bundles) { newValue in
            localBundles = newValue
        }
        .navigationDestination(for: UUID.self) { bundleId in
            BundleDetailView(bundleId: bundleId)
        }
    }
    
    private func startDrag(_ bundle: Bundle, _ index: Int, _ bundles: [Bundle]) {
        // 震动反馈
        mediumFeedback.impactOccurred()
        lightFeedback.prepare()
        
        dragItem = bundle
        dragTargetIndex = index
        localBundles = bundles
        longPressItem = nil
    }
    
    private func updateDrag(_ offset: CGFloat, _ targetIndex: Int?) {
        dragOffset = offset
        if let targetIndex = targetIndex {
            // 目标位置改变时触发轻微震动
            if dragTargetIndex != targetIndex {
                lightFeedback.impactOccurred()
                lightFeedback.prepare()
            }
            dragTargetIndex = targetIndex
        }
    }
    
    private func endDrag(_ bundle: Bundle, _ currentIndex: Int, _ newIndex: Int) {
        if currentIndex != newIndex {
            // 位置改变时的震动反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let movedItem = localBundles.remove(at: currentIndex)
                localBundles.insert(movedItem, at: newIndex)
            }
            dataManager.updateBundleOrders(categoryId: category.id, orderedBundles: localBundles)
        }
        longPressItem = nil
        dragItem = nil
        dragOffset = 0
        dragTargetIndex = nil
    }
}

// MARK: - Draggable Bundle Row
struct DraggableBundleRow: View {
    let bundle: Bundle
    let index: Int
    let dragItem: Bundle?
    let dragOffset: CGFloat
    let dragTargetIndex: Int?
    let longPressItem: Bundle?
    let localBundles: [Bundle]
    var isEditMode: Bool = false
    var isComparisonMode: Bool = false
    var isSelected: Bool = false
    let onDragStart: (Bundle, Int, [Bundle]) -> Void
    let onDragUpdate: (CGFloat, Int?) -> Void
    let onDragEnd: (Bundle, Int, Int) -> Void
    let onLongPress: (Bundle) -> Void
    let onDelete: (Bundle) -> Void
    let onToggleSelection: (UUID) -> Void

    @State private var pressStartTime: Date?
    @State private var hasTriggeredLongPress = false

    private var isDraggingThis: Bool { dragItem?.id == bundle.id }
    private var isLongPressed: Bool { longPressItem?.id == bundle.id && dragItem == nil }

    // 动态 zIndex：被拖拽或长按的元素显示在最上层
    private var dynamicZIndex: Double {
        if isDraggingThis || isLongPressed {
            return Double(localBundles.count) + 1
        }
        return Double(index)
    }

    private var rowOffset: CGFloat {
        guard let dragItem = dragItem,
              let dragIndex = localBundles.firstIndex(where: { $0.id == dragItem.id }),
              let targetIndex = dragTargetIndex else { return 0 }
        let rowHeight: CGFloat = 120
        if dragIndex < targetIndex {
            if index > dragIndex && index <= targetIndex { return -rowHeight }
        } else if dragIndex > targetIndex {
            if index >= targetIndex && index < dragIndex { return rowHeight }
        }
        return 0
    }

    var body: some View {
        Group {
            if isEditMode {
                // 编辑模式：使用 UIKit 手势实现长按+拖拽+滚动并存
                BundleCard(bundle: bundle, isDragging: isDraggingThis || isLongPressed, isEditMode: isEditMode, onDelete: { onDelete(bundle) })
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
                                    onLongPress(bundle)
                                }
                            },
                            onDragChanged: { translation in
                                if hasTriggeredLongPress || dragItem?.id == bundle.id {
                                    if dragItem == nil {
                                        onDragStart(bundle, index, localBundles)
                                    }
                                    if isDraggingThis {
                                        let newIndex = calculateNewIndex(translation: translation)
                                        onDragUpdate(translation, newIndex != dragTargetIndex ? newIndex : nil)
                                    }
                                }
                            },
                            onDragEnded: { translation in
                                if isDraggingThis {
                                    let currentIndex = localBundles.firstIndex(where: { $0.id == bundle.id }) ?? 0
                                    let newIndex = calculateNewIndex(translation: translation)
                                    onDragEnd(bundle, currentIndex, newIndex)
                                }
                                hasTriggeredLongPress = false
                            }
                        )
                    )
                    // 删除按钮放在最顶层，确保可点击
                    .overlay(alignment: .leading) {
                        Button(action: { onDelete(bundle) }) {
                            Color.clear
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .padding(.leading, 12)
                    }
            } else if isComparisonMode {
                // 对比模式：显示勾选框
                Button {
                    onToggleSelection(bundle.id)
                } label: {
                    BundleCard(bundle: bundle, isDragging: false, isEditMode: false, isComparisonMode: true, isSelected: isSelected, onDelete: {})
                }
                .buttonStyle(.plain)
            } else {
                // 非编辑模式：NavigationLink 导航到详情
                NavigationLink(value: bundle.id) {
                    BundleCard(bundle: bundle, isDragging: false, isEditMode: false, onDelete: {})
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func calculateNewIndex(translation: CGFloat) -> Int {
        let rowHeight: CGFloat = 120
        let currentIndex = localBundles.firstIndex(where: { $0.id == bundle.id }) ?? 0
        let moveOffset = Int(round(translation / rowHeight))
        return max(0, min(localBundles.count - 1, currentIndex + moveOffset))
    }
}

// MARK: - Bundle Card
struct BundleCard: View {
    let bundle: Bundle
    var isDragging: Bool = false
    var isEditMode: Bool = false
    var isComparisonMode: Bool = false
    var isSelected: Bool = false
    let onDelete: () -> Void
    @EnvironmentObject var dataManager: DataManager

    private var sortedAccessoryItems: [BundleAccessoryItem] {
        dataManager.bundleAccessoryItems
            .filter { $0.bundleId == bundle.id }
            .sorted { $0.order < $1.order }
    }

    private var orderedCategories: [AccessoryCategory] {
        var seenIds = Set<UUID>()
        var result: [AccessoryCategory] = []
        for item in sortedAccessoryItems {
            guard let accessory = dataManager.accessories.first(where: { $0.id == item.accessoryId }),
                  let categoryId = accessory.categoryId,
                  !seenIds.contains(categoryId) else { continue }
            seenIds.insert(categoryId)
            if let category = dataManager.accessoryCategories.first(where: { $0.id == categoryId }) {
                result.append(category)
            }
        }
        return result
    }

    private var accessoryCount: Int { sortedAccessoryItems.count }

    var body: some View {
        HStack(spacing: 12) {
            // 编辑模式左侧显示删除图标
            if isEditMode {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
            }

            // 对比模式左侧显示勾选框
            if isComparisonMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "bag.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bundle.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text("¥\(bundle.price)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
                if !orderedCategories.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(orderedCategories) { category in
                            Text(category.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                if !isEditMode && !isComparisonMode {
                    HStack {
                        Spacer()
                        Text("点击查看详情")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.dimensions(in: .unspecified).width + spacing
            }
            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRowItems: [LayoutSubview] = []
        var currentX: CGFloat = 0
        let maxWidth = proposal.width ?? 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && !currentRowItems.isEmpty {
                rows.append(Row(items: currentRowItems, height: currentRowItems.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0))
                currentRowItems = []
                currentX = 0
            }
            currentRowItems.append(subview)
            currentX += size.width + spacing
        }

        if !currentRowItems.isEmpty {
            rows.append(Row(items: currentRowItems, height: currentRowItems.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0))
        }
        return rows
    }

    struct Row {
        var items: [LayoutSubview]
        var height: CGFloat
    }
}

#Preview {
    NavigationStack {
        CategoryView(category: Category.defaults[0])
            .environmentObject(DataManager.shared)
    }
}


// MARK: - Gesture Handling View (UIKit)

/// 使用 UIKit 手势识别器实现长按+拖拽+滚动并存
/// 关键：长按触发前允许 ScrollView 滚动，长按触发后开始拖拽
struct GestureHandlingView: UIViewRepresentable {
    let onLongPress: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = GestureCoordinatorView()
        view.backgroundColor = .clear
        
        // 长按手势 - 0.3秒触发
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
        var onDragChanged: (CGFloat) -> Void
        var onDragEnded: (CGFloat) -> Void
        
        var longPressRecognizer: UILongPressGestureRecognizer?
        private var hasTriggeredLongPress = false
        private var startTouchPoint: CGPoint = .zero
        
        init(onLongPress: @escaping () -> Void,
             onDragChanged: @escaping (CGFloat) -> Void,
             onDragEnded: @escaping (CGFloat) -> Void) {
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
                    let translation = currentPoint.y - startTouchPoint.y
                    onDragChanged(translation)
                }
                
            case .ended, .cancelled:
                if hasTriggeredLongPress {
                    let currentPoint = recognizer.location(in: recognizer.view?.superview)
                    let translation = currentPoint.y - startTouchPoint.y
                    onDragEnded(translation)
                }
                hasTriggeredLongPress = false
                
            default:
                break
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 长按触发前允许 ScrollView 滚动，触发后阻止
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

class GestureCoordinatorView: UIView {
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
