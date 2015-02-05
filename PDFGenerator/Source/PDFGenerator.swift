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

let documentTitleFontSize: Float = 12.0

private let vSpaceAfterPageTitle = pointsFromMm(10)

private let tableCellPadding: Float = 2.0
private let tableHeaderHeight: Float = 15.0

private let defaultTableFrameWidth = pointsFromMm(0.2)

private struct PreparedCell {
    var text: NSAttributedString?
    let textFrame: CGRect?
    let cellFrame: CGRect
}


private let DRAW_STRING_RECT = true

public class PDFGenerator: NSObject {

    public var pageTitle: String?

    public let defaultTextFontSize: Float = 9.0

    public let pageLeftMargin   = pointsFromMm(25)
    public let pageTopMargin    = pointsFromMm(10)
    public let pageRightMargin  = pointsFromMm(10)
    public let pageBottomMargin = pointsFromMm(10)

    public let minSpaceBetweenBlocks = pointsFromMm(5)

    public let defaultFontName         = "HelveticaNeue"
    public let defaultBoldFontName     = "HelveticaNeue-Bold"
    public let defaultItalicFontName   = "HelveticaNeue-Italic"

    public var pageWidth  = pointsFromMm(210)
    public var pageHeight = pointsFromMm(297)
    public var pageBounds: CGRect {
        return CGRectMake(0, 0, CGFloat(pageWidth), CGFloat(pageHeight))
    }

    public var contentMaxWidth: Float {
        return pageWidth - pageLeftMargin - pageRightMargin
    }
    public var tableWidth: Float {
        return contentMaxWidth
    }

    private var tableCellHeight: Float {
        return defaultTextFontSize + tableCellPadding * 2
    }

    private let outputFilePath: String
    private var pdfContextInfo = Dictionary<String, String>()
    private(set) public var y: Float = 0.0

    public init(outputFilePath: String) {
        self.outputFilePath = outputFilePath

        super.init()
    }

    public func addDocumentInfo(param: PDFDocumentInfo, value: String) {
        var paramName: String
        switch param {
        case .DocumentName: paramName = String(kCGPDFContextTitle)
        case .CreatorName: paramName = String(kCGPDFContextCreator)
        case .Subject: paramName = String(kCGPDFContextSubject)
        }
        self.pdfContextInfo[paramName] = value
    }

    /**
     * Should be overridden by subclass.
     * DON'T FORGET TO CALL SUPERCLASS METHOD!
     */
    public func generate() {
        UIGraphicsBeginPDFContextToFile(self.outputFilePath, pageBounds, self.pdfContextInfo)
        self.startNewPage()
    }

    /**
     * Should be called in the end of the generate() method
     */
    public func finish() {
        // Close the PDF context and write the contents out.
        UIGraphicsEndPDFContext()
    }

    public func addY(space: Float) {
        if (!self.startNewPageIfNeeded(space)) {
            self.y += space
        }
    }

    public func startNewPageIfNeeded(rowHeight: Float) -> Bool {
        if (rowHeight > (pageHeight - pageTopMargin - pageBottomMargin - self.y)) {
            self.startNewPage()
            return true
        }
        return false
    }

    private func startNewPage() {
        self.y = pageTopMargin
        UIGraphicsBeginPDFPage()
    }

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
        self.y += vSpaceAfterPageTitle
    }

    public func drawTable(table: PDFTable) {
        self.drawTableHeader(table)

        for section in 0..<table.sectionsNumber {
            if let sectionTitle = table.titleForHeaderInSection(section) {
                self.drawTableSectionHeader(sectionTitle)
            }
            for rowNum in 0..<table.numberOfRowsInSection(section) {
                let row = table.rowAtIndex(rowNum, section: section)
                self.drawRow(row, inTable: table)
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
        var currentX = pageLeftMargin
        var currentY = self.y
        var rowHeight = tableCellHeight
        var columnWidth = tableWidth + defaultTableFrameWidth

        let text = NSMutableAttributedString(string: sectionTitle, attributes: attributesForTableSectionHeader())
        let maxTextRect = CGSizeMake(CGFloat(columnWidth - tableCellPadding * 2), CGFloat.max)
        let textBounds = text.boundingRectWithSize(maxTextRect, options: NSStringDrawingOptions.UsesFontLeading, context: nil)

        rowHeight = Float(textBounds.size.height) + tableCellPadding * 2

        let cellFrame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(columnWidth), CGFloat(rowHeight))
        drawFrame(cellFrame)

        let contentFrame = CGRectInset(cellFrame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
        drawString(text, inFrame: contentFrame)

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func drawRow(row: PDFTableRow, inTable table: PDFTable) {
        var currentX = pageLeftMargin
        var currentY = self.y
        var rowHeight: Float = 0.0

        var preparedCells = Array<PreparedCell>()
        for columnIndex in 0..<row.rowCells.count {
            let column = table.columns[columnIndex]
            let columnWidth = self.widthForColumn(column, allColumns: table.columns) + defaultTableFrameWidth

            var cell: PreparedCell
            if let theCell = row.rowCells[columnIndex] {
                switch theCell {
                case let .TextCell(cellText, attributes):
                    let text = self.attributedStringWithText(cellText, columnAttributes: column.textAttributes, cellAttributes: attributes)

                    let maxTextRect = CGSizeMake(CGFloat(columnWidth - tableCellPadding) * 2, CGFloat.max)
                    let textBounds = text.boundingRectWithSize(maxTextRect, options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
                    let newRowHeight = Float(textBounds.size.height) + tableCellPadding * 2
                    if newRowHeight > rowHeight {
                        rowHeight = newRowHeight
                    }
                    let cellFrame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(columnWidth), CGFloat(rowHeight))
                    let contentFrame = CGRectInset(cellFrame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
                    cell = PreparedCell(text: text, textFrame: contentFrame, cellFrame: cellFrame)
//                case let .ImageCell(image):
//                    break
//                case let .CustomCell(drawingBlock):
//                    break
                default:
                    let cellFrame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(columnWidth), CGFloat(tableCellHeight))
                    cell = PreparedCell(text: nil, textFrame: nil, cellFrame: cellFrame)
                }
            } else {
                    let cellFrame = CGRectMake(CGFloat(currentX), CGFloat(currentY), CGFloat(columnWidth), CGFloat(tableCellHeight))
                cell = PreparedCell(text: nil, textFrame: nil, cellFrame: cellFrame)
            }
            preparedCells.append(cell)

            currentX += columnWidth - defaultTableFrameWidth
        }
        if (self.startNewPageIfNeeded(rowHeight)) {
            self.drawTableHeader(table)
            currentY = self.y
        }

        for theCell in preparedCells {
            var cellFrame = theCell.cellFrame
            cellFrame.origin.y = CGFloat(currentY)
            cellFrame.size.height = CGFloat(rowHeight)
            drawFrame(cellFrame)
            if let text = theCell.text {
                let contentFrame = CGRectInset(cellFrame, CGFloat(tableCellPadding), CGFloat(tableCellPadding))
                drawString(text, inFrame: contentFrame)
            }
        }

        self.y += rowHeight - defaultTableFrameWidth
    }

    private func widthForColumn(column: PDFTableColumn, allColumns: Array<PDFTableColumn>) -> Float {
        var columnWidth = column.columnWidth
        if (columnWidth <= 0) {
            // FIXME: Column width should not be calculated for every row!
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
        }

        NSLog("Column width for \(column.propertyName) is \(columnWidth)")

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
                attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraph, range: NSMakeRange(0, countElements(text)))
            case let .FontSizeAbsolute(value, range):
                fontSize = value
                let font = UIFont(name: fontName, size: CGFloat(fontSize))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .FontSizeRelative(value, range):
                fontSize *= value
                let font = UIFont(name: fontName, size: CGFloat(fontSize))!
                attributedString.addAttribute(NSFontAttributeName, value: font, range: range)
            case let .FontWeight(value, range):
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

    func drawFrame(rect: CGRect) {
        drawFrame(rect, lineWidth: defaultTableFrameWidth)
    }
    func drawFrame(rect: CGRect, lineWidth: Float) {
        let currentContext = UIGraphicsGetCurrentContext()
        CGContextSetLineWidth(currentContext, CGFloat(lineWidth))

        UIColor.blackColor().setStroke()
        UIRectFrame(rect)
    }

    /**
     * Low level level which draws atring inside the frame
     */
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

        string.drawWithRect(rect, options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
    }
}
