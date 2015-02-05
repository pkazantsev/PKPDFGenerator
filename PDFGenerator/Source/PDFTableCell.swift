//
//  PDFTableCell.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 29/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//

public enum PDFTableCell {

    case TextCell(text: String, textAttributes: Array<PDFTableTextAttribute>?)
    case ImageCell(image: UIImage)
    case CustomCell((size: CGSize) -> ())

}
