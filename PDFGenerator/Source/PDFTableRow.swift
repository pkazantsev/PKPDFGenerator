//
//  PDFTableRow.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 31/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//

public struct PDFTableRow {
    public var rowCells: Array<PDFTableCell?>

    public init(rowCells: Array<PDFTableCell?>) {
        self.rowCells = rowCells
    }
}
