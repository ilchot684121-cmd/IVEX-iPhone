import Foundation
import UIKit

enum XLSXExporter {
    static func makeFile(stores: [StoreOrder], profile: ClientProfile, settings: AppSettings, suffix: String) -> URL? {
        guard !stores.isEmpty else { return nil }
        var entries: [(String, Data)] = []
        var media: [(name: String, data: Data)] = []
        var drawingIndex = 0

        let sheetNames = stores.enumerated().map { index, store in
            store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Магазин \(store.number)" : safeSheetName(store.name, fallback: "Магазин \(index + 1)")
        }

        for (index, store) in stores.enumerated() {
            let sheetNumber = index + 1
            var pictures: [(relationship: String, mediaName: String, title: String, anchor: String)] = []

            if let data = jpegData(store.businessCardData) {
                let mediaName = "ivex_store_\(store.number)_business_card.jpg"
                media.append((mediaName, data))
                pictures.append(("rId1", mediaName, "Business card", businessCardAnchor()))
            }

            for (productIndex, product) in store.usedProducts.prefix(97).enumerated() {
                if let data = jpegData(product.photoData) {
                    let mediaName = "ivex_store_\(store.number)_photo_\(productIndex + 1).jpg"
                    media.append((mediaName, data))
                    let relationship = "rId\(pictures.count + 1)"
                    pictures.append((relationship, mediaName, "Product \(productIndex + 1)", productAnchor(row: productIndex + 2)))
                }
            }

            let hasDrawing = !pictures.isEmpty
            var drawingID: Int?
            if hasDrawing {
                drawingIndex += 1
                drawingID = drawingIndex
                entries.append(("xl/drawings/drawing\(drawingIndex).xml", data(drawingXML(pictures))))
                entries.append(("xl/drawings/_rels/drawing\(drawingIndex).xml.rels", data(drawingRelationships(pictures))))
                entries.append(("xl/worksheets/_rels/sheet\(sheetNumber).xml.rels", data(sheetDrawingRelationship(drawingIndex))))
            }

            entries.append(("xl/worksheets/sheet\(sheetNumber).xml", data(storeSheetXML(
                store: store,
                profile: profile,
                settings: settings,
                hasDrawing: hasDrawing
            ))))
        }

        let summarySheetNumber = stores.count + 1
        entries.append(("xl/worksheets/sheet\(summarySheetNumber).xml", data(summaryXML(stores: stores, sheetNames: sheetNames, settings: settings))))
        entries.append(("xl/workbook.xml", data(workbookXML(sheetNames: sheetNames))))
        entries.append(("xl/_rels/workbook.xml.rels", data(workbookRelationships(sheetCount: summarySheetNumber))))
        entries.append(("xl/styles.xml", data(stylesXML)))
        entries.append(("_rels/.rels", data(rootRelationships)))
        entries.append(("[Content_Types].xml", data(contentTypes(sheetCount: summarySheetNumber, drawingCount: drawingIndex))))
        for item in media { entries.append(("xl/media/\(item.name)", item.data)) }

        let filename = "IVEX07_\(suffix)_\(timestamp()).xlsx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try StoredZIP.write(entries: entries, to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func storeSheetXML(store: StoreOrder, profile: ClientProfile, settings: AppSettings, hasDrawing: Bool) -> String {
        let products = Array(store.usedProducts.prefix(97))
        let lastProductRow = max(3, products.count + 2)
        let totalRow = products.isEmpty ? 4 : lastProductRow + 2
        let date = displayDate()
        var rows = """
        <row r="1" ht="84.75" customHeight="1"><c r="A1" s="2" t="inlineStr"><is><t>\(store.businessCardData == nil ? "ВИЗИТКА" : "")</t></is></c><c r="K1" s="3" t="inlineStr"><is><t>Order No.</t></is></c><c r="L1" s="3" t="inlineStr"><is><t>\(xml(store.orderNumber))</t></is></c><c r="M1" s="3" t="inlineStr"><is><t>Дата</t></is></c><c r="N1" s="3" t="inlineStr"><is><t>\(date)</t></is></c><c r="O1" s="3" t="inlineStr"><is><t>Status</t></is></c></row>
        <row r="2" ht="20"><c r="A2" s="3" t="inlineStr"><is><t>Description</t></is></c><c r="B2" s="4" t="inlineStr"><is><t>Price RMB</t></is></c><c r="C2" s="3" t="inlineStr"><is><t>Cartons</t></is></c><c r="D2" s="5" t="inlineStr"><is><t>Pcs/Carton</t></is></c><c r="E2" s="3" t="inlineStr"><is><t>Total</t></is></c><c r="F2" s="5" t="inlineStr"><is><t>Total price</t></is></c><c r="G2" s="3" t="inlineStr"><is><t>CBM</t></is></c><c r="H2" s="3" t="inlineStr"><is><t>Total CBM</t></is></c><c r="I2" s="3" t="inlineStr"><is><t>Photo</t></is></c><c r="J2" s="1" t="inlineStr"><is><t>Price EUR</t></is></c><c r="K2" s="3" t="inlineStr"><is><t>Store</t></is></c><c r="L2" s="3" t="inlineStr"><is><t>\(xml(store.name))</t></is></c><c r="M2" s="3" t="inlineStr"><is><t>Customer</t></is></c><c r="N2" s="3" t="inlineStr"><is><t>\(xml(profile.name))</t></is></c><c r="O2" s="3" t="inlineStr"><is><t>\(xml(store.orderStatus.rawValue))</t></is></c><c r="P2" s="3" t="inlineStr"><is><t>Product Status</t></is></c><c r="Q2" s="3" t="inlineStr"><is><t>Status Note</t></is></c></row>
        """

        for (index, product) in products.enumerated() {
            let row = index + 3
            let eurFormula = "B\(row)/\(decimal(max(settings.eurExchangeRate, 0.0001)))*(1+\(decimal(settings.smartPriceCoefficient)))"
            rows += """
            <row r="\(row)" ht="60" customHeight="1"><c r="A\(row)" s="6" t="inlineStr"><is><t>\(xml(product.name))</t></is></c><c r="B\(row)" s="7"><v>\(decimal(product.unitPrice))</v></c><c r="C\(row)" s="6"><v>\(decimal(product.cartons))</v></c><c r="D\(row)" s="6"><v>\(decimal(product.piecesPerCarton))</v></c><c r="E\(row)" s="6"><f>C\(row)*D\(row)</f><v>\(decimal(product.totalQuantity))</v></c><c r="F\(row)" s="6"><f>B\(row)*E\(row)</f><v>\(decimal(product.totalPrice))</v></c><c r="G\(row)" s="6"><v>\(decimal(product.cbmPerCarton))</v></c><c r="H\(row)" s="6"><f>C\(row)*G\(row)</f><v>\(decimal(product.totalCBM))</v></c><c r="I\(row)" s="8" t="inlineStr"><is><t></t></is></c><c r="J\(row)" s="9"><f>\(eurFormula)</f><v>\(decimal(product.unitPrice / max(settings.eurExchangeRate, 0.0001) * (1 + settings.smartPriceCoefficient)))</v></c><c r="P\(row)" s="6" t="inlineStr"><is><t>\(xml(product.status.rawValue))</t></is></c><c r="Q\(row)" s="17" t="inlineStr"><is><t>\(xml(product.statusNote.isEmpty ? product.note : product.statusNote))</t></is></c><c r="R\(row)" s="6" t="inlineStr"><is><t>\(product.id.uuidString)</t></is></c><c r="S\(row)" s="6"><v>\(store.number)</v></c></row>
            """
        }

        let rangeEnd = products.isEmpty ? 3 : lastProductRow
        rows += """
        <row r="\(totalRow)" ht="20"><c r="A\(totalRow)" s="6" t="inlineStr"><is><t>TOTAL PRICE RMB</t></is></c><c r="B\(totalRow)" s="6"><f>SUM(F3:F\(rangeEnd))</f><v>\(decimal(store.totalPrice))</v></c></row>
        <row r="\(totalRow + 1)" ht="20"><c r="A\(totalRow + 1)" s="6" t="inlineStr"><is><t>TOTAL CBM</t></is></c><c r="B\(totalRow + 1)" s="6"><f>SUM(H3:H\(rangeEnd))</f><v>\(decimal(store.totalCBM))</v></c></row>
        <row r="\(totalRow + 2)" ht="20"><c r="A\(totalRow + 2)" s="15" t="inlineStr"><is><t>ПЛАТЕНО КАПАРО RMB</t></is></c><c r="B\(totalRow + 2)" s="15"><v>\(decimal(store.depositRmb))</v></c></row>
        <row r="\(totalRow + 3)" ht="20"><c r="A\(totalRow + 3)" s="16" t="inlineStr"><is><t>ОСТАТЪК RMB</t></is></c><c r="B\(totalRow + 3)" s="16"><f>MAX(0,B\(totalRow)-B\(totalRow + 2))</f><v>\(decimal(store.remainingRmb))</v></c></row>
        <row r="100" hidden="1"><c r="B100" s="6"><v>\(decimal(store.totalPrice))</v></c></row><row r="101" hidden="1"><c r="B101" s="6"><v>\(decimal(store.totalCBM))</v></c></row><row r="102" hidden="1"><c r="B102" s="6"><v>\(decimal(store.depositRmb))</v></c></row>
        """

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:S102"/><sheetViews><sheetView workbookViewId="0" zoomScale="94"><selection activeCell="A1" sqref="A1"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols><col min="1" max="1" customWidth="1" width="27.38"/><col min="2" max="8" customWidth="1" width="12"/><col min="9" max="9" customWidth="1" width="16.38"/><col min="10" max="10" customWidth="1" width="11.38"/><col min="11" max="14" customWidth="1" width="18"/><col min="15" max="15" customWidth="1" width="24"/><col min="16" max="16" customWidth="1" width="22"/><col min="17" max="17" customWidth="1" width="32"/><col min="18" max="19" hidden="1" width="0" customWidth="1"/></cols><sheetData>\(rows)</sheetData><dataValidations count="1"><dataValidation type="list" allowBlank="1" sqref="P3:P99"><formula1>&quot;Нова поръчка,Приета,В обработка,Поръчана,Частично готова,Готова,Изпратена,Доставена,Отказана&quot;</formula1></dataValidation></dataValidations>\(hasDrawing ? "<drawing r:id=\"rId1\"/>" : "")<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>
        """
    }

    private static func summaryXML(stores: [StoreOrder], sheetNames: [String], settings: AppSettings) -> String {
        let total = stores.reduce(0) { $0 + $1.totalPrice }
        let cbm = stores.reduce(0) { $0 + $1.totalCBM }
        let deposit = stores.reduce(0) { $0 + $1.depositRmb }
        var detail = ""
        for (index, store) in stores.enumerated() {
            let row = index + 7
            let sheet = formulaSheet(sheetNames[index])
            detail += "<row r=\"\(row)\"><c r=\"A\(row)\" s=\"6\" t=\"inlineStr\"><is><t>\(xml(store.name))</t></is></c><c r=\"B\(row)\" s=\"7\"><f>'\(sheet)'!B100</f><v>\(decimal(store.totalPrice))</v></c><c r=\"C\(row)\" s=\"6\"><f>'\(sheet)'!B101</f><v>\(decimal(store.totalCBM))</v></c><c r=\"D\(row)\" s=\"7\"><f>'\(sheet)'!B102</f><v>\(decimal(store.depositRmb))</v></c><c r=\"E\(row)\" s=\"7\"><f>MAX(0,B\(row)-D\(row))</f><v>\(decimal(store.remainingRmb))</v></c></row>"
        }
        let last = stores.count + 7
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:E\(last)"/><sheetViews><sheetView workbookViewId="0"><selection activeCell="A1" sqref="A1"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="18"/><cols><col min="1" max="1" width="28" customWidth="1"/><col min="2" max="5" width="18" customWidth="1"/></cols><sheetData><row r="1" ht="30" customHeight="1"><c r="A1" s="2" t="inlineStr"><is><t>ОБОБЩЕНИЕ / SUMMARY / 合计</t></is></c></row><row r="2"><c r="A2" s="15" t="inlineStr"><is><t>ОБЩА СУМА RMB</t></is></c><c r="B2" s="15"><v>\(decimal(total))</v></c></row><row r="3"><c r="A3" s="15" t="inlineStr"><is><t>ОБЩА СУМА EUR</t></is></c><c r="B3" s="15"><f>B2/\(decimal(max(settings.eurExchangeRate, 0.0001)))</f><v>\(decimal(total / max(settings.eurExchangeRate, 0.0001)))</v></c></row><row r="4"><c r="A4" s="16" t="inlineStr"><is><t>ОБЩО CBM</t></is></c><c r="B4" s="16"><v>\(decimal(cbm))</v></c></row><row r="5"><c r="A5" s="15" t="inlineStr"><is><t>ОБЩО ПЛАТЕНО КАПАРО RMB</t></is></c><c r="B5" s="15"><v>\(decimal(deposit))</v></c></row><row r="6"><c r="A6" s="3" t="inlineStr"><is><t>МАГАЗИН</t></is></c><c r="B6" s="3" t="inlineStr"><is><t>СУМА RMB</t></is></c><c r="C6" s="3" t="inlineStr"><is><t>CBM</t></is></c><c r="D6" s="3" t="inlineStr"><is><t>КАПАРО RMB</t></is></c><c r="E6" s="3" t="inlineStr"><is><t>ОСТАТЪК RMB</t></is></c></row>\(detail)<row r="\(last)" ht="30"><c r="A\(last)" s="16" t="inlineStr"><is><t>ОБЩА КУБАТУРА / TOTAL VOLUME</t></is></c><c r="B\(last)" s="16"><v>\(decimal(cbm))</v></c><c r="C\(last)" s="16" t="inlineStr"><is><t>CBM / м³</t></is></c></row></sheetData><mergeCells count="1"><mergeCell ref="A1:E1"/></mergeCells><pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>
        """
    }

    private static func workbookXML(sheetNames: [String]) -> String {
        let all = sheetNames + ["Обобщение"]
        let sheets = all.enumerated().map { "<sheet name=\"\(xml($0.element))\" sheetId=\"\($0.offset + 1)\" r:id=\"rId\($0.offset + 1)\"/>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><workbook xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><bookViews><workbookView/></bookViews><sheets>\(sheets)</sheets><calcPr calcId=\"191029\" fullCalcOnLoad=\"1\" forceFullCalc=\"1\"/></workbook>"
    }

    private static func workbookRelationships(sheetCount: Int) -> String {
        var rels = (1...sheetCount).map { "<Relationship Id=\"rId\($0)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\($0).xml\"/>" }.joined()
        rels += "<Relationship Id=\"rId\(sheetCount + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(rels)</Relationships>"
    }

    private static func contentTypes(sheetCount: Int, drawingCount: Int) -> String {
        let sheets = (1...sheetCount).map { "<Override PartName=\"/xl/worksheets/sheet\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined()
        let drawings = drawingCount > 0 ? (1...drawingCount).map { "<Override PartName=\"/xl/drawings/drawing\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"/>" }.joined() : ""
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"jpg\" ContentType=\"image/jpeg\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>\(sheets)\(drawings)</Types>"
    }

    private static func drawingXML(_ pictures: [(relationship: String, mediaName: String, title: String, anchor: String)]) -> String {
        let items = pictures.enumerated().map { index, picture in
            "\(picture.anchor)<xdr:pic><xdr:nvPicPr><xdr:cNvPr id=\"\(index + 1)\" name=\"\(xml(picture.title))\"/><xdr:cNvPicPr/></xdr:nvPicPr><xdr:blipFill><a:blip r:embed=\"\(picture.relationship)\"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/>\(picture.anchor.contains("oneCellAnchor") ? "</xdr:oneCellAnchor>" : "</xdr:twoCellAnchor>")"
        }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\(items)</xdr:wsDr>"
    }

    private static func drawingRelationships(_ pictures: [(relationship: String, mediaName: String, title: String, anchor: String)]) -> String {
        let rels = pictures.map { "<Relationship Id=\"\($0.relationship)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/\($0.mediaName)\"/>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(rels)</Relationships>"
    }

    private static func sheetDrawingRelationship(_ drawingIndex: Int) -> String { "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing\" Target=\"../drawings/drawing\(drawingIndex).xml\"/></Relationships>" }
    private static func businessCardAnchor() -> String { "<xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>60000</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>60000</xdr:rowOff></xdr:from><xdr:ext cx=\"1750000\" cy=\"950000\"/>" }
    private static func productAnchor(row: Int) -> String { "<xdr:twoCellAnchor editAs=\"oneCell\"><xdr:from><xdr:col>8</xdr:col><xdr:colOff>50000</xdr:colOff><xdr:row>\(row)</xdr:row><xdr:rowOff>50000</xdr:rowOff></xdr:from><xdr:to><xdr:col>9</xdr:col><xdr:colOff>-50000</xdr:colOff><xdr:row>\(row + 1)</xdr:row><xdr:rowOff>-50000</xdr:rowOff></xdr:to>" }

    private static func jpegData(_ source: Data?) -> Data? {
        guard let source, let image = UIImage(data: source) else { return nil }
        return image.jpegData(compressionQuality: 0.82)
    }
    private static func safeSheetName(_ value: String, fallback: String) -> String {
        let cleaned = value.components(separatedBy: CharacterSet(charactersIn: "[]:*?/\\")).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? fallback : cleaned).prefix(31))
    }
    private static func formulaSheet(_ value: String) -> String { value.replacingOccurrences(of: "'", with: "''") }
    private static func xml(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;") }
    private static func decimal(_ value: Double) -> String { String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), value) }
    private static func data(_ value: String) -> Data { Data(value.utf8) }
    private static func timestamp() -> String { let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmm"; return f.string(from: Date()) }
    private static func displayDate() -> String { let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy HH:mm"; return f.string(from: Date()) }

    private static let rootRelationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="¥#,##0.00"/><numFmt numFmtId="169" formatCode="#,##0.00 [$€-407]"/></numFmts><fonts count="4"><font><name val="Calibri"/><sz val="11"/></font><font><name val="Calibri"/><sz val="26"/><b/></font><font><name val="Calibri"/><sz val="11"/><b/></font><font><name val="Calibri"/><sz val="11"/><color rgb="FFFC4700"/></font></fonts><fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFCCFF66"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFF0000"/></patternFill></fill></fills><borders count="4"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="medium"/><right style="medium"/><top style="medium"/><bottom style="medium"/></border><border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/></border><border><left style="thin"/><right/><top style="thin"/><bottom style="thin"/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="18"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="169" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"><alignment horizontal="center"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="2" xfId="0"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="164" fontId="3" fillId="0" borderId="2" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="3" xfId="0"/><xf numFmtId="169" fontId="3" fillId="0" borderId="2" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="169" fontId="3" fillId="0" borderId="2" xfId="0"/><xf numFmtId="169" fontId="3" fillId="0" borderId="2" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="169" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="2" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="3" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="2" xfId="0"><alignment wrapText="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
    """
}

private enum StoredZIP {
    static func write(entries: [(String, Data)], to url: URL) throws {
        var archive = Data()
        var central = Data()
        for (name, payload) in entries {
            let nameData = Data(name.utf8)
            let crc = CRC32.checksum(payload)
            let offset = UInt32(archive.count)
            archive.appendLE(UInt32(0x04034b50)); archive.appendLE(UInt16(20)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(crc); archive.appendLE(UInt32(payload.count)); archive.appendLE(UInt32(payload.count)); archive.appendLE(UInt16(nameData.count)); archive.appendLE(UInt16(0)); archive.append(nameData); archive.append(payload)
            central.appendLE(UInt32(0x02014b50)); central.appendLE(UInt16(20)); central.appendLE(UInt16(20)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(crc); central.appendLE(UInt32(payload.count)); central.appendLE(UInt32(payload.count)); central.appendLE(UInt16(nameData.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset); central.append(nameData)
        }
        let centralOffset = UInt32(archive.count)
        archive.append(central)
        archive.appendLE(UInt32(0x06054b50)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(entries.count)); archive.appendLE(UInt16(entries.count)); archive.appendLE(UInt32(central.count)); archive.appendLE(centralOffset); archive.appendLE(UInt16(0))
        try archive.write(to: url, options: .atomic)
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data { var x = (crc ^ UInt32(byte)) & 0xff; for _ in 0..<8 { x = (x & 1) == 1 ? (x >> 1) ^ 0xedb88320 : x >> 1 }; crc = (crc >> 8) ^ x }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) } }
}
