//
//  KZLinkedConsole.swift
//
//  Created by Krzysztof Zabłocki on 05/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//

import AppKit

extension Notification.Name {
    static let KZLinkedConsoleDidOpenFile = Notification.Name(rawValue: "pl.pixle.KZLinkedConsole.DidOpenFile")
}

class KZLinkedConsole: NSObject {

    internal struct Strings {
        static let linkedFileName = "KZLinkedFileName"
        static let linkedLine = "KZLinkedLine"
    }

    private static var windowDidBecomeMainObserver: NSObjectProtocol?

    class func pluginDidLoad(_ bundle: Bundle) {
        if Bundle.main.bundleIdentifier == "com.apple.dt.Xcode" {
            NotificationCenter.default.addObserver(self, selector: #selector(controlGroupDidChange(_:)), name: NSNotification.Name(rawValue: "IDEControlGroupDidChangeNotificationName"), object: nil)
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(openFile(_:)), name: NSNotification.Name(rawValue: "pl.pixle.KZLinkedConsole.OpenFile"), object: nil)
            swizzleMethods()
        }
    }

    static func controlGroupDidChange(_ notification: Notification) {
        guard let consoleTextView = KZPluginHelper.consoleTextView(),
        let textStorage = consoleTextView.value(forKey: "textStorage") as? NSTextStorage else {
            return
        }
        consoleTextView.linkTextAttributes = [
            NSCursorAttributeName: NSCursor.pointingHand(),
            NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue
        ]
        textStorage.kz_isUsedInXcodeConsole = true
    }

    static func openFile(_ notification: Notification) {
        guard let fileName = (notification.object as? NSObject)?.description else {
            return
        }
        
        openFile(fromTextView: nil, fileName: fileName, lineNumber: ((notification as NSNotification).userInfo?["Line"] as AnyObject).description)
    }

    static func openFile(fromTextView textView: NSTextView?, fileName: String, lineNumber: String? = nil) {
        var optionalFilePath: String?
        if (fileName as NSString).isAbsolutePath {
            optionalFilePath = fileName
        } else if let workspacePath = KZPluginHelper.workspacePath() {
            optionalFilePath = kz_findFile(workspacePath, fileName)
        }
        
        guard let filePath = optionalFilePath else {
            return
        }
        
        if NSApp.delegate?.application!(NSApp, openFile: filePath) ?? false {
            DistributedNotificationCenter.default.post(name: Notification.Name.KZLinkedConsoleDidOpenFile, object: filePath)
            guard let line = lineNumber != nil ? Int(lineNumber!) : 0 , line >= 1 else {
                return
            }
            
            if let window = textView?.window ?? NSApp.mainWindow {
                scrollTextView(inWindow: window, toLine: line)
            } else {
                windowDidBecomeMainObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSWindowDidBecomeMain, object: nil, queue: OperationQueue.main, using: { (notification) in
                    scrollTextView(inWindow: notification.object as! NSWindow, toLine: line)
                    NotificationCenter.default.removeObserver(windowDidBecomeMainObserver!)
                })
            }
        }
    }

    static func scrollTextView(inWindow window: NSWindow, toLine line: Int) {
        guard nil == NSClassFromString("SourceEditor.SourceEditorView") else {
            KZFunctions.scrollXcode9TextView(in: window, toLine: line)
            return
        }
        guard let textView = KZPluginHelper.editorTextView(inWindow: window),
            let text = (textView.string as NSString?) else {
            return
        }
        
        var currentLine = 1
        var index = 0
        while index < text.length {
            let lineRange = text.lineRange(for: NSMakeRange(index, 0))
            index = NSMaxRange(lineRange)
            
            if currentLine == line {
                textView.scrollRangeToVisible(lineRange)
                textView.setSelectedRange(lineRange)
                break
            }
            currentLine += 1
        }
    }

    static func swizzleMethods() {
        guard let storageClass = NSClassFromString("NSTextStorage") as? NSObject.Type,
            let textViewClass = NSClassFromString("NSTextView") as? NSObject.Type else {
                return
        }
        
        do {
            let fixAttributesInRangeSelector = #selector(NSTextStorage.fixAttributes(in:))
            let kz_fixAttributesInRangeSelector = #selector(NSTextStorage.kz_fixAttributesInRange(_:))
            try storageClass.jr_swizzleMethod(fixAttributesInRangeSelector, withMethod: kz_fixAttributesInRangeSelector)
            let mouseDownSelector = #selector(NSTextView.mouseDown(with:))
            let kz_mouseDownSelector = #selector(NSTextView.kz_mouseDown(_:))
            try textViewClass.jr_swizzleMethod(mouseDownSelector, withMethod: kz_mouseDownSelector)
        }
        catch {
            Swift.print("Swizzling failed")
        }
    }
}
