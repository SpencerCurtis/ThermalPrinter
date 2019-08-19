//
//  ViewController.swift
//  ThermalPrinter
//
//  Created by Spencer Curtis on 5/24/19.
//  Copyright © 2019 Lambda School. All rights reserved.
//

import Cocoa
import ORSSerial

class ViewController: NSViewController, ORSSerialPortDelegate {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var linesBeforeTextField: NSTextField!
    @IBOutlet weak var linesAfterTextField: NSTextField!
    
    let printer = Printer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        linesBeforeTextField.stringValue = "0"
        linesAfterTextField.stringValue = "3"
        
        printer.serialPort.delegate = self
        textView.string = UserDefaults.standard.string(forKey: "lastText") ?? ""
        let imageURL = Bundle.main.url(forResource: "test", withExtension: "bmp")!
        
        let data = try! Data(contentsOf: imageURL)
        
        print(data[1...100])
        
        let scalar = UnicodeScalar(data[1])
        
        printer.print(String(scalar))
        
//        printer.printBitmap(bitmap: macIconData, width: 229, height: 225)
        
        
        printer.reset()
        printer.resetToDefaults()
//        printer.printBitmap(bitmap: data, width: 200, height: 200, lineAtATime: false)
    }
    
    @IBAction func printWrittenText(_ sender: Any) {
        
        var printText: String = ""
        
        let linesBefore = Int(linesBeforeTextField.stringValue) ?? 0
        let linesAfter = Int(linesAfterTextField.stringValue) ?? 0
        printText += textView.string
        
        printer.feed(lines: linesBefore)
        printer.print(printText)
        printer.feed(lines: linesAfter)
        
        UserDefaults.standard.set(printText, forKey: "lastText")
    }
   
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        let dataString = String(data: data, encoding: .ascii)!
        print(dataString)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print(error)
    }
    
    func serialPortWasRemoved(fromSystem serialPort: ORSSerialPort) {
        
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func presentAlertWith(message: String, informativeText: String) {
        let alert = NSAlert()
        
        alert.messageText = message
        alert.informativeText = informativeText
        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
}

