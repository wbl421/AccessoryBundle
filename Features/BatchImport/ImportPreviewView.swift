import SwiftUI

// MARK: - Import Preview View
struct ImportPreviewView: View {
    let result: ParsedImportResult
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var importComplete = false
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            if importComplete {
                successView
            } else if isImporting {
                importingView
            } else {
                previewView
            }
        }
    }

    // MARK: - 预览视图
    private var previewView: some View {
        List {
            // 摘要
            Section {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(result.accessories.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("个配件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    if !result.categories.filter(\.isNew).isEmpty {
                        VStack(spacing: 4) {
                            Text("\(result.categories.filter(\.isNew).count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                            Text("个新分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if !result.errors.isEmpty {
                        VStack(spacing: 4) {
                            Text("\(result.errors.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            Text("个错误")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }

            // 新分类
            let newCategories = result.categories.filter(\.isNew)
            if !newCategories.isEmpty {
                Section("将自动创建的分类") {
                    ForEach(newCategories, id: \.name) { cat in
                        HStack {
                            Image(systemName: "folder.fill.badge.plus")
                                .foregroundStyle(.orange)
                            Text(cat.name)
                                .font(.subheadline)
                        }
                    }
                }
            }

            // 警告
            if !result.warnings.isEmpty {
                Section("警告") {
                    ForEach(result.warnings, id: \.row) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("第\(warning.row)行: \(warning.message)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 错误
            if !result.errors.isEmpty {
                Section("错误（将被跳过）") {
                    ForEach(result.errors, id: \.row) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("第\(error.row)行: \(error.message)")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }

            // 配件列表
            Section("配件列表 (\(result.accessories.count))") {
                ForEach(Array(result.accessories.enumerated()), id: \.offset) { index, accessory in
                    HStack(spacing: 12) {
                        // 缩略图
                        if let firstImage = accessory.thumbnailImages.first {
                            Image(uiImage: firstImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        // 信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(accessory.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text("¥\(accessory.price)")
                                    .font(.caption)
                                    .foregroundStyle(.red)

                                if let catName = accessory.categoryName {
                                    Text(catName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        Spacer()

                        // 图片数量提示
                        let imgCount = accessory.thumbnailImages.count + accessory.detailImages.count
                        if imgCount > 0 {
                            Text("\(imgCount)张图")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("导入预览")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("确认导入") {
                    performImport()
                }
                .fontWeight(.semibold)
                .disabled(result.accessories.isEmpty)
            }
        }
    }

    // MARK: - 导入中视图
    private var importingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在导入配件...")
                .font(.headline)
            Text("请勿关闭此页面")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 成功视图
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("导入完成")
                .font(.title2)
                .fontWeight(.bold)

            Text("成功导入 \(importedCount) 个配件")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    // MARK: - 执行导入
    private func performImport() {
        isImporting = true

        let count = dataManager.batchImportAccessories(
            parsed: result.accessories,
            newCategoryNames: result.categories.filter(\.isNew).map(\.name)
        )

        importedCount = count
        isImporting = false
        importComplete = true
    }
}
