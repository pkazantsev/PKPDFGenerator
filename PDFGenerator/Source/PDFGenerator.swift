//
//  BasePDFGenerator.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 28/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//
import UIKit

public enum PDFDocumentInfo {
    case DocumentName
    case CreatorName
    case Subject
}

public func pointsFromMm(value: Float) -> Float {
    return (value / 25.4) * 72
}

/// Page sizes which can be set. Avaiable standard sizes:
///
/// - A5
/// - A4
/// - US Letter
public enum PDFPageSize {
    case A4
    case A5
    case Letter
}

public enum PDFPageOrientation {
    case Portrait
    case Landscape
}

let documentTitleFontSize: Float = 12.0

private struct PreparedCell {
    let cellWidth: Float
    let cellType: PreparedCellType
    let cellAttributes: Array<PDFTableCellAttribute>?
}

private enum PreparedCellType {
    case Empty
    case TextCell(text: NSAttributedString)
    case ImageCell(image: UIImage)
    case CustomCell((frame: CGRect) -> ())
}

private let DRAW_STRING_RECT = false

public class PDFGenerator: NSObject {

    public let tableCellPadding: Float = 2.0
    public let tableHeaderHeight: Float = 15.0

    public var pageTitle: String?

    /// Default 9 pt
    public var defaultTextFontSize: Float = 9.0

    /// Default 25 mm
    public var pageLeftMargin   = pointsFromMm(25)
    /// Default 10 mm
    public var pageTopMargin    = pointsFromMm(10)
    /// Default 10 mm
    public var pageRightMargin  = pointsFromMm(10)
    /// Default 10 mm
    public var pageBottomMargin = pointsFromMm(10)

    /// Default 0.2mm
    public var defaultTableFrameWidth = pointsFromMm(0.2)

    /// 5 mm
    public let minSpaceBetweenBlocks = pointsFromMm(5)

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
    public var pageWidth  = pointsFromMm(210)
    /// Default page size is A4 in portrait (width - 210mm, height - 297mm).
    ///
    /// To set standard page size use setPageFormat(PDFPageSize, PDFPageOrientation)
    public var pageHeight = pointsFromMm(297)

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
    private var pdfContextInfo = Dictionary<String, String>()
    private(set) public var y: Float = 0.0

    public init(outputFilePath: String) {
        self.outputFilePath = outputFilePath

        super.init()
    }

    /// Adds document info to PDF document metadata. Supported:
    ///  - DocumentName
    ///  - CreatorName
    ///  - Subject
    public func addDocumentInfo(param: PDFDocumentInfo, value: String) {
        var paramName: String
        switch param {
        case .DocumentName: paramName = String(kCGPDFContextTitle)
        case .CreatorName: paramName = String(kCGPDFContextCreator)
        case .Subject: paramName = String(kCGPDFContextSubject)
        }
        self.pdfContextInfo[paramName] = value
    }

    /// Sets size for page. Avaiable standard sizes:
    ///  - A5
    ///  - A4
    ///  - US Letter
    public func setPageFormat(size: PDFPageSize, orientation: PDFPageOrientation) {
        var width: Float
        var height: Float
        switch size {
        case .A4:
            width = pointsFromMm(210)
            height = pointsFromMm(297)
        case .A5:
            width = pointsFromMm(148)
            height = pointsFromMm(210)
        case .Letter:
            width = pointsFromMm(216)
            height = pointsFromMm(279)
        }

        switch orientation {
        case .Portrait: self.pageWidth = width; self.pageHeight = height
        case .Landscape: self.pageWidth = height; self.pageHeight = width
        }
    }

    /// Should be overridden by subclass.
    ///
    /// DON'T FORGET TO CALL SUPERCLASS METHOD!
    public func generate() {
        let pageBounds = CGRectMake(0, 0, CGFloat(pageWidth), CGFloat(pageHeight))
        UIGraphicsBeginPDFContextToFile(self.outputFilePath, pageBounds, self.pdfContextInfo)
        self.startNewPage()
    }

    /// Should be called in the end of the generate() method
    public func finish() {
        // Close the PDF context and write the contents out.
        UIGraphicsEndPDFContext()
    }

    /// Adds vertical space before next element on page
    /// Always call this method after you've drawn something in your subclass
    ///
    /// :param: space Vertical space before next element
    public func addY(space: Float) {
        if (!self.startNewPageIfNeeded(space)) {
            self.y += space
        }
    }

    private func startNewPageIfNeeded(rowHeight: Float) -> Bool {
        if (rowHeight > (pageHeight - pageBottomMargin - self.y)) {
            self.startNewPage()
            return true
        }
        return false
    }

    private func startNewPage() {
        self.y = pageTopMargin
        UIGraphicsBeginPDFPage()
    }

    /// Draws page title if set
    public func drawPageTitle() {
        if let title = self.pageTitle {
            drawPageTitle(title)
        }
    }

    func drawPageTitle(title: String) {
        let attributedTitle = NSAttributedString(string: title, attributes: self.attributesForPageTitle())

        var rect = attributedTitle.boundingRectWithSize(CGSizeMake(CGFloat(contentMaxWidth), CGFloat(pageHeight)), options: .UsesLineFragmentOrigin, context: nil)
        rect = CGRectMake(CGFloat(pageLeftMargin), CGFloat(self.y), CGFloat(contentMaxWidth), ceil(rect.size.height))

        drawString(attributedTitle, inFrame: rect)

        self.y += Float(rect.size.height)
        self.y += minSpaceBetweenBlocks
    }

    /// Draws table
    ///
    /// :param: table Table to draw
    public func drawTable(table: PDFTable) {
        self.drawTableHeader(table)

        for section in 0..<table.sectionsNumber {
            if let sectionTitle = table.titleForHeaderInSection(section) {
                self.drawTableSectionHeader(sectionTitle)
            }
            for rowNum in 0..<table.numberOfRowsInSection(section) {
                let row = table.rowAtIndex(rowNum, section: section)
                if row.rowCells.count == 0 {
                    NSLog("Row cells count for row \(rowNum) should not be 0!")
                } else {
                    let lastRowOfTable = (section == table.sectionsNumber - 1 && rowNum == table.numberOfRowsInSection(section) - 1)
                    self.drawRow(row, inTable: table, linkWithNextBlockOfHeight: lastRowOfTable ? table.linkWithNextBlockOfHeight : nil)
                }
            }
        }
    }

    private func drawTableHeader(table: PDFTable) {
        var currentX = pageLeftMargin
        var currentY = self.y
        var rowHeight = tableHeaderHeight
        for column in table.columns {
            var columnWidth = self.widthForColumn(column, allColumns: table.columns) + defaultTableFrameWidth
            let frame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(columnWidth), CGFloat(rowHeight))

            drawFrame(frame)

            let textFrame = CGRectInset(frame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
            let text = NSAttributedString(string: column.columnTitle, attributes: attributesForTableColumnHeader())
            drawString(text, inFrame: textFrame)

            currentX += columnWidth - defaultTableFrameWidth
        }

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func drawTableSectionHeader(sectionTitle: String) {
        var currentX = CGFloat(pageLeftMargin)
        var currentY = CGFloat(self.y)
        var columnWidth = tableWidth + defaultTableFrameWidth

        let text = NSMutableAttributedString(string: sectionTitle, attributes: attributesForTableSectionHeader())
        let maxTextRect = CGSizeMake(CGFloat(columnWidth - tableCellPadding * 2), CGFloat.max)
        let textBounds = text.boundingRectWithSize(maxTextRect, options: NSStringDrawingOptions.UsesFontLeading, context: nil)

        let rowHeight = Float(textBounds.size.height) + tableCellPadding * 2

        let cellFrame = CGRectMake(currentX, currentY, CGFloat(columnWidth), CGFloat(rowHeight))
        drawFrame(cellFrame)

        let contentFrame = CGRectInset(cellFrame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
        drawString(text, inFrame: contentFrame)

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func drawRow(row: PDFTableRow, inTable table: PDFTable, linkWithNextBlockOfHeight: Float?) {
        var currentY = self.y
        var rowHeight: Float = 0.0

        var preparedCells = Array<PreparedCell>()

        var columnsCountToSkip = 0
        var cellType: PreparedCellType = .Empty
        var cellAttributes: [PDFTableCellAttribute]?
        var columnWidth: Float = 0
        for columnIndex in 0..<row.rowCells.count {
            let column = table.columns[columnIndex]
            // Add cell frame width so that this column right frame is overlaps the left frame of next frame
            columnWidth += self.widthForColumn(column, allColumns: table.columns) + (columnWidth > 0 ? 0 : defaultTableFrameWidth)
            var cellShouldBeMerged = false
            if columnsCountToSkip > 0 { // If the last one left — draw it
                columnsCountToSkip--
                if columnsCountToSkip > 0 {
                    continue
                }
                cellShouldBeMerged = true
            }

            if !cellShouldBeMerged {
                switch row.rowCells[columnIndex] {
                case let .EmptyCell(cellAttr):
                    cellAttributes = cellAttr
                    cellType = .Empty
                case let .TextCell(cellText, textAttributes, cellAttr):
                    cellAttributes = cellAttr
                    let text = self.attributedStringWithText(cellText, columnAttributes: column.textAttributes, cellAttributes: textAttributes)
                    cellType = .TextCell(text: text)

                    let maxTextRect = CGSizeMake(CGFloat(columnWidth - tableCellPadding * 2), CGFloat.max)
                    let textBounds = text.boundingRectWithSize(maxTextRect, options: .UsesLineFragmentOrigin | .UsesFontLeading, context: nil)
                    let newRowHeight = Float(textBounds.size.height) + tableCellPadding * 2
                    if newRowHeight > rowHeight {
                        rowHeight = newRowHeight
                    }
                case let .ImageCell(image, cellAttr):
                    cellAttributes = cellAttr
                    cellType = .ImageCell(image: image)

                    let newRowHeight = Float(image.size.height) + tableCellPadding * 2
                    if newRowHeight > rowHeight {
                        rowHeight = newRowHeight
                    }
                case let .CustomCell(drawingBlock, cellAttr):
                    cellAttributes = cellAttr
                    cellType = .CustomCell(drawingBlock)
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
            heightWithLinkedRow += rowHeight
        }
        if (self.startNewPageIfNeeded(heightWithLinkedRow)) {
            self.drawTableHeader(table)
            currentY = self.y
        }

        var currentX = pageLeftMargin
        for theCell in preparedCells {
            let cellFrame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(theCell.cellWidth), CGFloat(rowHeight))

            drawFrame(cellFrame, cellAttributes: theCell.cellAttributes)

            switch theCell.cellType {
            case .Empty: // We've already drawn cell frame
                break
            case let .TextCell(text):
                let contentFrame = CGRectInset(cellFrame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
                drawString(text, inFrame: contentFrame)
            case let .ImageCell(image):
                // TODO: Implement image drawing!
                break
            case let .CustomCell(drawingBlock):
                drawingBlock(frame: cellFrame)
            }

            currentX += theCell.cellWidth - defaultTableFrameWidth
        }

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func widthForColumn(column: PDFTableColumn, allColumns: Array<PDFTableColumn>) -> Float {
        var columnWidth = column.columnWidth
        if (columnWidth <= 0) {
            if let width = self.columnsWidth[column.propertyName] {
                columnWidth = width
            }
        }
        if (columnWidth <= 0) {
            columnWidth = tableWidth
            var columnsWithoutWidthCount: Float = 0
            for column in allColumns {
                if column.columnWidth > 0 {
                    columnWidth -= column.columnWidth
                } else {
                    columnsWithoutWidthCount++
                }
            }
            if (columnsWithoutWidthCount > 1) {
                columnWidth /= columnsWithoutWidthCount
            }
            NSLog("Column width for \(column.propertyName) is \(columnWidth)")
            self.columnsWidth[column.propertyName] = columnWidth
        }

        return columnWidth
    }

    private func attributesForPageTitle() -> Dictionary<String, AnyObject> {
        let font = UIFont(name: defaultFontName, size: CGFloat(documentTitleFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .Center
        paragraph.lineBreakMode = .ByTruncatingMiddle

        let attributes: Dictionary<String, AnyObject> = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributesForTableSectionHeader() -> Dictionary<String, AnyObject> {
        let font = UIFont(name: defaultFontName, size: CGFloat(defaultTextFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .Center
        paragraph.lineBreakMode = .ByTruncatingMiddle

        let attributes: Dictionary<String, AnyObject> = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributesForTableColumnHeader() -> Dictionary<String, AnyObject> {
        let font = UIFont(name: defaultBoldFontName, size: CGFloat(defaultTextFontSize))!
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .Center
        paragraph.lineBreakMode = .ByTruncatingMiddle

        let attributes: Dictionary<String, AnyObject> = [NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraph]

        return attributes
    }

    private func attributedStringWithText(text: String, columnAttributes: Array<PDFTableTextAttribute>, cellAttributes: Array<PDFTableTextAttribute>?) -> NSAttributedString {
        var attributes = columnAttributes
        if let other = cellAttributes {
            attributes.extend(other)
        }

        var fontName = defaultFontName
        var fontSize = defaultTextFontSize
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .Center
        paragraph.lineBreakMode = .ByTruncatingMiddle

        var attributedString = NSMutableAttributedString(string: text, attributes: [NSFontAttributeName: UIFont(name: fontName, size: CGFloat(fontSize))!])

        for attribute in attributes {
            switch attribute {
            case let .Alignment(value):
                paragraph.alignment = value
                attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraph, range: NSMakeRange(0, count(text)))
            case let .FontSizeAbsolute(value, range):
                let font = UIFont(name: fontName, size: CGFloat(value))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .FontSizeRelative(value, range):
                let font = UIFont(name: fontName, size: CGFloat(fontSize * value))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .FontWeight(value, range):
                var fontName = ""
                switch value {
                case .Normal: fontName = defaultFontName
                case .Italic: fontName = defaultItalicFontName
                case .Bold: fontName = defaultBoldFontName
                }
                let font = UIFont(name: fontName, size: CGFloat(fontSize))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            }
        }

        return NSAttributedString(attributedString: attributedString)
    }

    private func cellAttributesContainCellsMerge(attributes: [PDFTableCellAttribute]?) -> Int? {
        if let cellAttributes = attributes {
            for attribute in cellAttributes {
                switch attribute {
                case let .MergedColumns(value):
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
    /// :param: rect Position and size of the frame
    /// :param: cellAttributes Attributes of cell frame and filling
    func drawFrame(rect: CGRect, cellAttributes: Array<PDFTableCellAttribute>? = nil) {
        var lineWidth: Float? = defaultTableFrameWidth
        var lineColor: UIColor = UIColor.blackColor()
        var fillColor: UIColor?

        if let cellAttributes = cellAttributes {
            for attribute in cellAttributes {
                switch attribute {
                case let .FrameWidth(widthValue):
                    switch widthValue {
                    case let .NoWidth: lineWidth = nil
                    case let .Fixed(value): lineWidth = value
                    }
                case let .FrameColor(color):
                    lineColor = color
                case let .FillColor(color):
                    fillColor = color
                case .MergedColumns(_):
                    break
                }
            }
        }

        let currentContext = UIGraphicsGetCurrentContext()
        if let fillColor = fillColor {
            fillColor.setFill()
            UIRectFill(rect)
        }
        if let lineWidth = lineWidth {
            CGContextSetLineWidth(currentContext, CGFloat(lineWidth))
            lineColor.setStroke()
            UIRectFrame(rect)
        }
    }

    /// Low level method which draws string inside the frame
    ///
    /// :param: string Attributed string to draw
    /// :param: rect Frame which restricts the text on page
    public func drawString(string: NSAttributedString, inFrame rect: CGRect) {
        if (string.length == 0) {
            return
        }

        if (DRAW_STRING_RECT) {
            UIColor.magentaColor().setStroke()
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 0.4)
            UIRectFrame(rect)
            UIColor.blackColor().setStroke()
        }

        UIColor.blackColor().setFill()

        string.drawWithRect(rect, options: .UsesLineFragmentOrigin | .UsesFontLeading, context: nil)
    }
}
