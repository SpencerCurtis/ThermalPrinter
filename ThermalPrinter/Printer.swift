//
//  Printer.swift
//  ThermalPrinter
//
//  Created by Spencer Curtis on 5/25/19.
//  Copyright © 2019 Lambda School. All rights reserved.
//

import Foundation
import ORSSerial

class Printer {
    
    let serialPort: ORSSerialPort
    
    // MARK: - Thermal Printer Properties
    
    var resumeTime = 0.0
    var byteTime = 0.0
    var dotPrintTime = 0.0
    var dotFeedTime = 0.0
    var prevByte =  "\n"
    var column: UInt8 = 0
    var maxColumn: UInt8 = 32
    var charHeight: UInt8 = 24
    var lineSpacing: UInt8 = 8
    var barcodeHeight: UInt8 = 50
    var defaultHeatTime: UInt8 = 255 // 3-255 Heating time, Unit (10us), Default: 80 (800us)
    var firmwareVersion =   268
    var writeToStdout = false
    var printMode: UInt8 = 0 {
        didSet {
            writePrintMode()
        }
    }
    
    init(portPath: String = "/dev/cu.usbserial") {
        guard let port = ORSSerialPort(path: portPath) else {
            fatalError("Port not available. Is it connected you your machine?")
        }
        port.baudRate = 9600
        self.serialPort = port
        
        setHeatTime()
        setPrintDensity(1)
    }
    
    func setHeatTime() {
        /*
         27,       # Esc
         55,       # 7 (print settings)
         11,       # Heat dots
         defaultHeatTime, # 3-255 Heating time, Unit (10us), Default: 80 (800us)
         40)       # Heat interval
         */
        write(bytes: 27, 55, 11, defaultHeatTime, 40)
    }
    
    /// 100% density is 10.
    func setPrintDensity(_ density: UInt8) {
        write(bytes: 18,
              35,
              (2 << 5) | density)
        dotPrintTime = 0.03
        dotFeedTime = 0.0021
    }
    
    func resetToDefaults() {
        goOnline()
        justify(to: .left)
        invertColors(false)
        setDoubleHeight(false)
        setLineHeight(30)
        setBold(false)
        underline(size: .none)
    }
    
    func reset() {
        write(bytes: 27, 64) // Esc @ is the init command
        prevByte = "\n" // Treat as if prior line is blank
        column = 0
        maxColumn = 32
        charHeight = 24
        lineSpacing = 6
        barcodeHeight = 50
        
        if firmwareVersion >= 264 {
            write(bytes: 27, 68) // Set tab stops
            write(bytes: 4, 8, 12, 16) // every 4 columns,
            write(bytes: 20, 24, 28, 0) // 0 is end of list
        }
    }
    
    // MARK: - Character Commands
    
    private let inverseMask: UInt8 = 1 << 1
    private let updownMask: UInt8 = 1 << 2
    private let boldMask: UInt8 = 1 << 3
    private let doubleHeightMask: UInt8 = 1 << 4
    private let doubleWidthMark: UInt8 = 1 << 5
    private let strikethroughMask: UInt8 = 1 << 6
    
    enum PrintMode {
        case inverse
        case updown
        case bold
        case doubleHeight
        case doubleWidth
        case strikethrough
    }
    
    private func setPrintMode(_ printMode: PrintMode, turnOn: Bool) {
        
        var mask: UInt8
        
        switch printMode {
        case .inverse:
            mask = inverseMask
        case .updown:
            mask = updownMask
        case .bold:
            mask = boldMask
        case .doubleHeight:
            charHeight = turnOn ? 48 : 24
            mask = doubleHeightMask
        case .doubleWidth:
            maxColumn = turnOn ? 16 : 32
            mask = doubleWidthMark
        case .strikethrough:
            mask = strikethroughMask
        }
        
        if turnOn {
            self.printMode |= ~mask
        } else {
            self.printMode &= ~mask
        }
    }
    
    func writePrintMode() {
        write(bytes: 27, 33, printMode)
    }
    
    
    func invertColors(_ shouldInvert: Bool) {
        
        if firmwareVersion >= 268 {
            
            let invertByte: UInt8 = shouldInvert ? 1 : 0
            
            write(bytes: 29, 66, invertByte)
        } else {
            setPrintMode(.inverse, turnOn: shouldInvert)
        }
    }
    
    func setUpsideDown(_ shouldUpsideDown: Bool) {
        setPrintMode(.updown, turnOn: shouldUpsideDown)
    }
    
    func setBold(_ shouldBold: Bool) {
        setPrintMode(.bold, turnOn: shouldBold)
    }
    
    func setDoubleHeight(_ shouldDoubleHeight: Bool) {
        setPrintMode(.doubleHeight, turnOn: shouldDoubleHeight)
    }
    
    func setDoubleWidth(_ shouldDoubleWidth: Bool) {
        setPrintMode(.doubleWidth, turnOn: shouldDoubleWidth)
    }
    
    func setStrikethrough(_ shouldStrikethrough: Bool) {
        setPrintMode(.strikethrough, turnOn: shouldStrikethrough)
    }
    
   
    func setNormal() {
        printMode = 0
    }
    
    
    func setWidth(_ width: PrintWidth) {
        write(bytes: 27, 33, width.rawValue)
    }
    
    
    func setTimeout(seconds: TimeInterval) {
        resumeTime = Date().timeIntervalSince1970 + seconds
    }
    
    func feed(lines: Int) {
        if firmwareVersion >= 264 {
            write(bytes: 27, 100, lineSpacing)
            setTimeout(seconds: dotFeedTime * Double(charHeight))
            prevByte = "\n"
            column = 0
        } else {
            for _ in 1...lines {
                print("\n")
            }
        }
    }
    
    func feedRows(_ rows: Int) {
        write(bytes: 27, 74, UInt8(rows))
        setTimeout(seconds: Double(rows) * dotFeedTime)
        prevByte = "\n"
        column = 0
    }
    
    func setLineHeight(_ lineHeight: UInt8 = 32) {
        
        var lineHeight = lineHeight
        
        if lineHeight < 24 { lineHeight = 24 }
        
        let lineSpacing: UInt8 = lineHeight - 24
        
        write(bytes: 27, 51, lineSpacing)
    }
    
    
    func write(bytes: UInt8...) {
        
        var numbers = bytes
        
        let data = Data(bytes: &numbers, count: MemoryLayout.size(ofValue: numbers))
        
        serialPort.open()
        serialPort.send(data)
        serialPort.close()
    }
    
    func printBitmap() {
        let imageURL = Bundle.main.url(forResource: "test", withExtension: "bmp")!
    
        let data = try! Data(contentsOf: imageURL)
        
        var string = ""
        
        for i in data {
            let scalar = String(UnicodeScalar(i))
            string += scalar
        }
        
        let stringData = string.data(using: .utf8)!
        
        writeTextData(stringData)
    }
    
    
    enum PrintWidth: UInt8 {
        case normal
        case small
        case double = 17
    }
    
    enum Underline: Int {
        case none = 0
        case normal = 1
        case thick = 2
    }
    
    func underline(size: Underline) {
        write(bytes: 27, 45, UInt8(size.rawValue))
    }
    
    func print(_ text: String) {
        let data = text.data(using: .utf8)!
        serialPort.open()
        serialPort.send(data)
        serialPort.close()
    }
    
    enum Justification: UInt8 {
        case left
        case center
        case right
    }
    
    func justify(to justification: Justification) {
        write(bytes: 0x1B, 0x61, justification.rawValue)
    }
    
    func goOnline() {
        write(bytes: 27, 61, 1)
    }
    
    func goOffline() {
        write(bytes: 27, 61, 0)
    }
    
    func flush() {
        write(bytes: 12)
    }
    
    enum Size {
        case normal
        case medium
        case large
    }
    
    func setSize(_ size: Size) {
        
        let newSize: UInt8
        
        switch size {
        case .normal:
            newSize = 0x00
            charHeight = 24
            maxColumn = 32
        case .medium:
            newSize = 0x01
            charHeight = 48
            maxColumn = 32
        case .large:
            newSize = 0x11
            charHeight = 24
            maxColumn = 32
        }
        write(bytes: 29, 33, newSize)
        prevByte = "\n"
    }
    
    
    func printBitmap(bitmap: Data, width: UInt8, height: UInt8, lineAtATime: Bool = false) {
        
        let rowBytes: UInt8 = (width + 7) / 8
            
        let rowBytesClipped = min(48, rowBytes)
        
        let maxChunkHeight: UInt8 = lineAtATime ? 1 : 255
        
        for rowStart in stride(from: 0, to: height, by: Int(maxChunkHeight)) {
            
            var chunkHeight: UInt8 = UInt8(height - rowStart)
            
            chunkHeight = min(chunkHeight, maxChunkHeight)
            write(bytes: 18, 42, chunkHeight, rowBytesClipped)
            
            var i: Int = 0
            for y in 0...chunkHeight {
                for x in 0...rowBytesClipped {
                    
                    if writeToStdout {

                    } else {
                        var character = bitmap[Int(y) * Int(x)]
                        Swift.print(character)
                        writeBitmapData(Data(bytes: &character, count: MemoryLayout<UInt8>.size))
                    }
                    
                    i += 1
                }
                Swift.print("\(Int(rowBytes) - Int(rowBytesClipped))")
                i += Int(rowBytes) - Int(rowBytesClipped)
            }
            setTimeout(seconds: Double(chunkHeight) * dotFeedTime)
        }
        
        prevByte = "\n"
        
    }
    
    func timeoutWait() {
        if !writeToStdout {
            while Date().timeIntervalSince1970 - resumeTime < 0 {
                print("\(Date().timeIntervalSince1970 - resumeTime) seconds left to wait")
            }
        }
    }
    private func writeTextData(_ textData: Data) {
        serialPort.open()
        serialPort.send(textData)
        serialPort.close()
    }
    
    private func writeBitmapData(_ data: Data) {
        serialPort.open()
        
        for i in 0..<data.count {
            var character = data[i]
            
            var timeout = byteTime
            if character != 0x13 {
                
//                timeoutWait()
                serialPort.send(data)
                
                let characterString = String(UnicodeScalar(character))
                
                if characterString == "\n" || column == maxColumn {
                    // Blank Line
                    timeout += Double((charHeight + lineSpacing)) * dotFeedTime
                } else {
                    // Text Line
                    timeout += (Double(charHeight) + dotPrintTime)
                        + (Double(lineSpacing)  * dotFeedTime)
                    column = 0
                    
                    character = 0x0a
                }
            } else {
                column += 1
            }
            setTimeout(seconds: timeout)
            prevByte = String(UnicodeScalar(character))
        }
        
        
//        serialPort.send(data)
        serialPort.close()
    }
}

enum PrinterCommands: String {
    case tab = "\t"
    case lineFeed = "\n"
    case formFeed = "\\f"
    case carriageReturn = "\r"
}
