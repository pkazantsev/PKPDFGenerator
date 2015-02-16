# PKPDFGenerator
The high level API for creating PDF documents in Swift (some may not be high-level enough yet)

## Usage
### Document
To start with, subclass PDFGenerator and implement `generate()` method, don't forget to call superclass' `generate()` method in the beginning and `finish()` in the end:
```swift
override func generate() {
    super.generate()
    // Your code
    super.finish()
}
```
In that method you implement your drawing code. Drawing should be performed using UIKit drawing features like `NSString.drawInRect()` and `UIImage.drawInRect()`. 
After every draw `addY` method should be called with height of the drawn rect and desired space to add before next block, default value could be used — `minSpaceBetweenBlocks`.

### Document parameters
Many parameters of document could be set:
* Page title — `pageTitle` will be drawn when `drawPageTitle()` called
* Page size — could be set using `setPageFormat(PDFPageSize, orientation: PDFPageOrientation)` with one of predefined sizes or custom size could be set to `pageWidth` and `pageHeight` properties
* Font name and size — `defaultFontName` and `defaultTextFontSize` properties
* Page margins — separate properties `pageLeftMargin`, `pageTopMargin`, `pageRightMargin`, `pageBottomMargin`
* Table frame width — `defaultTableFrameWidth`
* Default space between blocks — `minSpaceBetweenBlocks`

### Text
Text is drawn using `drawString(NSAttributedString, inFrame:CGRect)` method. *__To be improved!__*

### Table
Main feature of the framework — Table.
To use table one should implement `PDFTable` protocol, it's designed after `UITableViewDelegate`.

#### PDFTable
1. Table's `columns` should be populated with `PDFTableColumn` instances. 
2. `sectionsNumber: Int` - number of sections in table. **Should be at least 1**
2. `numberOfRowsInSection(Int) -> Int` should return number of sections in the table. **Should be at least 1**
3. `titleForHeaderInSection(Int) -> Int` could return title for section or nil, in that case row for that section's title is not added to the table.
4. `rowAtIndex(Int, section: Int) -> PDFTableRow` returns row which for now only consists of `PDFTableCell` array. 
5. `linkWithNextBlockOfHeight: Float?` tells the generator to check that there is enough space to draw a block of given height after the last row of the table, if not — page break is adedd before the last row.
For a table without sections set `sectionsNumber` to 1 and return nil from `titleForHeaderInSection(Int)`

#### PDFTableColumn
Column can be populated with data:
* Column title
* Column width — optional. If not set autocalculation will be used based on table width
* Property name — optional. May be used to get data from `PDFTable` based on property.
* Text attributes — text attributes for all cells of the column. 

#### PDFTableCell
The core of the table.
Can be set to one of:
* Empty cell — draws only cell frame.
* Text cell — draws text.
* Image cell — draws image. *__To be implemented!__*
* Custom cell — contains closure which takes position and size of the cell and can draw in frame of the cell. *__To be implemented!__*

Cells of all types have `cellAttributes` property which is array of `PDFTableCellAttribute` and can be set to:
* FrameWidth — enum, `.FixedWidth` to sets frame width or `.NoWidth` if no frame should be drawn
* FrameColor
* FillColor
* MergedColumns(Int) — count of columns which should be merged include the one for which this property set. 

Text cells and columns can be configured with `textAttributes` of type `PDFTableTextAttribute`:
* Alignment(NSTextAlignment) - text aligment: `.Left`, `.Right`, `.Center`
* FontWeight(TextFontWeight, range: NSRange) — can be set to `.Normal`, `.Bold`, `.Italic`.
* FontSizeAbsolute(Float, range: NSRange) — text size
* FontSizeRelative(Float, range: NSRange) — text size relative to default text size

## Tasks:
* Create ArrayPDFTable: PDFTable class
* Create GroupedPDFTable: PDFTable class
* Create example project
* Introduce autolayouts
