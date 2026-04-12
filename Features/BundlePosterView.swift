import SwiftUI
import Photos

// MARK: - 海报入口：配件款式选择
struct PosterStyleSelectView: View {
    let bundleId: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    // 每个分组选中的款式 index
    @State private var selectedIndices: [UUID: Int] = [:]

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
                if let posterImage = posterImage {
                    PosterShareView(image: posterImage)
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
        let posterView = BundlePosterView(
            bundleName: data.bundle.name,
            originalPrice: originalPrice,
            bundlePrice: data.bundle.price,
            accessories: selectedDetails
        )

        let renderer = ImageRenderer(content: posterView)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            posterImage = image
            showPosterPreview = true
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

            Divider().padding(.horizontal, 20)

            // 价格对比区
            priceSection

            Divider().padding(.horizontal, 20)

            // 配件列表
            accessoryListSection

            // 底部
            footerSection
        }
        .frame(width: 375)
        .background(Color.white)
    }

    // MARK: - 顶部品牌区
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text(bundleName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }

    // MARK: - 价格对比区
    private var priceSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("商品原价")
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)
                    Text("¥\(originalPrice)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.gray)
                        .strikethrough()
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Text("套餐价")
                        .font(.system(size: 14, weight: .medium))
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
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.3))
                    Text("¥\(savings)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.3))
                }
                .frame(maxWidth: .infinity)
            }

            if savings > 0 {
                Text("约\(String(format: "%.1f", discount * 10))折")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color.white)
    }

    // MARK: - 配件列表
    private var accessoryListSection: some View {
        VStack(spacing: 0) {
            Text("配件列表")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    // 序号
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.red)
                        .clipShape(Circle())

                    // 缩略图
                    Group {
                        if let path = item.imagePath, let image = ImageStorage.shared.loadImage(filename: path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo")
                                .font(.body)
                                .foregroundStyle(.gray)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))

                    // 分类 + 名称
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.categoryName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                        Text(item.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 价格
                    Text("¥\(item.price)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if index < accessories.count - 1 {
                    Divider().padding(.horizontal, 20)
                }
            }
        }
        .background(Color.white)
        .padding(.bottom, 12)
    }

    // MARK: - 底部
    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扫码咨询")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    Text("了解更多优惠")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray.opacity(0.7))
                }
                Spacer()
                // 二维码占位
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 64, height: 64)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 20))
                                .foregroundStyle(.gray)
                            Text("二维码")
                                .font(.system(size: 8))
                                .foregroundStyle(.gray)
                        }
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }
}

// MARK: - 海报预览与分享
struct PosterShareView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var errorMessage = ""

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
                            Text("分享/保存海报")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        saveToPhotoLibrary()
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
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("好的") {}
            } message: {
                Text("海报已保存到相册")
            }
            .alert("保存失败", isPresented: $showSaveError) {
                Button("好的") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveToPhotoLibrary() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performSave()
                case .denied, .restricted:
                    self.errorMessage = "请在设置中允许访问相册"
                    self.showSaveError = true
                case .notDetermined:
                    self.errorMessage = "无法确定相册权限"
                    self.showSaveError = true
                @unknown default:
                    self.errorMessage = "未知错误"
                    self.showSaveError = true
                }
            }
        }
    }

    private func performSave() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showSaveSuccess = true
                } else {
                    self.errorMessage = error?.localizedDescription ?? "保存失败"
                    self.showSaveError = true
                }
            }
        }
    }
}

#Preview {
    PosterStyleSelectView(bundleId: UUID())
        .environmentObject(DataManager.shared)
}
