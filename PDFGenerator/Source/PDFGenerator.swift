//
//  BasePDFGenerator.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 28/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//
import UIKit

public enum PDFDocumentInfo {
    case documentName
    case creatorName
    case subject
}

public func points(fromMm value: Float) -> Float {
    return (value / 25.4) * 72
}

/// Page sizes which can be set. Avaiable standard sizes:
///
/// - A5
/// - A4
/// - US Letter
public enum PDFPageSize {
    case a4
    case a5
    case letter

    fileprivate var size: (Float, Float) {
        switch self {
        case .a4: return (points(fromMm: 210), points(fromMm: 297))
        case .a5: return (points(fromMm: 148), points(fromMm: 210))
        case .letter: return (points(fromMm: 216), points(fromMm: 279))
        }
    }
}

public enum PDFPageOrientation {
    case portrait
    case landscape
}

let documentTitleFontSize: Float = 12.0

private struct PreparedCell {
    let cellWidth: Float
    let cellType: PreparedCellType
    let cellAttributes: [PDFTableCellAttribute]?
}

private enum PreparedCellType {
    case empty
    case textCell(text: NSAttributedString)
    case imageCell(image: UIImage)
    case customCell((_ frame: CGRect) -> ())
}

private let DRAW_STRING_RECT = false

public class PDFGenerator: NSObject {

    public let tableCellPadding: Float = 2.0
    public let tableHeaderHeight: Float = 15.0

    public var pageTitle: String?

    /// Default 9 pt
    public var defaultTextFontSize: Float = 9.0

    /// Default 25 mm
    public var pageLeftMargin   = points(fromMm: 25)
    /// Default 10 mm
    public var pageTopMargin    = points(fromMm: 10)
    /// Default 10 mm
    public var pageRightMargin  = points(fromMm: 10)
    /// Default 10 mm
    public var pageBottomMargin = points(fromMm: 10)

    /// Default 0.2mm
    public var defaultTableFrameWidth = points(fromMm: 0.2)

    /// 5 mm
    public let minSpaceBetweenBlocks = points(fromMm: 5)

    /// Default Helvetica Neue
    public var defaultFontName = "HelveticaNeue"
    public var defaultBoldFontName: String {
        return "\(defaultFontName)-Bold"
    }
    public var defaultItalicFontName: String {
        return "\(defaultFontName)-Italic"
    }

    /// Default page size is A4 in portrait (width - 210mm, height - 297mm).
    ///
    /// To set standard page size use setPageFormat(PDFPageSize, PDFPageOrientation)
    public var pageWidth  = points(fromMm: 210)
    /// Default page size is A4 in portrait (width - 210mm, height - 297mm).
    ///
    /// To set standard page size use setPageFormat(PDFPageSize, PDFPageOrientation)
    public var pageHeight = points(fromMm: 297)

    public var contentMaxWidth: Float {
        return pageWidth - pageLeftMargin - pageRightMargin
    }
    public var tableWidth: Float {
        return contentMaxWidth
    }

    /// Contain value only for columns with no width specified.
    ///
    /// Column property code as a key.
    private var columnsWidth = [String: Float]()

    private let outputFilePath: String
    private var pdfContextInfo = [String: String]()
    private(set) public var y: Float = 0.0

    public init(outputFilePath: String) {
        self.outputFilePath = outputFilePath

        super.init()
    }

    /// Adds document info to PDF document metadata. Supported:
    ///  - DocumentName
    ///  - CreatorName
    ///  - Subject
    public func addDocumentInfo(_ param: PDFDocumentInfo, value: String) {
        var paramName: String
        switch param {
        case .documentName: paramName = String(kCGPDFContextTitle)
        case .creatorName: paramName = String(kCGPDFContextCreator)
        case .subject: paramName = String(kCGPDFContextSubject)
        }
        self.pdfContextInfo[paramName] = value
    }

    /// Sets size for page. Avaiable standard sizes:
    ///  - A5
    ///  - A4
    ///  - US Letter
    public func setPageFormat(_ format: PDFPageSize, orientation: PDFPageOrientation) {
        let (width, height) = format.size
        switch orientation {
        case .portrait: pageWidth = width; pageHeight = height
        case .landscape: pageWidth = height; pageHeight = width
        }
    }

    /// Should be overridden by subclass.
    ///
    /// DON'T FORGET TO CALL SUPERCLASS METHOD!
    public func generate() {
        columnsWidth.removeAll(keepingCapacity: true) // Clear column width cache

        let pageBounds = CGRect(x: 0, y: 0, width: CGFloat(pageWidth), height: CGFloat(pageHeight))
        UIGraphicsBeginPDFContextToFile(outputFilePath, pageBounds, pdfContextInfo)
        startNewPage()
    }

    /// Should be called in the end of the generate() method
    public func finish() {
        // Close the PDF context and write the contents out.
        UIGraphicsEndPDFContext()
    }

    /// Adds vertical space before next element on page
    /// Always call this method after you've drawn something in your subclass
    ///
    /// - parameter space: Vertical space before next element
    public func addY(_ space: Float) {
        if !startNewPageIfNeeded(space) {
            y += space
        }
    }

    private func startNewPageIfNeeded(_ rowHeight: Float) -> Bool {
        if rowHeight > (pageHeight - pageBottomMargin - y) {
            startNewPage()
            return true
        }
        return false
    }

    private func startNewPage() {
        y = pageTopMargin
        UIGraphicsBeginPDFPage()
    }

    /// Draws page title if set
    public func drawPageTitle() {
        if let title = pageTitle {
            drawPageTitle(title)
        }
    }

    func drawPageTitle(_ title: String) {
        let attributedTitle = NSAttributedString(string: title, attributes: attributesForPageTitle())

        var rect = attributedTitle.boundingRect(with: CGSize(width: CGFloat(contentMaxWidth), height: CGFloat(pageHeight)), options: .usesLineFragmentOrigin, context: nil)
        rect = CGRect(x: CGFloat(pageLeftMargin), y: CGFloat(y), width: CGFloat(contentMaxWidth), height: ceil(rect.size.height))

        drawString(attributedTitle, inFrame: rect)

        self.y += Float(rect.size.height)
        self.y += minSpaceBetweenBlocks
    }

    /// Draws table
    ///
    /// - parameter table: Table to draw
    public func drawTable(_ table: PDFTable) {
        self.drawTableHeader(table)

        for section in 0..<table.sectionsNumber {
            if let sectionTitle = table.titleForHeaderInSection(section) {
                self.drawTableSectionHeader(sectionTitle)
            }
            for rowNum in 0..<table.numberOfRowsInSection(section) {
                let row = table.rowAtIndex(row: rowNum, section: section)
                if row.rowCells.count == 0 {
                    NSLog("Row cells count for row \(rowNum) should not be 0!")
                } else {
                    let lastRowOfTable = (section == table.sectionsNumber - 1 && rowNum == table.numberOfRowsInSection(section) - 1)
                    self.drawRow(row, inTable: table, linkWithNextBlockOfHeight: lastRowOfTable ? table.linkWithNextBlockOfHeight : nil)
                }
            }
        }
    }

    private func drawTableHeader(_ table: PDFTable) {
        var currentX = pageLeftMargin
        let currentY = self.y
        let rowHeight = tableHeaderHeight
        for column in table.columns {
            let columnWidth = width(for: column, allColumns: table.columns) + defaultTableFrameWidth
            let frame = CGRect(x: CGFloat(currentX), y: CGFloat(currentY), width: CGFloat(columnWidth), height: CGFloat(rowHeight))

            drawFrame(frame)

            let textFrame = frame.insetBy(dx: CGFloat(tableCellPadding), dy: CGFloat(tableCellPadding))
            let text = NSAttributedString(string: column.columnTitle, attributes: attributesForTableColumnHeader())
            drawString(text, inFrame: textFrame)

            currentX += columnWidth - defaultTableFrameWidth
        }

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func drawTableSectionHeader(_ sectionTitle: String) {
        let currentX = CGFloat(pageLeftMargin)
        let currentY = CGFloat(y)
        let columnWidth = tableWidth + defaultTableFrameWidth

        let text = NSMutableAttributedString(string: sectionTitle, attributes: attributesForTableSectionHeader())
        let maxTextRect = CGSize(width: CGFloat(columnWidth - tableCellPadding * 2), height: CGFloat.greatestFiniteMagnitude)
        let textBounds = text.boundingRect(with: maxTextRect, options: NSStringDrawingOptions.usesFontLeading, context: nil)

        let rowHeight = Float(textBounds.size.height) + tableCellPadding * 2

        let cellFrame = CGRect(x: currentX, y: currentY, width: CGFloat(columnWidth), height: CGFloat(rowHeight))
        drawFrame(cellFrame)

        let contentFrame = cellFrame.insetBy(dx: CGFloat(tableCellPadding), dy: CGFloat(tableCellPadding))
        drawString(text, inFrame: contentFrame)

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func drawRow(_ row: PDFTableRow, inTable table: PDFTable, linkWithNextBlockOfHeight: Float?) {
        var currentY = self.y
        var rowHeight: Float = 0.0

        var preparedCells = [PreparedCell]()

        var columnsCountToSkip = 0
        var cellType: PreparedCellType = .empty
        var cellAttributes: [PDFTableCellAttribute]?
        var columnWidth: Float = 0
        for columnIndex in 0..<row.rowCells.count {
            let column = table.columns[columnIndex]
            // Add cell frame width so that this column right frame is overlaps the left frame of next frame
            columnWidth += width(for: column, allColumns: table.columns) + (columnWidth > 0 ? 0 : defaultTableFrameWidth)
            var cellShouldBeMerged = false
            if columnsCountToSkip > 0 { // If the last one left — draw it
                columnsCountToSkip -= 1
                if columnsCountToSkip > 0 {
                    continue
                }
                cellShouldBeMerged = true
            }

            if !cellShouldBeMerged {
                switch row.rowCells[columnIndex] {
                case let .emptyCell(cellAttr):
                    cellAttributes = cellAttr
                    cellType = .empty
                case let .textCell(cellText, textAttributes, cellAttr):
                    cellAttributes = cellAttr
                    let text = attributedString(cellText, columnAttributes: column.textAttributes, cellAttributes: textAttributes)
                    cellType = .textCell(text: text)

                    let maxTextRect = CGSize(width: CGFloat(columnWidth - tableCellPadding * 2), height: CGFloat.greatestFiniteMagnitude)
                    let textBounds = text.boundingRect(with: maxTextRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    let newRowHeight = ceil(Float(textBounds.size.height) + tableCellPadding * 2)
                    if newRowHeight > rowHeight {
                        rowHeight = newRowHeight
                    }
                case let .imageCell(image, cellAttr):
                    cellAttributes = cellAttr
                    cellType = .imageCell(image: image)
                    let scale = (columnWidth - tableCellPadding * 2) / Float(image.size.width)

                    let newRowHeight = ceil(Float(image.size.height) * scale) + tableCellPadding * 2
                    if newRowHeight > rowHeight {
                        rowHeight = newRowHeight
                    }
                case let .customCell(drawingBlock, cellAttr):
                    cellAttributes = cellAttr
                    cellType = .customCell(drawingBlock)
                }
                if let columnsNum = cellAttributesContainCellsMerge(cellAttributes) {
                    columnsCountToSkip = columnsNum - 1
                    continue
                }
            }
            preparedCells.append(PreparedCell(cellWidth: columnWidth, cellType: cellType, cellAttributes: cellAttributes))
            columnWidth = 0
        }
        var heightWithLinkedRow = rowHeight
        if let linkedRowHeight = linkWithNextBlockOfHeight {
            heightWithLinkedRow += linkedRowHeight
        }
        if startNewPageIfNeeded(heightWithLinkedRow) {
            self.drawTableHeader(table)
            currentY = self.y
        }

        var currentX = pageLeftMargin
        for theCell in preparedCells {
            let cellFrame = CGRect(x: CGFloat(currentX), y: CGFloat(currentY), width: CGFloat(theCell.cellWidth), height: CGFloat(rowHeight))

            drawFrame(cellFrame, cellAttributes: theCell.cellAttributes)

            switch theCell.cellType {
            case .empty: // We've already drawn cell frame
                break
            case let .textCell(text):
                let contentFrame = cellFrame.insetBy(dx: CGFloat(tableCellPadding), dy: CGFloat(tableCellPadding))
                drawString(text, inFrame: contentFrame)
            case let .imageCell(image):
                let contentFrame = cellFrame.insetBy(dx: CGFloat(tableCellPadding), dy: CGFloat(tableCellPadding))
                drawImage(image, inFrame: contentFrame)
                break
            case let .customCell(drawingBlock):
                drawingBlock(cellFrame)
            }

            currentX += theCell.cellWidth - defaultTableFrameWidth
        }

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func width(for column: PDFTableColumn, allColumns: [PDFTableColumn]) -> Float {
        var columnWidth = column.columnWidth
        if columnWidth <= 0 {
            if let width = self.columnsWidth[column.propertyName] {
                columnWidth = width
            }
        }
        if columnWidth <= 0 {
            columnWidth = tableWidth
            var columnsWithoutWidthCount: Float = 0
            for column in allColumns {
                if column.columnWidth > 0 {
                    columnWidth -= column.columnWidth
                } else {
                    columnsWithoutWidthCount += 1
                }
            }
            if columnsWithoutWidthCount > 1 {
                columnWidth /= columnsWithoutWidthCount
            }
            NSLog("Column width for \(column.propertyName) is \(columnWidth)")
            self.columnsWidth[column.propertyName] = columnWidth
        }

        return columnWidth
    }

    private func attributesForPageTitle() -> [String: AnyObject] {
        let font = UIFont(name: defaultFontName, size: CGFloat(documentTitleFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle

        let attributes: [String: AnyObject] = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributesForTableSectionHeader() -> [String: AnyObject] {
        let font = UIFont(name: defaultFontName, size: CGFloat(defaultTextFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle

        let attributes: [String: AnyObject] = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributesForTableColumnHeader() -> [String: AnyObject] {
        let font = UIFont(name: defaultBoldFontName, size: CGFloat(defaultTextFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle

        let attributes: [String: AnyObject] = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributedString(_ text: String, columnAttributes: [PDFTableTextAttribute], cellAttributes: [PDFTableTextAttribute]?) -> NSAttributedString {
        var attributes = columnAttributes
        if let other = cellAttributes {
            attributes.append(contentsOf: other)
        }

        let fontName = defaultFontName
        let fontSize = defaultTextFontSize
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle

        let attributedString = NSMutableAttributedString(string: text, attributes: [NSFontAttributeName: UIFont(name: fontName, size: CGFloat(fontSize))!])

        for attribute in attributes {
            switch attribute {
            case let .alignment(value):
                paragraph.alignment = value
                attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraph, range: NSMakeRange(0, text.characters.count))
            case let .fontSizeAbsolute(value, range):
                let font = UIFont(name: fontName, size: CGFloat(value))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .fontSizeRelative(value, range):
                let font = UIFont(name: fontName, size: CGFloat(fontSize * value))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .fontWeight(value, range):
                var fontName = ""
                switch value {
                case .normal: fontName = defaultFontName
                case .italic: fontName = defaultItalicFontName
                case .bold: fontName = defaultBoldFontName
                }
                let font = UIFont(name: fontName, size: CGFloat(fontSize))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            }
        }

        return NSAttributedString(attributedString: attributedString)
    }

    private func cellAttributesContainCellsMerge(_ attributes: [PDFTableCellAttribute]?) -> Int? {
        if let cellAttributes = attributes {
            for attribute in cellAttributes {
                switch attribute {
                case let .mergedColumns(value):
                    return value
                default:
                    continue
                }
            }
        }
        return nil
    }

    /// Low level method which draws frame according to rect with cell attributes
    ///
    /// - parameter rect: Position and size of the frame
    /// - parameter cellAttributes: Attributes of cell frame and filling
    func drawFrame(_ rect: CGRect, cellAttributes: [PDFTableCellAttribute]? = nil) {
        var lineWidth: Float? = defaultTableFrameWidth
        var lineColor: UIColor = .black
        var fillColor: UIColor?

        if let cellAttributes = cellAttributes {
            for attribute in cellAttributes {
                switch attribute {
                case let .frameWidth(widthValue):
                    switch widthValue {
                    case .noWidth: lineWidth = nil
                    case let .fixed(value): lineWidth = value
                    }
                case let .frameColor(color):
                    lineColor = color
                case let .fillColor(color):
                    fillColor = color
                case .mergedColumns(_):
                    break
                }
            }
        }

        guard let currentContext = UIGraphicsGetCurrentContext() else {
            return
        }
        if let fillColor = fillColor {
            fillColor.setFill()
            UIRectFill(rect)
        }
        if let lineWidth = lineWidth {
            currentContext.setLineWidth(CGFloat(lineWidth))
            lineColor.setStroke()
            UIRectFrame(rect)
        }
    }

    /// Low level method which draws string inside the frame
    ///
    /// - parameter string: Attributed string to draw
    /// - parameter rect: Frame which restricts the text on page
    public func drawString(_ string: NSAttributedString, inFrame rect: CGRect) {
        guard string.length > 0 else {
            return
        }

        if DRAW_STRING_RECT {
            let context = UIGraphicsGetCurrentContext()!

            UIColor.magenta.setStroke()
            context.setLineWidth(0.4)
            UIRectFrame(rect)
            UIColor.black.setStroke()
        }

        UIColor.black.setFill()

        string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    /// Low level method which draws image inside the frame.
    /// The method does not change aspect ratio.
    ///
    /// - parameter image: UIImage to draw
    /// - parameter rect: Frame which restricts the image on page
    public func drawImage(_ image: UIImage, inFrame rect: CGRect) {
        let scale = rect.size.width / image.size.width
        let width = image.size.width * scale
        let height = image.size.height * scale

        image.draw(in: CGRect(origin: rect.origin, size: CGSize(width: width, height: height)))
    }
}
