//
//  PdfGeneratorTable.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 29/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//
import UIKit

/// The PDFTable protocol should be implemented
/// to represent data for a table to be drawn on PDF document
public protocol PDFTable {
    var columns: Array<PDFTableColumn> { get }

    var sectionsNumber: Int { get }
    /// Used to check if the last row of the table can be drawn on current page
    /// with a next block of given height, if not – page break will be added
    /// before drawing the last row.
    var linkWithNextBlockOfHeight: Float? { get }

    func numberOfRowsInSection(_ section: Int) -> Int
    func titleForHeaderInSection(_ section: Int) -> String?
    func rowAtIndex(row: Int, section: Int) -> PDFTableRow
}

public struct PDFTableColumn {
    private(set) public var columnWidth: Float
    private(set) public var columnTitle: String
    private(set) public var propertyName: String
    private(set) public var textAttributes = Array<PDFTableTextAttribute>()

    public init(title: String, propertyName: String, width: Float = -1) {
        self.columnTitle = title
        self.columnWidth = width
        self.propertyName = propertyName
    }

    public mutating func addTextAttribute(_ attribute: PDFTableTextAttribute) {
        textAttributes.append(attribute)
    }
}

public struct PDFTableRow {
    public let rowCells: Array<PDFTableCell>

    public init(rowCells: Array<PDFTableCell>) {
        self.rowCells = rowCells
    }
}

/// PDFTableCell represent a cell of table. Can be of type:
///
/// - EmptyCell - Just a frame unless attributes contains FrameWidth.NoWidth attribute
/// - TextCell - Draws text with specified text attributes in a cell
/// - ImageCell - Draws image in a cell
/// - CustomCell - Block executed expected to draw something in frame passed
public enum PDFTableCell {
    case emptyCell(cellAttributes: Array<PDFTableCellAttribute>?)
    case textCell(String, textAttributes: Array<PDFTableTextAttribute>?, cellAttributes: Array<PDFTableCellAttribute>?)
    case imageCell(UIImage, cellAttributes: Array<PDFTableCellAttribute>?)
    case customCell((_ frame: CGRect) -> (), cellAttributes: Array<PDFTableCellAttribute>?)
}

public enum PDFTableTextAttribute {
    case alignment(NSTextAlignment)

    case fontWeight(TextFontWeight, range: NSRange)
    case fontSizeAbsolute(Float, range: NSRange)
    case fontSizeRelative(Float, range: NSRange)

    public enum TextFontWeight {
        case normal
        case italic
        case bold
    }
}

public enum PDFTableCellAttribute {
    /// Sets width for cell frame
    case frameWidth(FrameWidthAttribute)
    /// Sets color for cell frame
    case frameColor(UIColor)
    /// Sets fill color for cell or resets fill color if no value
    case fillColor(UIColor?)
    /// Sets count of columns which will be merged including the one with the attribute
    case mergedColumns(Int)

    public enum FrameWidthAttribute {
        case noWidth
        case fixed(Float)
    }
}
