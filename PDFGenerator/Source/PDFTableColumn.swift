//
//  PDFTableColumn.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 31/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//

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
