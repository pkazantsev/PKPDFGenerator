//
//  PdfGeneratorTable.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 29/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//
import UIKit

public protocol PDFTable {
    var columns: Array<PDFTableColumn> { get }

    var sectionsNumber: Int { get }

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
    public let rowCells: Array<PDFTableCell?>

    public init(rowCells: Array<PDFTableCell?>) {
        self.rowCells = rowCells
    }
}

public enum PDFTableCell {
    case TextCell(text: String, textAttributes: Array<PDFTableTextAttribute>?)
    case ImageCell(image: UIImage)
    case CustomCell((size: CGSize) -> ())
}

public enum PDFTableTextFontWeight {
    case Normal
    case Italic
    case Bold
}

public enum PDFTableTextAttribute {
    case Alignment(value: NSTextAlignment)

    case FontWeight(value: PDFTableTextFontWeight, range: NSRange)
    case FontSizeAbsolute(value: Float, range: NSRange)
    case FontSizeRelative(value: Float, range: NSRange)
}
