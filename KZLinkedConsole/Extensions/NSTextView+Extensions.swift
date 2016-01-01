//
// Created by Krzysztof Zabłocki on 05/12/15.
// Copyright (c) 2015 pixle. All rights reserved.
//

import Foundation
import AppKit

extension NSTextView {
    func kz_mouseDown(event: NSEvent) {
        let pos = convertPoint(event.locationInWindow, fromView:nil)
        let idx = characterIndexForInsertionAtPoint(pos)

        guard let expectedClass = NSClassFromString("IDEConsoleTextView")
            where isKindOfClass(expectedClass) && attributedString().length > 1 && idx < attributedString().length else {
                kz_mouseDown(event)
            return
        }
        
        let attr = attributedString().attributesAtIndex(idx, effectiveRange: nil)
        
        guard let fileName = attr[KZLinkedConsole.Strings.linkedFileName] as? String,
            let lineNumber = attr[KZLinkedConsole.Strings.linkedLine] as? String,
            let appDelegate = NSApplication.sharedApplication().delegate else {
                kz_mouseDown(event)
                return
        }
        
        guard let workspacePath = KZPluginHelper.workspacePath() else {
            return
        }
        
        let args = ["-L", workspacePath, "-name", fileName, "-print", "-quit"]
        guard let filePath = KZPluginHelper.runShellCommand("/usr/bin/find", arguments: args) else {
            return
        }
        
        if appDelegate.application!(NSApplication.sharedApplication(), openFile: filePath) {
            dispatch_async(dispatch_get_main_queue()) {
                if  let textView = KZPluginHelper.editorTextView(inWindow: self.window),
                    let line = Int(lineNumber) where line >= 1 {
                        self.scrollTextView(textView, toLine:line)
                }
            }
        }
    }
    
    private func scrollTextView(textView: NSTextView, toLine line: Int) {
        guard let text = (textView.string as NSString?) else {
            return
        }
        
        var currentLine = 1
        var index = 0
        for (; index < text.length; currentLine++) {
            let lineRange = text.lineRangeForRange(NSMakeRange(index, 0))
            index = NSMaxRange(lineRange)
            
            if currentLine == line {
                textView.scrollRangeToVisible(lineRange)
                textView.setSelectedRange(lineRange)
                break
            }
        }
    }
}