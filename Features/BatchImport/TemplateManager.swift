import SwiftUI

// MARK: - Template Manager
class TemplateManager {
    static let shared = TemplateManager()

    /// 获取模板文件URL（从Bundle中复制到临时目录）
    func getTemplateURL() -> URL? {
        guard let bundleURL = Foundation.Bundle.main.url(forResource: "import_template", withExtension: "xlsx") else {
            return nil
        }

        // 复制到临时目录以便分享
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("配件导入模板.xlsx")

        // 如果临时目录已有旧文件，先删除
        try? FileManager.default.removeItem(at: tempURL)

        do {
            try FileManager.default.copyItem(at: bundleURL, to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
}
