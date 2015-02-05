//
//  PdfGeneratorTable.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 29/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//

public protocol PDFTable {
    var columns: Array<PDFTableColumn> { get }

    var sectionsNumber: Int { get }

    func numberOfRowsInSection(section: Int) -> Int
    func titleForHeaderInSection(section: Int) -> String?
    func rowAtIndex(row: Int, section: Int) -> PDFTableRow
//    func cell(row: Int, column: Int, section: Int) -> PDFTableCell?
}
