//
//  PDFTableTextAttribute.swift
//  MyPriceList
//
//  Created by Pavel Kazantsev on 31/01/15.
//  Copyright (c) 2015 Pakaz.Ru. All rights reserved.
//

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
