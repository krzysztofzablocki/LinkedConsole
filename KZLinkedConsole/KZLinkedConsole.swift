//
//  KZLinkedConsole.swift
//
//  Created by Krzysztof Zabłocki on 05/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//

import AppKit

class KZLinkedConsole: NSObject {

    internal struct Strings {
        static let linkedFileName = "KZLinkedFileName"
        static let linkedLine = "KZLinkedLine"
    }

    private static var windowDidBecomeMainObserver: NSObjectProtocol?

    class func pluginDidLoad(bundle: NSBundle) {
        if NSBundle.mainBundle().bundleIdentifier == "com.apple.dt.Xcode" {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(controlGroupDidChange(_:)), name: "IDEControlGroupDidChangeNotificationName", object: nil)
            NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(openFile(_:)), name: "pl.pixle.KZLinkedConsole.OpenFile", object: nil)
            swizzleMethods()
        }
    }

    static func controlGroupDidChange(notification: NSNotification) {
        guard let consoleTextView = KZPluginHelper.consoleTextView(),
        let textStorage = consoleTextView.valueForKey("textStorage") as? NSTextStorage else {
            return
        }
        consoleTextView.linkTextAttributes = [
            NSCursorAttributeName: NSCursor.pointingHandCursor(),
            NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue
        ]
        textStorage.kz_isUsedInXcodeConsole = true
    }

    static func openFile(notification: NSNotification) {
        guard let fileName = notification.object?.description else {
            return
        }
        
        openFile(fromTextView: nil, fileName: fileName, lineNumber: notification.userInfo?["Line"]?.description)
    }

    static func openFile(fromTextView textView: NSTextView?, fileName: String, lineNumber: String? = nil) {
        var optionalFilePath: String?
        if (fileName as NSString).absolutePath {
            optionalFilePath = fileName
        } else if let workspacePath = KZPluginHelper.workspacePath() {
            optionalFilePath = kz_findFile(workspacePath, fileName)
        }
        
        guard let filePath = optionalFilePath else {
            return
        }
        
        if NSApp.delegate?.application!(NSApp, openFile: filePath) ?? false {
            NSDistributedNotificationCenter.defaultCenter().postNotificationName("pl.pixle.KZLinkedConsole.DidOpenFile", object: filePath)
            guard let line = lineNumber != nil ? Int(lineNumber!) : 0 where line >= 1 else {
                return
            }
            
            if let window = textView?.window ?? NSApp.mainWindow {
                scrollTextView(inWindow: window, toLine: line)
            } else {
                windowDidBecomeMainObserver = NSNotificationCenter.defaultCenter().addObserverForName(NSWindowDidBecomeMainNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) in
                    scrollTextView(inWindow: notification.object as! NSWindow, toLine: line)
                    NSNotificationCenter.defaultCenter().removeObserver(windowDidBecomeMainObserver!)
                })
            }
        }
    }

    static func scrollTextView(inWindow window: NSWindow, toLine line: Int) {
        guard let textView = KZPluginHelper.editorTextView(inWindow: window),
            let text = (textView.string as NSString?) else {
                return
        }
        
        var currentLine = 1
        var index = 0
        while index < text.length {
            let lineRange = text.lineRangeForRange(NSMakeRange(index, 0))
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
            let fixAttributesInRangeSelector = #selector(NSTextStorage.fixAttributesInRange(_:))
            let kz_fixAttributesInRangeSelector = #selector(NSTextStorage.kz_fixAttributesInRange(_:))
            try storageClass.jr_swizzleMethod(fixAttributesInRangeSelector, withMethod: kz_fixAttributesInRangeSelector)
            let mouseDownSelector = #selector(NSTextView.mouseDown(_:))
            let kz_mouseDownSelector = #selector(NSTextView.kz_mouseDown(_:))
            try textViewClass.jr_swizzleMethod(mouseDownSelector, withMethod: kz_mouseDownSelector)
        }
        catch {
            Swift.print("Swizzling failed")
        }
    }
}