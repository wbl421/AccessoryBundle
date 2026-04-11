import SwiftUI
import CoreXLSX
import ZIPFoundation

// MARK: - 解析临时模型

struct ParsedAccessory {
    var name: String
    var price: Int
    var categoryName: String?
    var description: String?
    var thumbnailImages: [UIImage]
    var detailImages: [UIImage]
}

struct ParsedCategory {
    var name: String
    var isNew: Bool
}

struct ParseError {
    var row: Int
    var message: String
}

struct ParseWarning {
    var row: Int
    var message: String
}

struct ParsedImportResult: Identifiable {
    let id = UUID()
    var accessories: [ParsedAccessory]
    var categories: [ParsedCategory]
    var errors: [ParseError]
    var warnings: [ParseWarning]
}

// MARK: - Excel 解析器

class ExcelParser {

    // 模板列定义
    private let headerNames = ["缩略图1", "缩略图2", "缩略图3", "商品名称", "商品价格", "商品分类", "商品详情", "详情图1", "详情图2", "详情图3"]

    // 图片列索引 (0-2 缩略图, 7-9 详情图)
    private let thumbnailColumns = [0, 1, 2]
    private let detailImageColumns = [7, 8, 9]

    // 文字列索引
    private let nameColumn = 3
    private let priceColumn = 4
    private let categoryColumn = 5
    private let descriptionColumn = 6

    /// 解析 xlsx 文件
    func parseXLSX(at url: URL, existingCategories: [AccessoryCategory]) -> ParsedImportResult {
        var accessories: [ParsedAccessory] = []
        var errors: [ParseError] = []
        var warnings: [ParseWarning] = []
        var categoryNames: [String: Bool] = [:] // name -> isNew

        // 已有分类名（小写，用于匹配）
        var existingNameSet: Set<String> = []
        for cat in existingCategories {
            existingNameSet.insert(cat.name.lowercased().trimmingCharacters(in: .whitespaces))
        }

        // 安全域访问
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        // 复制到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("import_\(UUID().uuidString).xlsx")
        try? FileManager.default.removeItem(at: tempURL)

        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            errors.append(ParseError(row: 0, message: "无法读取文件：\(error.localizedDescription)"))
            return ParsedImportResult(accessories: accessories, categories: [], errors: errors, warnings: warnings)
        }

        // 1. 从zip中直接提取共享字符串
        let sharedStrings = extractSharedStrings(from: tempURL)

        // 2. 从zip中直接提取工作表数据
        let rowsData = extractWorksheetRows(from: tempURL, sharedStrings: sharedStrings)

        if rowsData.isEmpty {
            errors.append(ParseError(row: 0, message: "文件中没有数据，请确保Excel中有内容"))
            return ParsedImportResult(accessories: accessories, categories: [], errors: errors, warnings: warnings)
        }

        // 3. 验证表头
        let headerRow = rowsData[0]
        for (index, expectedName) in headerNames.enumerated() {
            let actualName = headerRow[index]?.trimmingCharacters(in: .whitespaces) ?? ""
            if actualName != expectedName {
                warnings.append(ParseWarning(row: 1, message: "第\(index + 1)列表头\"\(actualName)\"与模板\"\(expectedName)\"不一致，将按列位置解析"))
            }
        }

        // 4. 提取图片
        let cellImages = extractImagesFromXLSX(at: tempURL)

        // 5. 解析数据行（从第2行开始）
        for rowIndex in 1..<rowsData.count {
            let row = rowsData[rowIndex]
            let excelRow = rowIndex + 1

            // 跳过完全空行
            let isTextEmpty = row.allSatisfy { $0?.trimmingCharacters(in: .whitespaces).isEmpty ?? true }
            let hasImages = cellImages[excelRow] != nil
            if isTextEmpty && !hasImages { continue }

            let name = row[nameColumn]?.trimmingCharacters(in: .whitespaces) ?? ""
            let priceStr = row[priceColumn]?.trimmingCharacters(in: .whitespaces) ?? ""
            let categoryName = row[categoryColumn]?.trimmingCharacters(in: .whitespaces)
            let description = row[descriptionColumn]?.trimmingCharacters(in: .whitespaces)

            // 验证必填字段
            if name.isEmpty {
                errors.append(ParseError(row: excelRow, message: "商品名称为空，已跳过"))
                continue
            }

            guard let price = Int(priceStr), price >= 0 else {
                errors.append(ParseError(row: excelRow, message: "商品价格\"\(priceStr)\"无效，已跳过"))
                continue
            }

            // 处理分类
            var resolvedCategoryName: String? = nil
            if let catName = categoryName, !catName.isEmpty {
                let lookupKey = catName.lowercased().trimmingCharacters(in: .whitespaces)
                if existingNameSet.contains(lookupKey) {
                    categoryNames[catName] = false
                } else if categoryNames[catName] == nil {
                    categoryNames[catName] = true
                }
                resolvedCategoryName = catName
            }

            // 提取图片
            var thumbnailImages: [UIImage] = []
            var detailImages: [UIImage] = []

            for col in thumbnailColumns {
                if let image = cellImages[excelRow]?[col] {
                    thumbnailImages.append(image)
                }
            }

            for col in detailImageColumns {
                if let image = cellImages[excelRow]?[col] {
                    detailImages.append(image)
                }
            }

            let accessory = ParsedAccessory(
                name: name,
                price: price,
                categoryName: resolvedCategoryName,
                description: description?.isEmpty == true ? nil : description,
                thumbnailImages: thumbnailImages,
                detailImages: detailImages
            )
            accessories.append(accessory)
        }

        // 构建分类列表
        let categories = categoryNames.map { name, isNew in
            ParsedCategory(name: name, isNew: isNew)
        }.sorted { $0.name < $1.name }

        if accessories.isEmpty && errors.isEmpty {
            errors.append(ParseError(row: 0, message: "文件中没有有效数据"))
        }

        return ParsedImportResult(
            accessories: accessories,
            categories: categories,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - 从ZIP直接提取共享字符串

    // swiftlint:disable:next deprecated_declaration
    private func openArchive(at url: URL) -> Archive? {
        Archive(url: url, accessMode: .read)
    }

    private func extractSharedStrings(from url: URL) -> [String] {
        guard let archive = openArchive(at: url) else { return [] }

        // 查找 xl/sharedStrings.xml
        for entry in archive {
            if entry.path == "xl/sharedStrings.xml" {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                guard let xmlStr = String(data: data, encoding: .utf8) else { return [] }
                return parseSharedStringsXML(xmlStr)
            }
        }
        return []
    }

    /// 解析 sharedStrings.xml
    private func parseSharedStringsXML(_ xml: String) -> [String] {
        var strings: [String] = []
        // 提取所有 <si>...</si> 块中的 <t> 文本
        let siPattern = #"<si>(.*?)</si>"#
        guard let siRegex = try? NSRegularExpression(pattern: siPattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(xml.startIndex..., in: xml)

        for match in siRegex.matches(in: xml, range: range) {
            guard let blockRange = Range(match.range(at: 1), in: xml) else { continue }
            let block = String(xml[blockRange])

            // 提取 <t> 或 <t xml:space="preserve"> 中的文本
            let tPattern = #"<t[^>]*>(.*?)</t>"#
            if let tRegex = try? NSRegularExpression(pattern: tPattern, options: [.dotMatchesLineSeparators]) {
                let tRange = NSRange(block.startIndex..., in: block)
                var text = ""
                for tMatch in tRegex.matches(in: block, range: tRange) {
                    guard let textRange = Range(tMatch.range(at: 1), in: block) else { continue }
                    text += String(block[textRange])
                }
                // 解码XML实体
                text = text
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&apos;", with: "'")
                strings.append(text)
            }
        }
        return strings
    }

    // MARK: - 从ZIP直接提取工作表行数据

    private func extractWorksheetRows(from url: URL, sharedStrings: [String]) -> [[String?]] {
        guard let archive = openArchive(at: url) else { return [] }

        // 查找第一个 xl/worksheets/sheet*.xml
        var sheetData: Data?
        for entry in archive {
            if entry.path.hasPrefix("xl/worksheets/sheet") && entry.path.hasSuffix(".xml") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                sheetData = data
                break
            }
        }

        guard let data = sheetData,
              let xmlStr = String(data: data, encoding: .utf8) else { return [] }

        return parseWorksheetXML(xmlStr, sharedStrings: sharedStrings)
    }

    /// 解析工作表 XML，提取行数据
    private func parseWorksheetXML(_ xml: String, sharedStrings: [String]) -> [[String?]] {
        var allRows: [[String?]] = []

        // 提取所有 <row>...</row> 块
        let rowPattern = #"<row[^>]*>(.*?)</row>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(xml.startIndex..., in: xml)

        for rowMatch in rowRegex.matches(in: xml, range: range) {
            guard let rowBlockRange = Range(rowMatch.range(at: 1), in: xml) else { continue }
            let rowBlock = String(xml[rowBlockRange])

            var rowData: [String?] = Array(repeating: nil, count: 10)

            // 提取所有 <c ...>...</c> 单元格
            let cellPattern = #"<c\s+([^>]*?)>(.*?)</c>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else { continue }
            let cellRange = NSRange(rowBlock.startIndex..., in: rowBlock)

            for cellMatch in cellRegex.matches(in: rowBlock, range: cellRange) {
                guard let attrsRange = Range(cellMatch.range(at: 1), in: rowBlock),
                      let contentRange = Range(cellMatch.range(at: 2), in: rowBlock) else { continue }
                let attrs = String(rowBlock[attrsRange])
                let content = String(rowBlock[contentRange])

                // 从属性中提取单元格引用 (r="A1" → 列字母A)
                var colIndex: Int?
                let refPattern = #"r="([A-Z]+)\d+""#
                if let refRegex = try? NSRegularExpression(pattern: refPattern, options: []),
                   let refMatch = refRegex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
                   let refRange = Range(refMatch.range(at: 1), in: attrs) {
                    let colLetter = String(attrs[refRange])
                    colIndex = columnLetterToInt(colLetter)
                }

                guard let col = colIndex, col < 10 else { continue }

                // 判断单元格类型
                let isSharedString = attrs.contains("t=\"s\"")
                let isInlineString = attrs.contains("t=\"inlineStr\"")

                // 提取值
                var cellValue: String?

                if isSharedString {
                    // 共享字符串：从 <v> 获取索引
                    let vPattern = #"<v>(.*?)</v>"#
                    if let vRegex = try? NSRegularExpression(pattern: vPattern, options: []),
                       let vMatch = vRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                       let vRange = Range(vMatch.range(at: 1), in: content) {
                        let indexStr = String(content[vRange])
                        if let index = Int(indexStr), index < sharedStrings.count {
                            cellValue = sharedStrings[index]
                        }
                    }
                } else if isInlineString {
                    // 内联字符串：从 <is><t> 获取
                    let tPattern = #"<t[^>]*>(.*?)</t>"#
                    if let tRegex = try? NSRegularExpression(pattern: tPattern, options: [.dotMatchesLineSeparators]),
                       let tMatch = tRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                       let tRange = Range(tMatch.range(at: 1), in: content) {
                        cellValue = String(content[tRange])
                    }
                } else {
                    // 数字等：直接从 <v> 获取值
                    let vPattern = #"<v>(.*?)</v>"#
                    if let vRegex = try? NSRegularExpression(pattern: vPattern, options: []),
                       let vMatch = vRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                       let vRange = Range(vMatch.range(at: 1), in: content) {
                        cellValue = String(content[vRange])
                    }
                }

                rowData[col] = cellValue
            }

            allRows.append(rowData)
        }

        return allRows
    }

    /// 列字母转0-based索引 (A=0, B=1, ..., Z=25, AA=26, ...)
    private func columnLetterToInt(_ letter: String) -> Int {
        var result = 0
        for char in letter {
            if let value = char.asciiValue {
                result = result * 26 + Int(value - 65)
            }
        }
        return result
    }

    // MARK: - 图片提取（从xlsx zip包）

    private func extractImagesFromXLSX(at url: URL) -> [Int: [Int: UIImage]] {
        var result: [Int: [Int: UIImage]] = [:]

        guard let archive = openArchive(at: url) else { return result }

        // 1. 提取所有图片数据 (xl/media/ 目录)
        var imageDataList: [(path: String, data: Data)] = []
        for entry in archive {
            if entry.path.hasPrefix("xl/media/") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if !data.isEmpty {
                    imageDataList.append((path: entry.path, data: data))
                }
            }
        }

        guard !imageDataList.isEmpty else { return result }

        // 2. 解析 drawing 关系文件
        var imageRels: [String: String] = [:] // rId -> media path
        for entry in archive {
            if entry.path.hasPrefix("xl/drawings/_rels/") && entry.path.hasSuffix(".rels") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    let pattern = #"Id="([^"]+)".*Target="([^"]+)""#
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let range = NSRange(xmlStr.startIndex..., in: xmlStr)
                        for match in regex.matches(in: xmlStr, range: range) {
                            if let idRange = Range(match.range(at: 1), in: xmlStr),
                               let targetRange = Range(match.range(at: 2), in: xmlStr) {
                                let id = String(xmlStr[idRange])
                                let target = String(xmlStr[targetRange])
                                imageRels[id] = "xl/drawings/" + target
                            }
                        }
                    }
                }
            }
        }

        // 3. media path -> 图片Data 映射
        var mediaMap: [String: Data] = [:]
        for item in imageDataList {
            mediaMap[item.path] = item.data
        }

        // 4. 解析 drawing XML
        var imagePositions: [(row: Int, col: Int, imageData: Data)] = []
        for entry in archive {
            if entry.path.hasPrefix("xl/drawings/") && entry.path.hasSuffix(".xml") && !entry.path.contains("_rels") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    parseDrawingXML(xmlStr, imageRels: imageRels, mediaMap: mediaMap, result: &imagePositions)
                }
            }
        }

        // 5. 映射图片到单元格
        if !imagePositions.isEmpty {
            for pos in imagePositions {
                if let image = UIImage(data: pos.imageData) {
                    if result[pos.row] == nil { result[pos.row] = [:] }
                    result[pos.row]?[pos.col] = image
                }
            }
        } else if !imageDataList.isEmpty {
            // 回退：按图片顺序分配到图片列
            var imgIndex = 0
            for row in 2...200 {
                for col in [0, 1, 2, 7, 8, 9] {
                    if imgIndex < imageDataList.count {
                        if let image = UIImage(data: imageDataList[imgIndex].data) {
                            if result[row] == nil { result[row] = [:] }
                            result[row]?[col] = image
                        }
                        imgIndex += 1
                    }
                }
            }
        }

        return result
    }

    /// 解析 drawing XML
    private func parseDrawingXML(_ xmlStr: String, imageRels: [String: String], mediaMap: [String: Data], result: inout [(row: Int, col: Int, imageData: Data)]) {
        let anchorPattern = #"<xdr:twoCellAnchor[^>]*>(.*?)</xdr:twoCellAnchor>"#
        let oneAnchorPattern = #"<xdr:oneCellAnchor[^>]*>(.*?)</xdr:oneCellAnchor>"#

        for pattern in [anchorPattern, oneAnchorPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(xmlStr.startIndex..., in: xmlStr)

            for match in regex.matches(in: xmlStr, range: range) {
                guard let blockRange = Range(match.range(at: 1), in: xmlStr) else { continue }
                let block = String(xmlStr[blockRange])

                var col: Int?
                var row: Int?
                var rId: String?

                if let fromRange = block.range(of: "<xdr:from>", options: []),
                   let fromEndRange = block.range(of: "</xdr:from>", options: []) {
                    let fromBlock = String(block[fromRange.lowerBound..<fromEndRange.upperBound])
                    if let colMatch = extractXMLValue(from: fromBlock, tag: "xdr:col") {
                        col = Int(colMatch)
                    }
                    if let rowMatch = extractXMLValue(from: fromBlock, tag: "xdr:row") {
                        row = Int(rowMatch)
                    }
                }

                let rIdPattern = #"r:embed="([^"]+)""#
                if let rIdRegex = try? NSRegularExpression(pattern: rIdPattern, options: []),
                   let rIdMatch = rIdRegex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
                   let rIdRange = Range(rIdMatch.range(at: 1), in: block) {
                    rId = String(block[rIdRange])
                }

                if let col = col, let row = row, let rId = rId,
                   let mediaPath = imageRels[rId],
                   let imageData = mediaMap[mediaPath] {
                    result.append((row: row, col: col, imageData: imageData))
                }
            }
        }
    }

    /// 从XML字符串中提取标签值
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let openRange = xml.range(of: openTag, options: []),
              let closeRange = xml.range(of: closeTag, options: []) else { return nil }
        return String(xml[openRange.upperBound..<closeRange.lowerBound])
    }
}
