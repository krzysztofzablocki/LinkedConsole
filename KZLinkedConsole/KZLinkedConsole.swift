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

    class func pluginDidLoad(bundle: NSBundle) {
        if NSBundle.mainBundle().bundleIdentifier == "com.apple.dt.Xcode" {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(controlGroupDidChange(_:)), name: "IDEControlGroupDidChangeNotificationName", object: nil)
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

    static func openFile(textView: NSTextView?, fileName: String, lineNumber: String? = nil) {
        guard let workspacePath = KZPluginHelper.workspacePath() else {
            return
        }
        
        guard let filePath = kz_findFile(workspacePath, fileName) else {
            return
        }
        
        if NSApp.delegate?.application!(NSApp, openFile: filePath) ?? false {
            dispatch_async(dispatch_get_main_queue()) {
                if  let textView = KZPluginHelper.editorTextView(inWindow: textView?.window),
                    let line = Int(lineNumber!) where lineNumber != nil && line >= 1 {
                    scrollTextView(textView, toLine:line)
                }
            }
        }
    }

    static func scrollTextView(textView: NSTextView, toLine line: Int) {
        guard let text = (textView.string as NSString?) else {
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