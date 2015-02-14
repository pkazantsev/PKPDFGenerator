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

    func numberOfRowsInSection(section: Int) -> Int
    func titleForHeaderInSection(section: Int) -> String?
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

    public mutating func addTextAttribute(attribute: PDFTableTextAttribute) {
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
    case EmptyCell(cellAttributes: Array<PDFTableCellAttribute>?)
    case TextCell(String, textAttributes: Array<PDFTableTextAttribute>?, cellAttributes: Array<PDFTableCellAttribute>?)
    case ImageCell(UIImage, cellAttributes: Array<PDFTableCellAttribute>?)
    case CustomCell((frame: CGRect) -> (), cellAttributes: Array<PDFTableCellAttribute>?)
}

public enum PDFTableTextAttribute {
    case Alignment(NSTextAlignment)

    case FontWeight(TextFontWeight, range: NSRange)
    case FontSizeAbsolute(Float, range: NSRange)
    case FontSizeRelative(Float, range: NSRange)

    public enum TextFontWeight {
        case Normal
        case Italic
        case Bold
    }
}

public enum PDFTableCellAttribute {
    /// Sets width for cell frame
    case FrameWidth(FrameWidthAttribute)
    /// Sets color for cell frame
    case FrameColor(UIColor)
    /// Sets fill color for cell or resets fill color if no value
    case FillColor(UIColor?)
    /// Sets count of columns which will be merged including the one with the attribute
    case MergedColumns(Int)

    public enum FrameWidthAttribute {
        case NoWidth
        case Fixed(Float)
    }
}
