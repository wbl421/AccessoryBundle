import SwiftUI
import Photos

// MARK: - 海报入口：配件款式选择
struct PosterStyleSelectView: View {
    let bundleId: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    // 每个分组选中的款式 index
    @State private var selectedIndices: [UUID: Int] = [:]

    // 选中的海报模板
    @State private var selectedTemplate: PosterTemplate = .classic

    private var bundleData: (bundle: Bundle, groups: [BundleAccessoryGroup])? {
        dataManager.bundleWithAccessoryGroups(for: bundleId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let data = bundleData {
                        if data.groups.isEmpty {
                            // 空状态
                            VStack(spacing: 16) {
                                Image(systemName: "bag")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("套餐暂无配件")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("请先添加配件后再生成海报")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            // 模板选择
                            templateSelectionSection

                            ForEach(data.groups) { group in
                                groupSelectionCard(group: group)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("选择海报款式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("生成海报") {
                        generateAndShare()
                    }
                    .fontWeight(.semibold)
                    .disabled(bundleData?.groups.isEmpty ?? true)
                }
            }
            .sheet(isPresented: $showPosterPreview) {
                if let image = posterImage {
                    PosterShareView(image: image)
                } else {
                    // 加载中
                    ZStack {
                        Color(.systemGroupedBackground)
                        ProgressView("生成中...")
                    }
                }
            }
        }
        .onAppear {
            // 默认选中每个分组的第一个款式
            if let data = bundleData {
                for group in data.groups {
                    if selectedIndices[group.id] == nil {
                        selectedIndices[group.id] = 0
                    }
                }
            }
        }
    }

    // MARK: - 模板选择区域
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("海报模板")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                ForEach(PosterTemplate.allCases) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        VStack(spacing: 8) {
                            // 模板预览缩略图
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTemplate == template ? Color.red.opacity(0.1) : Color(.systemGray6))
                                .frame(width: 80, height: 60)
                                .overlay(
                                    VStack(spacing: 4) {
                                        if template == .classic {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.red.opacity(0.8))
                                                .frame(height: 16)
                                            HStack(spacing: 4) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.gray.opacity(0.3))
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.gray.opacity(0.3))
                                            }
                                        } else if template == .simple {
                                            VStack(spacing: 4) {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(height: 8)
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(height: 8)
                                            }
                                            .padding(4)
                                        } else if template == .card {
                                            VStack(spacing: 4) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.blue.opacity(0.6))
                                                    .frame(height: 20)
                                                HStack(spacing: 4) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color.gray.opacity(0.2))
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color.gray.opacity(0.2))
                                                }
                                            }
                                            .padding(4)
                                        } else {
                                            // 深色款预览
                                            VStack(spacing: 4) {
                                                Rectangle()
                                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                                                    .frame(height: 20)
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                                                        .frame(width: 8, height: 8)
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.4))
                                                        .frame(height: 6)
                                                }
                                            }
                                            .padding(4)
                                        }
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedTemplate == template ? Color.red : Color.clear, lineWidth: 2)
                                )

                            Text(template.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTemplate == template ? .semibold : .regular)
                                .foregroundStyle(selectedTemplate == template ? .red : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 分组选择卡片
    @ViewBuilder
    private func groupSelectionCard(group: BundleAccessoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let categoryName = dataManager.accessoryCategories
                .first(where: { $0.id == group.accessory.categoryId })?.name ?? "配件"

            Text(categoryName)
                .font(.headline)
                .foregroundStyle(.primary)

            if group.items.count == 1 {
                // 只有一个款式，直接展示
                let detail = group.items[0]
                HStack(spacing: 12) {
                    posterThumbnail(path: detail.displayImagePath)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("¥\(detail.displayPrice)")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Text("已选")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // 多个款式，让用户选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(group.items.enumerated()), id: \.offset) { index, detail in
                            let isSelected = selectedIndices[group.id] == index
                            Button {
                                selectedIndices[group.id] = index
                            } label: {
                                VStack(spacing: 8) {
                                    posterThumbnail(path: detail.displayImagePath)
                                        .frame(width: 80, height: 80)
                                    Text(detail.displayName)
                                        .font(.caption)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundStyle(isSelected ? .blue : .primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(height: 32)
                                    Text("¥\(detail.displayPrice)")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                .frame(width: 100)
                                .padding(8)
                                .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 缩略图
    @ViewBuilder
    private func posterThumbnail(path: String?) -> some View {
        Group {
            if let path = path, let image = ImageStorage.shared.loadImage(filename: path) {
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
        .background(Color(.systemGray6))
    }

    // MARK: - 生成海报
    @State private var posterImage: UIImage?
    @State private var showPosterPreview = false

    private func generateAndShare() {
        guard let data = bundleData else { return }

        // 构建选中的款式列表
        var selectedDetails: [PosterAccessoryItem] = []
        for group in data.groups {
            let selectedIndex = selectedIndices[group.id] ?? 0
            if selectedIndex < group.items.count {
                let detail = group.items[selectedIndex]
                let categoryName = dataManager.accessoryCategories
                    .first(where: { $0.id == group.accessory.categoryId })?.name ?? "配件"
                selectedDetails.append(PosterAccessoryItem(
                    categoryName: categoryName,
                    displayName: detail.displayName,
                    price: detail.displayPrice,
                    imagePath: detail.displayImagePath
                ))
            }
        }

        let originalPrice = selectedDetails.reduce(0) { $0 + $1.price }

        // 先清空旧图片，显示加载状态
        posterImage = nil
        showPosterPreview = true

        // 延迟渲染，确保 sheet 已打开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let posterView = createPosterView(
                template: selectedTemplate,
                bundleName: data.bundle.name,
                originalPrice: originalPrice,
                bundlePrice: data.bundle.price,
                accessories: selectedDetails
            )

            let renderer = ImageRenderer(content: posterView)
            renderer.scale = 3.0
            if let image = renderer.uiImage {
                self.posterImage = image
            }
        }
    }
}

// MARK: - 海报数据模型
struct PosterAccessoryItem {
    let categoryName: String
    let displayName: String
    let price: Int
    let imagePath: String?
}

// MARK: - 海报视图（用于渲染成图片）
struct BundlePosterView: View {
    let bundleName: String
    let originalPrice: Int
    let bundlePrice: Int
    let accessories: [PosterAccessoryItem]

    private var savings: Int { originalPrice - bundlePrice }
    private var discount: Double { originalPrice > 0 ? Double(bundlePrice) / Double(originalPrice) : 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部品牌区
            headerSection

            // 价格对比区
            priceSection

            // 配件列表
            accessoryListSection
        }
        .frame(width: 375)
        .background(Color.white)
    }

    // MARK: - 顶部品牌区
    private var headerSection: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [Color.red.opacity(0.9), Color(red: 1.0, green: 0.3, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                Text(bundleName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 100)
    }

    // MARK: - 价格对比区
    private var priceSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("套餐价")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.red)
                Text("¥\(bundlePrice)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.red)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("原价 ¥\(originalPrice)")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .strikethrough()
                    if savings > 0 {
                        Text("立省 ¥\(savings)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.3))
                    }
                }
            }

            if savings > 0 {
                HStack(spacing: 6) {
                    Text("约\(String(format: "%.1f", discount * 10))折")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("超值优惠")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
    }

    // MARK: - 配件列表
    private var accessoryListSection: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("配件清单")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("共\(accessories.count)件")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 两列网格布局
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                    accessoryCard(item: item, index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
    }

    // MARK: - 配件卡片
    @ViewBuilder
    private func accessoryCard(item: PosterAccessoryItem, index: Int) -> some View {
        VStack(spacing: 0) {
            // 图片区
            ZStack(alignment: .topLeading) {
                Group {
                    if let path = item.imagePath, let image = ImageStorage.shared.loadImage(filename: path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(red: 0.94, green: 0.94, blue: 0.94)
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                }
                .frame(height: 120)
                .clipped()

                // 序号角标
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.red)
                    .clipShape(Circle())
                    .padding(6)
            }

            // 文字区
            VStack(alignment: .leading, spacing: 4) {
                Text(item.categoryName)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("¥\(item.price)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 海报预览与分享
struct PosterShareView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var saveResult: SaveResult?

    private enum SaveResult: Equatable {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("套餐海报", image: Image(uiImage: image))
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享海报")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        saveToAlbum()
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("保存到相册")
                        }
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("海报预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("保存成功", isPresented: Binding(
                get: { saveResult == .success },
                set: { if !$0 { saveResult = nil } }
            )) {
                Button("好的") { saveResult = nil }
            } message: {
                Text("海报已保存到相册")
            }
            .alert("保存失败", isPresented: Binding(
                get: { if case .failure = saveResult { return true } else { return false } },
                set: { if !$0 { saveResult = nil } }
            )) {
                Button("好的") { saveResult = nil }
            } message: {
                Text(saveResultMessage)
            }
        }
    }

    private var saveResultMessage: String {
        if case .failure(let msg) = saveResult {
            return msg
        }
        return ""
    }

    private func saveToAlbum() {
        // 直接调用，系统会自动处理权限请求弹窗
        // 第一次使用时系统会弹出"允许访问相册"的权限弹窗
        // 不需要手动调 PHPhotoLibrary.requestAuthorization（在 sheet 中会死锁）
        let saver = ImageSaver()
        saver.onSuccess = {
            DispatchQueue.main.async {
                self.saveResult = .success
            }
        }
        saver.onFailure = { error in
            DispatchQueue.main.async {
                if error.contains("权限") || error.contains("denied") || error.contains("access") {
                    self.saveResult = .failure("请在设置中允许访问相册")
                } else {
                    self.saveResult = .failure(error)
                }
            }
        }
        saver.save(image: image)
    }
}

// MARK: - ImageSaver（处理 UIImageWriteToSavedPhotosAlbum 回调）
class ImageSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onFailure: ((String) -> Void)?

    func save(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onFailure?(error.localizedDescription)
        } else {
            onSuccess?()
        }
    }
}

// MARK: - 海报模板类型
enum PosterTemplate: String, CaseIterable, Identifiable {
    case classic = "经典款"
    case simple = "简约款"
    case card = "卡片款"
    case dark = "黑金款"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .classic: return "红色渐变背景，两列网格展示"
        case .simple: return "白色简约，列表排列"
        case .card: return "卡片风格，大图展示"
        case .dark: return "深色背景，金色点缀"
        }
    }
}

// MARK: - 海报模板2：简约款
struct BundlePosterViewSimple: View {
    let bundleName: String
    let originalPrice: Int
    let bundlePrice: Int
    let accessories: [PosterAccessoryItem]

    private var savings: Int { originalPrice - bundlePrice }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 12) {
                Text(bundleName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("套餐价")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        Text("¥\(bundlePrice)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.red)
                    }

                    if savings > 0 {
                        VStack(spacing: 4) {
                            Text("立省")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                            Text("¥\(savings)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.3))
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color.white)

            // 分割线
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1)

            // 配件列表
            VStack(spacing: 0) {
                ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        // 序号
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.red)
                            .clipShape(Circle())

                        // 图片
                        Group {
                            if let path = item.imagePath, let image = ImageStorage.shared.loadImage(filename: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // 信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.categoryName)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                            Text(item.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.black)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Text("¥\(item.price)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    if index < accessories.count - 1 {
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 375)
        .background(Color.white)
    }
}

// MARK: - 海报模板3：卡片款
struct BundlePosterViewCard: View {
    let bundleName: String
    let originalPrice: Int
    let bundlePrice: Int
    let accessories: [PosterAccessoryItem]

    private var savings: Int { originalPrice - bundlePrice }
    private var discount: Double { originalPrice > 0 ? Double(bundlePrice) / Double(originalPrice) : 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部大卡片
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 16) {
                    Text(bundleName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("¥\(bundlePrice)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    if savings > 0 {
                        HStack(spacing: 8) {
                            Text("原价 ¥\(originalPrice)")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                                .strikethrough()
                            Text("省¥\(savings)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.0))
                        }
                    }
                }
                .padding(.vertical, 30)
            }

            // 配件大卡片列表
            VStack(spacing: 12) {
                ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 16) {
                        // 大图
                        Group {
                            if let path = item.imagePath, let image = ImageStorage.shared.loadImage(filename: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 信息
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color(red: 0.2, green: 0.6, blue: 1.0))
                                    .clipShape(Circle())

                                Text(item.categoryName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }

                            Text(item.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("¥\(item.price)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
            .padding(16)
        }
        .frame(width: 375)
        .background(Color(red: 0.96, green: 0.96, blue: 0.98))
    }
}

// MARK: - 海报模板4：深色款
struct BundlePosterViewDark: View {
    let bundleName: String
    let originalPrice: Int
    let bundlePrice: Int
    let accessories: [PosterAccessoryItem]

    private var savings: Int { originalPrice - bundlePrice }

    // 金色
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        VStack(spacing: 0) {
            // 顶部品牌区
            VStack(spacing: 16) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(goldColor)

                Text(bundleName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // 价格区
                VStack(spacing: 8) {
                    Text("套餐价")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(goldColor)
                        Text("\(bundlePrice)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(goldColor)
                    }

                    if savings > 0 {
                        HStack(spacing: 12) {
                            Text("原价 ¥\(originalPrice)")
                                .font(.system(size: 13))
                                .foregroundStyle(.gray)
                                .strikethrough()
                            Text("立省 ¥\(savings)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.4))
                        }
                    }
                }
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))

            // 分割线
            Rectangle()
                .fill(goldColor.opacity(0.3))
                .frame(height: 1)

            // 配件列表
            VStack(spacing: 0) {
                ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 14) {
                        // 序号
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.15))
                            .frame(width: 24, height: 24)
                            .background(goldColor)
                            .clipShape(Circle())

                        // 图片
                        Group {
                            if let path = item.imagePath, let image = ImageStorage.shared.loadImage(filename: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 65, height: 65)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // 信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.categoryName)
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                            Text(item.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Text("¥\(item.price)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(goldColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if index < accessories.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))

            // 底部
            Text("精选配件 品质保证")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.12, green: 0.12, blue: 0.15))
        }
        .frame(width: 375)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
}

// MARK: - 海报工厂方法
func createPosterView(
    template: PosterTemplate,
    bundleName: String,
    originalPrice: Int,
    bundlePrice: Int,
    accessories: [PosterAccessoryItem]
) -> AnyView {
    switch template {
    case .classic:
        return AnyView(BundlePosterView(
            bundleName: bundleName,
            originalPrice: originalPrice,
            bundlePrice: bundlePrice,
            accessories: accessories
        ))
    case .simple:
        return AnyView(BundlePosterViewSimple(
            bundleName: bundleName,
            originalPrice: originalPrice,
            bundlePrice: bundlePrice,
            accessories: accessories
        ))
    case .card:
        return AnyView(BundlePosterViewCard(
            bundleName: bundleName,
            originalPrice: originalPrice,
            bundlePrice: bundlePrice,
            accessories: accessories
        ))
    case .dark:
        return AnyView(BundlePosterViewDark(
            bundleName: bundleName,
            originalPrice: originalPrice,
            bundlePrice: bundlePrice,
            accessories: accessories
        ))
    }
}

#Preview {
    PosterStyleSelectView(bundleId: UUID())
        .environmentObject(DataManager.shared)
}
