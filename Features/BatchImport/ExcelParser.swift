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

    // 模板列定义（14列：5缩略图 + 4文字 + 5详情图）
    private let headerNames = ["缩略图1", "缩略图2", "缩略图3", "缩略图4", "缩略图5", "商品名称", "商品价格", "商品分类", "商品详情", "详情图1", "详情图2", "详情图3", "详情图4", "详情图5"]

    // 图片列索引 (0-4 缩略图, 9-13 详情图)
    private let thumbnailColumns = [0, 1, 2, 3, 4]
    private let detailImageColumns = [9, 10, 11, 12, 13]

    // 文字列索引
    private let nameColumn = 5
    private let priceColumn = 6
    private let categoryColumn = 7
    private let descriptionColumn = 8

    // 列数
    private let columnCount = 14

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

        // 3. 验证表头（支持带"（必填）"等后缀的表头）
        let headerRow = rowsData[0]
        for (index, expectedName) in headerNames.enumerated() {
            let actualName = headerRow[index]?.trimmingCharacters(in: .whitespaces) ?? ""
            if actualName != expectedName && !actualName.hasPrefix(expectedName) {
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

        // 通过 workbook.xml 找到第一个 sheet 的文件路径
        let firstSheetPath = findFirstSheetPath(in: archive)

        var sheetData: Data?
        for entry in archive {
            if entry.path == firstSheetPath {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                sheetData = data
                break
            }
        }

        // 回退：如果通过 workbook.xml 找不到，按文件名顺序取第一个
        if sheetData == nil {
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
        }

        guard let data = sheetData,
              let xmlStr = String(data: data, encoding: .utf8) else { return [] }

        return parseWorksheetXML(xmlStr, sharedStrings: sharedStrings)
    }

    /// 从 workbook.xml 和 workbook.xml.rels 中找到第一个 sheet 的路径
    private func findFirstSheetPath(in archive: Archive) -> String {
        // 1. 从 workbook.xml 中找到第一个 sheet 的 rId
        var firstSheetRId: String?
        for entry in archive {
            if entry.path == "xl/workbook.xml" {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    // 匹配 <sheet name="xxx" sheetId="1" r:id="rId1"/>
                    let pattern = #"r:id="([^"]+)""#
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                       let match = regex.firstMatch(in: xmlStr, range: NSRange(xmlStr.startIndex..., in: xmlStr)),
                       let range = Range(match.range(at: 1), in: xmlStr) {
                        firstSheetRId = String(xmlStr[range])
                    }
                }
                break
            }
        }

        guard let rId = firstSheetRId else { return "" }

        // 2. 从 workbook.xml.rels 中找到 rId 对应的 Target 路径
        for entry in archive {
            if entry.path == "xl/_rels/workbook.xml.rels" {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    // 匹配 <Relationship Id="rId1" Target="worksheets/sheet1.xml"/>
                    let pattern = #"Id="\(rId)"[^>]*Target="([^"]+)""#
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                       let match = regex.firstMatch(in: xmlStr, range: NSRange(xmlStr.startIndex..., in: xmlStr)),
                       let range = Range(match.range(at: 1), in: xmlStr) {
                        var target = String(xmlStr[range])
                        // Target 可能是 "/xl/worksheets/sheet1.xml" 或 "worksheets/sheet1.xml"
                        if target.hasPrefix("/") {
                            target = String(target.dropFirst()) // 去掉开头的 /
                        }
                        if !target.hasPrefix("xl/") {
                            target = "xl/" + target
                        }
                        return target
                    }
                }
                break
            }
        }

        return ""
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

            var rowData: [String?] = Array(repeating: nil, count: columnCount)

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

                guard let col = colIndex, col < columnCount else { continue }

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
            if entry.path.hasPrefix("xl/media/") && !entry.path.hasSuffix("/") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if !data.isEmpty {
                    imageDataList.append((path: entry.path, data: data))
                }
            }
        }

        print("[ExcelParser] 找到 \(imageDataList.count) 张图片")
        for item in imageDataList {
            print("[ExcelParser]   - \(item.path) (\(item.data.count) bytes)")
        }

        guard !imageDataList.isEmpty else { return result }

        // media path -> 图片Data 映射
        var mediaMap: [String: Data] = [:]
        for item in imageDataList {
            mediaMap[item.path] = item.data
        }

        // 2. 优先尝试 WPS cellimages 方式（WPS专有，国内用户最常用）
        let wpsResult = extractWPSCellImages(archive: archive, mediaMap: mediaMap)
        if !wpsResult.isEmpty {
            print("[ExcelParser] WPS cellimages 方式成功，映射 \(wpsResult.values.flatMap { $0.values }.count) 张图片")
            for (row, cols) in wpsResult.sorted(by: { $0.key < $1.key }) {
                print("[ExcelParser]   row \(row): cols \(cols.keys.sorted())")
            }
            return wpsResult
        }

        // 3. 尝试标准 drawing XML 方式（Excel 生成的文件）
        let drawingResult = extractDrawingXMLImages(archive: archive, mediaMap: mediaMap, imageDataList: imageDataList)
        if !drawingResult.isEmpty {
            print("[ExcelParser] drawing XML 方式成功，映射 \(drawingResult.values.flatMap { $0.values }.count) 张图片")
            for (row, cols) in drawingResult.sorted(by: { $0.key < $1.key }) {
                print("[ExcelParser]   row \(row): cols \(cols.keys.sorted())")
            }
            return drawingResult
        }

        // 4. 最终 fallback：按图片文件名顺序智能分配
        print("[ExcelParser] 所有方式失败，使用 fallback 分配策略")
        fallbackImageAssignment(imageDataList: imageDataList, result: &result)
        return result
    }

    // MARK: - WPS cellimages 方式

    /// 提取 WPS 专有的 cellimages 图片（WPS 使用 _xlfn.DISPIMG 公式 + cellimages.xml）
    private func extractWPSCellImages(archive: Archive, mediaMap: [String: Data]) -> [Int: [Int: UIImage]] {
        var result: [Int: [Int: UIImage]] = [:]

        // Step 1: 检查是否存在 cellimages.xml 和 cellimages.xml.rels
        var cellImagesXML: String?
        var cellImagesRelsXML: String?

        for entry in archive {
            if entry.path == "xl/cellimages.xml" {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                cellImagesXML = String(data: data, encoding: .utf8)
            } else if entry.path == "xl/_rels/cellimages.xml.rels" {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                cellImagesRelsXML = String(data: data, encoding: .utf8)
            }
        }

        guard let cellImagesXMLStr = cellImagesXML else {
            print("[ExcelParser] WPS: 未找到 xl/cellimages.xml")
            return result
        }

        print("[ExcelParser] WPS: 找到 cellimages.xml")

        // Step 2: 解析 cellimages.xml.rels → rId → mediaPath
        var cellImageRels: [String: String] = [:]
        if let relsXML = cellImagesRelsXML {
            cellImageRels = parseRelsXML(relsXML, basePath: "xl/")
            print("[ExcelParser] WPS cellimages rels: \(cellImageRels)")
        }

        // Step 3: 解析 cellimages.xml → imageID → rId
        // 格式: <etc:cellImage><xdr:pic><xdr:nvPicPr><xdr:cNvPr name="ID_xxx" .../>
        //        <xdr:blipFill><a:blip r:embed="rId1"/></xdr:blipFill>
        var imageIDToRId: [String: String] = [:]
        let cellImagePattern = #"<etc:cellImage>(.*?)</etc:cellImage>"#
        if let cellImageRegex = try? NSRegularExpression(pattern: cellImagePattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(cellImagesXMLStr.startIndex..., in: cellImagesXMLStr)
            for match in cellImageRegex.matches(in: cellImagesXMLStr, range: range) {
                guard let blockRange = Range(match.range(at: 1), in: cellImagesXMLStr) else { continue }
                let block = String(cellImagesXMLStr[blockRange])

                // 提取 cNvPr name 属性 (图片ID)
                var imageID: String?
                let namePattern = #"name="([^"]+)""#
                if let nameRegex = try? NSRegularExpression(pattern: namePattern, options: []),
                   let nameMatch = nameRegex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
                   let nameRange = Range(nameMatch.range(at: 1), in: block) {
                    imageID = String(block[nameRange])
                }

                // 提取 blip r:embed (rId)
                var rId: String?
                let embedPattern = #"r:embed="([^"]+)""#
                if let embedRegex = try? NSRegularExpression(pattern: embedPattern, options: []),
                   let embedMatch = embedRegex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
                   let embedRange = Range(embedMatch.range(at: 1), in: block) {
                    rId = String(block[embedRange])
                }

                if let imageID = imageID, let rId = rId {
                    imageIDToRId[imageID] = rId
                    print("[ExcelParser] WPS: imageID=\(imageID) → rId=\(rId)")
                }
            }
        }

        // Step 4: 构建 imageID → imageData 映射
        var imageIDToData: [String: Data] = [:]
        for (imageID, rId) in imageIDToRId {
            if let mediaPath = cellImageRels[rId], let imageData = mediaMap[mediaPath] {
                imageIDToData[imageID] = imageData
                print("[ExcelParser] WPS: imageID=\(imageID) → rId=\(rId) → \(mediaPath) (\(imageData.count) bytes)")
            } else if let mediaPath = cellImageRels[rId] {
                // 尝试路径变体
                let variants = generatePathVariants(mediaPath)
                for variant in variants {
                    if let imageData = mediaMap[variant] {
                        imageIDToData[imageID] = imageData
                        print("[ExcelParser] WPS: imageID=\(imageID) → rId=\(rId) → \(variant) (\(imageData.count) bytes) [变体]")
                        break
                    }
                }
            } else {
                print("[ExcelParser] WPS: imageID=\(imageID) → rId=\(rId) → 未找到media路径")
            }
        }

        // Step 5: 从 worksheet XML 中解析 DISPIMG 公式，获取 (row, col) → imageID
        let sheetPath = findFirstSheetPath(in: archive)
        var sheetXML: String?
        for entry in archive {
            if entry.path == sheetPath || (sheetPath.isEmpty && entry.path.hasPrefix("xl/worksheets/sheet") && entry.path.hasSuffix(".xml") && !entry.path.contains("_rels")) {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                sheetXML = String(data: data, encoding: .utf8)
                break
            }
        }

        guard let sheetXMLStr = sheetXML else {
            print("[ExcelParser] WPS: 未找到 worksheet XML")
            return result
        }

        // 解析 DISPIMG 公式
        let dispimgMappings = parseDISPIMGFormulas(sheetXMLStr)
        print("[ExcelParser] WPS: 找到 \(dispimgMappings.count) 个 DISPIMG 公式")
        for mapping in dispimgMappings {
            print("[ExcelParser] WPS:   row=\(mapping.row), col=\(mapping.col), imageID=\(mapping.imageID)")
        }

        // Step 6: 组合 (row, col, imageID) + (imageID, imageData) → 最终结果
        for mapping in dispimgMappings {
            if let imageData = imageIDToData[mapping.imageID], let image = UIImage(data: imageData) {
                if result[mapping.row] == nil { result[mapping.row] = [:] }
                result[mapping.row]?[mapping.col] = image
                print("[ExcelParser] WPS: 映射 row=\(mapping.row), col=\(mapping.col)")
            } else {
                print("[ExcelParser] WPS: 无法映射 row=\(mapping.row), col=\(mapping.col), imageID=\(mapping.imageID)")
            }
        }

        return result
    }

    /// 从 worksheet XML 中解析 _xlfn.DISPIMG 公式，返回 (row, col, imageID)
    private func parseDISPIMGFormulas(_ xml: String) -> [(row: Int, col: Int, imageID: String)] {
        var mappings: [(row: Int, col: Int, imageID: String)] = []

        // 提取所有 <row>...</row> 块
        let rowPattern = #"<row[^>]*>(.*?)</row>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(xml.startIndex..., in: xml)

        for rowMatch in rowRegex.matches(in: xml, range: range) {
            guard let rowBlockRange = Range(rowMatch.range(at: 1), in: xml) else { continue }
            let rowBlock = String(xml[rowBlockRange])

            // 提取所有 <c ...>...</c> 单元格
            let cellPattern = #"<c\s+([^>]*?)>(.*?)</c>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else { continue }
            let cellRange = NSRange(rowBlock.startIndex..., in: rowBlock)

            for cellMatch in cellRegex.matches(in: rowBlock, range: cellRange) {
                guard let attrsRange = Range(cellMatch.range(at: 1), in: rowBlock),
                      let contentRange = Range(cellMatch.range(at: 2), in: rowBlock) else { continue }
                let attrs = String(rowBlock[attrsRange])
                let content = String(rowBlock[contentRange])

                // 检查是否包含 DISPIMG 公式
                guard content.contains("DISPIMG") else { continue }

                // 提取单元格位置 r="A2"
                var colIndex: Int?
                var rowNumber: Int?
                let refPattern = #"r="([A-Z]+)(\d+)""#
                if let refRegex = try? NSRegularExpression(pattern: refPattern, options: []),
                   let refMatch = refRegex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)) {
                    if let colRange = Range(refMatch.range(at: 1), in: attrs) {
                        colIndex = columnLetterToInt(String(attrs[colRange]))
                    }
                    if let rowRange = Range(refMatch.range(at: 2), in: attrs) {
                        rowNumber = Int(String(attrs[rowRange]))
                    }
                }

                guard let col = colIndex, let row = rowNumber else { continue }

                // 提取 imageID: DISPIMG("ID_xxx",1) 或 DISPIMG("ID_xxx")
                let dispimgPattern = #"DISPIMG\(&quot;([^&]+)&quot;"#
                if let dispimgRegex = try? NSRegularExpression(pattern: dispimgPattern, options: []),
                   let dispimgMatch = dispimgRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                   let idRange = Range(dispimgMatch.range(at: 1), in: content) {
                    let imageID = String(content[idRange])
                    mappings.append((row: row, col: col, imageID: imageID))
                } else {
                    // 也尝试非转义的引号
                    let dispimgPattern2 = #"DISPIMG\("([^"]+)""#
                    if let dispimgRegex2 = try? NSRegularExpression(pattern: dispimgPattern2, options: []),
                       let dispimgMatch2 = dispimgRegex2.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                       let idRange2 = Range(dispimgMatch2.range(at: 1), in: content) {
                        let imageID = String(content[idRange2])
                        mappings.append((row: row, col: col, imageID: imageID))
                    }
                }
            }
        }

        return mappings
    }

    // MARK: - 标准 Drawing XML 方式

    /// 提取标准 drawing XML 中的图片（Excel 生成的文件）
    private func extractDrawingXMLImages(archive: Archive, mediaMap: [String: Data], imageDataList: [(path: String, data: Data)]) -> [Int: [Int: UIImage]] {
        var result: [Int: [Int: UIImage]] = [:]
        var imagePositions: [(row: Int, col: Int, imageData: Data)] = []

        // 解析 drawing 关系文件（每个 drawing XML 有自己的 rels 文件）
        var drawingRelsMap: [String: [String: String]] = [:]
        for entry in archive {
            if entry.path.hasPrefix("xl/drawings/_rels/") && entry.path.hasSuffix(".rels") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    let pathComponents = entry.path.split(separator: "/")
                    let relsFileName = String(pathComponents.last ?? "")
                    let drawingFileName = relsFileName.replacingOccurrences(of: ".rels", with: "")
                    let rels = parseRelsXML(xmlStr, basePath: "xl/drawings/")
                    if !rels.isEmpty {
                        drawingRelsMap[drawingFileName] = rels
                    }
                }
            }
        }

        guard !drawingRelsMap.isEmpty else {
            print("[ExcelParser] Drawing: 未找到 drawing rels 文件")
            return result
        }

        print("[ExcelParser] Drawing rels: \(drawingRelsMap)")

        // 解析 drawing XML
        for entry in archive {
            if entry.path.hasPrefix("xl/drawings/") && entry.path.hasSuffix(".xml") && !entry.path.contains("_rels") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                if let xmlStr = String(data: data, encoding: .utf8) {
                    let pathComponents = entry.path.split(separator: "/")
                    let drawingFileName = String(pathComponents.last ?? "")
                    let imageRels = drawingRelsMap[drawingFileName] ?? [:]
                    print("[ExcelParser] Drawing: 解析 \(drawingFileName), rels数: \(imageRels.count)")
                    parseDrawingXML(xmlStr, imageRels: imageRels, mediaMap: mediaMap, imageDataList: imageDataList, result: &imagePositions)
                }
            }
        }

        print("[ExcelParser] Drawing: 解析得到 \(imagePositions.count) 个图片位置")

        // 映射到结果（drawing XML 中 row/col 是 0-based，需 +1）
        for pos in imagePositions {
            if let image = UIImage(data: pos.imageData) {
                let excelRow = pos.row + 1
                if result[excelRow] == nil { result[excelRow] = [:] }
                result[excelRow]?[pos.col] = image
            }
        }

        return result
    }

    /// 通用解析 .rels 文件，返回 [Id → resolvedMediaPath]
    private func parseRelsXML(_ xmlStr: String, basePath: String) -> [String: String] {
        var rels: [String: String] = [:]
        let relPattern = #"<Relationship\s+[^>]*/?>"#
        guard let relRegex = try? NSRegularExpression(pattern: relPattern, options: [.dotMatchesLineSeparators]) else { return rels }
        let range = NSRange(xmlStr.startIndex..., in: xmlStr)

        for relMatch in relRegex.matches(in: xmlStr, range: range) {
            guard let relRange = Range(relMatch.range(at: 0), in: xmlStr) else { continue }
            let relElement = String(xmlStr[relRange])

            var id: String?
            var target: String?

            let idPattern = #"Id="([^"]+)""#
            if let idRegex = try? NSRegularExpression(pattern: idPattern, options: []),
               let idMatch = idRegex.firstMatch(in: relElement, range: NSRange(relElement.startIndex..., in: relElement)),
               let idRange = Range(idMatch.range(at: 1), in: relElement) {
                id = String(relElement[idRange])
            }

            let targetPattern = #"Target="([^"]+)""#
            if let targetRegex = try? NSRegularExpression(pattern: targetPattern, options: []),
               let targetMatch = targetRegex.firstMatch(in: relElement, range: NSRange(relElement.startIndex..., in: relElement)),
               let targetRange = Range(targetMatch.range(at: 1), in: relElement) {
                target = String(relElement[targetRange])
            }

            if let id = id, let target = target {
                if target.contains("media") || target.contains("image") {
                    let resolvedPath = resolveRelativePath(target, basePath: basePath)
                    rels[id] = resolvedPath
                }
            }
        }
        return rels
    }

    /// Fallback: 当 drawing XML 解析失败时，按图片文件名排序后智能分配
    private func fallbackImageAssignment(imageDataList: [(path: String, data: Data)], result: inout [Int: [Int: UIImage]]) {
        // 按文件路径排序（确保 image1, image2, ... 顺序正确）
        let sortedImages = imageDataList.sorted { $0.path < $1.path }

        // xlsx 中图片通常按列优先顺序排列：
        // 第一个产品的所有图片 → 第二个产品的所有图片
        // 每个产品的图片顺序：缩略图1-5 + 详情图1-5
        let imagesPerProduct = thumbnailColumns.count + detailImageColumns.count // 10

        var imgIndex = 0
        var dataRow = 2 // Excel 数据从第2行开始

        while imgIndex < sortedImages.count {
            var thumbIdx = 0
            var detailIdx = 0

            // 为当前行分配图片
            for i in 0..<imagesPerProduct {
                if imgIndex >= sortedImages.count { break }
                if let image = UIImage(data: sortedImages[imgIndex].data) {
                    if result[dataRow] == nil { result[dataRow] = [:] }

                    if i < thumbnailColumns.count {
                        // 前5张作为缩略图
                        result[dataRow]?[thumbnailColumns[thumbIdx]] = image
                        thumbIdx += 1
                    } else {
                        // 后5张作为详情图
                        result[dataRow]?[detailImageColumns[detailIdx]] = image
                        detailIdx += 1
                    }
                }
                imgIndex += 1
            }
            dataRow += 1
        }
    }

    /// 解析 drawing XML
    private func parseDrawingXML(_ xmlStr: String, imageRels: [String: String], mediaMap: [String: Data], imageDataList: [(path: String, data: Data)], result: inout [(row: Int, col: Int, imageData: Data)]) {
        // 同时支持带命名空间前缀和不带前缀的标签
        // 有些 xlsx 生成器使用 <twoCellAnchor>，有些用 <xdr:twoCellAnchor>
        let anchorPatterns = [
            #"<xdr:twoCellAnchor[^>]*>(.*?)</xdr:twoCellAnchor>"#,
            #"<twoCellAnchor[^>]*>(.*?)</twoCellAnchor>"#,
            #"<xdr:oneCellAnchor[^>]*>(.*?)</xdr:oneCellAnchor>"#,
            #"<oneCellAnchor[^>]*>(.*?)</oneCellAnchor>"#
        ]

        for pattern in anchorPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(xmlStr.startIndex..., in: xmlStr)

            for match in regex.matches(in: xmlStr, range: range) {
                guard let blockRange = Range(match.range(at: 1), in: xmlStr) else { continue }
                let block = String(xmlStr[blockRange])

                var col: Int?
                var row: Int?
                var rId: String?

                // 提取 from 块中的 col 和 row（支持 xdr: 前缀和无前缀）
                let fromPatterns = ["<xdr:from>", "<from>"]
                let fromEndPatterns = ["</xdr:from>", "</from>"]

                for (fp, fep) in zip(fromPatterns, fromEndPatterns) {
                    if let fromRange = block.range(of: fp, options: []),
                       let fromEndRange = block.range(of: fep, options: []) {
                        let fromBlock = String(block[fromRange.lowerBound..<fromEndRange.upperBound])

                        // 尝试带前缀和无前缀的标签
                        for prefix in ["xdr:", ""] {
                            if col == nil, let colMatch = extractXMLValue(from: fromBlock, tag: "\(prefix)col") {
                                col = Int(colMatch)
                            }
                            if row == nil, let rowMatch = extractXMLValue(from: fromBlock, tag: "\(prefix)row") {
                                row = Int(rowMatch)
                            }
                        }
                        break
                    }
                }

                // 提取 rId（支持 r:embed 和 embed 两种写法）
                let rIdPatterns = [#"r:embed="([^"]+)""#, #"embed="([^"]+)""#]
                for rIdPattern in rIdPatterns {
                    if rId != nil { break }
                    if let rIdRegex = try? NSRegularExpression(pattern: rIdPattern, options: []),
                       let rIdMatch = rIdRegex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
                       let rIdRange = Range(rIdMatch.range(at: 1), in: block) {
                        rId = String(block[rIdRange])
                    }
                }

                guard let col = col, let row = row, let rId = rId else {
                    print("[ExcelParser]   跳过: col=\(col as Any), row=\(row as Any), rId=\(rId as Any)")
                    continue
                }

                // 方式1: 通过 imageRels + mediaMap 查找
                if let mediaPath = imageRels[rId],
                   let imageData = mediaMap[mediaPath] {
                    result.append((row: row, col: col, imageData: imageData))
                    print("[ExcelParser]   方式1成功: rId=\(rId), mediaPath=\(mediaPath), row=\(row), col=\(col)")
                    continue
                }

                // 方式1.5: 尝试不同的路径变体
                if let mediaPath = imageRels[rId] {
                    let pathVariants = generatePathVariants(mediaPath)
                    for variant in pathVariants {
                        if let imageData = mediaMap[variant] {
                            result.append((row: row, col: col, imageData: imageData))
                            print("[ExcelParser]   方式1.5成功: rId=\(rId), mediaPath=\(mediaPath)→\(variant), row=\(row), col=\(col)")
                            break
                        }
                    }
                    if result.last?.row == row && result.last?.col == col { continue }
                }

                // 方式2: 回退 - rId 中的数字通常对应图片序号 (rId1→image1, rId2→image2)
                let rIdNumPattern = #"rId(\d+)"#
                if let rIdNumRegex = try? NSRegularExpression(pattern: rIdNumPattern, options: []),
                   let rIdNumMatch = rIdNumRegex.firstMatch(in: rId, range: NSRange(rId.startIndex..., in: rId)),
                   let numRange = Range(rIdNumMatch.range(at: 1), in: rId),
                   let imageIndex = Int(String(rId[numRange])),
                   imageIndex >= 1, imageIndex <= imageDataList.count {
                    result.append((row: row, col: col, imageData: imageDataList[imageIndex - 1].data))
                    print("[ExcelParser]   方式2成功: rId=\(rId)→index=\(imageIndex), row=\(row), col=\(col)")
                    continue
                }

                print("[ExcelParser]   失败: rId=\(rId), row=\(row), col=\(col)")
                print("[ExcelParser]   imageRels keys: \(imageRels.keys)")
                print("[ExcelParser]   mediaMap keys: \(mediaMap.keys)")
            }
        }
    }

    /// 生成路径变体，用于匹配不同格式的 media 路径
    private func generatePathVariants(_ path: String) -> [String] {
        var variants: [String] = [path]
        // 添加 xl/ 前缀
        if !path.hasPrefix("xl/") {
            variants.append("xl/" + path)
        }
        // 去除 xl/ 前缀
        if path.hasPrefix("xl/") {
            variants.append(String(path.dropFirst(3)))
        }
        // 添加 / 前缀
        if !path.hasPrefix("/") {
            variants.append("/" + path)
        }
        return variants
    }

    /// 从XML字符串中提取标签值
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let openRange = xml.range(of: openTag, options: []),
              let closeRange = xml.range(of: closeTag, options: []) else { return nil }
        return String(xml[openRange.upperBound..<closeRange.lowerBound])
    }

    /// 解析相对路径，如 "../media/image1.png" 相对于 "xl/drawings/" → "xl/media/image1.png"
    private func resolveRelativePath(_ path: String, basePath: String) -> String {
        // 绝对路径（以 / 开头）
        if path.hasPrefix("/") {
            return String(path.dropFirst())
        }
        // 拼接基路径
        var components = (basePath + path).split(separator: "/").map(String.init)
        // 处理 ".." 和 "."
        var resolved: [String] = []
        for comp in components {
            if comp == ".." {
                if !resolved.isEmpty { resolved.removeLast() }
            } else if comp != "." && !comp.isEmpty {
                resolved.append(comp)
            }
        }
        return resolved.joined(separator: "/")
    }
}
