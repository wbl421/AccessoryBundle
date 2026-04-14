import SwiftUI

// MARK: - Batch Import Entry View (批量导入入口)
struct BatchImportEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    // 导入相关状态
    @State private var showingDocumentPicker = false
    @State private var parsedResult: ParsedImportResult?
    @State private var importErrorMessage: String?
    
    // 模板URL（页面加载时初始化）
    @State private var templateURL: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部说明区域
                    VStack(spacing: 6) {
                        Text("批量导入配件")
                            .font(.title2.bold())
                        Text("通过Excel表格快速导入多个配件数据")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemBackground))
                    
                    // 选项卡片区域
                    VStack(spacing: 12) {
                        // 选项A：下载导入模板
                        if let url = templateURL {
                            ShareLink(item: url, subject: Text("配件导入模板")) {
                                optionCardContent(
                                    icon: "arrow.down.doc",
                                    iconColor: .green,
                                    title: "下载导入模板",
                                    subtitle: "获取标准模板，按格式填写后上传"
                                )
                            }
                        } else {
                            optionCardContent(
                                icon: "arrow.down.doc",
                                iconColor: .green,
                                title: "下载导入模板",
                                subtitle: "模板加载中..."
                            )
                            .onAppear {
                                templateURL = TemplateManager.shared.getTemplateURL()
                            }
                        }
                        
                        // 选项B：直接导入文件
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            optionCardContent(
                                icon: "square.and.arrow.down",
                                iconColor: .blue,
                                title: "直接导入文件",
                                subtitle: "选择已填写好的Excel文件导入"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color(.systemGroupedBackground))
                    
                    // 使用说明区域
                    VStack(alignment: .leading, spacing: 0) {
                        Text("使用说明")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            instructionRow(number: 1, text: "下载模板获取标准格式文件")
                            instructionRow(number: 2, text: "在Excel中填写配件信息")
                            instructionRow(number: 3, text: "可插入商品图片到对应单元格")
                            instructionRow(number: 4, text: "保存后选择「直接导入文件」")
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .padding(.top, 8)
                    
                    Spacer(minLength: 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("批量导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("导入失败", isPresented: .constant(importErrorMessage != nil)) {
                Button("确定") { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        parseImportFile(url: url)
                    }
                }
            }
            .fullScreenCover(item: $parsedResult) { result in
                ImportPreviewView(result: result)
                    .environmentObject(dataManager)
            }
        }
        .onAppear {
            if templateURL == nil {
                templateURL = TemplateManager.shared.getTemplateURL()
            }
        }
    }
    
    // MARK: - 选项卡片内容
    private func optionCardContent(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            
            // 文字
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 说明行
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color(.darkGray))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 解析导入文件
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
}

#Preview {
    BatchImportEntryView()
        .environmentObject(DataManager.shared)
}
