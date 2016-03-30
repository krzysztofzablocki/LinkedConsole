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
        
        guard let filePath = kz_findFile(workspacePath, fileName) else {
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
}


/**
 [workspacePath : [fileName : filePath]]
 */
var kz_filePathCache = [String : [String : String]]()


/**
 Search for the given filename in the given workspace.

 To avoid parsing the project's header file inclusion path,
 we use the following heuristic:

 1. Look in kz_filePathCache.
 2. Look for the file in the current workspace.
 3. Look in the parent directory of the current workspace,
    excluding the current workspace because we've already searched there.
 4. Keep recursing upwards, but stop if we have gone more than 2
    levels up or we have reached /foo/bar.

 The assumption here is that /foo/bar would actually be /Users/username
 and searching the developer's entire home directory is likely to be too
 expensive.

 Similarly, if the project is in some subdirectory heirarchy, then if
 we are three levels up then that search is likely to be large and too
 expensive also.

 */
func kz_findFile(workspacePath : String, _ fileName : String) -> String? {
    var thisWorkspaceCache = kz_filePathCache[workspacePath] ?? [:]
    if let result = thisWorkspaceCache[fileName] {
        if NSFileManager.defaultManager().fileExistsAtPath(result) {
            return result
        }
    }

    var searchPath = workspacePath
    var prevSearchPath : String? = nil
    var searchCount = 0
    while true {
        let result = kz_findFile(fileName, searchPath, prevSearchPath)
        if result != nil && !result!.isEmpty {
            thisWorkspaceCache[fileName] = result
            kz_filePathCache[workspacePath] = thisWorkspaceCache
            return result
        }

        prevSearchPath = searchPath
        searchPath = (searchPath as NSString).stringByDeletingLastPathComponent
        searchCount += 1
        let searchPathCount = searchPath.componentsSeparatedByString("/").count
        if searchPathCount <= 3 || searchCount >= 2 {
            return nil
        }
    }
}

func kz_findFile(fileName : String, _ searchPath : String, _ prevSearchPath : String?) -> String? {
    let args = (prevSearchPath == nil ?
        ["-L", searchPath, "-name", fileName, "-print", "-quit"] :
        ["-L", searchPath, "-name", prevSearchPath!, "-prune", "-o", "-name", fileName, "-print", "-quit"])
    return KZPluginHelper.runShellCommand("/usr/bin/find", arguments: args)
}

func kz_gitBranch(path: String) -> String? {
    let args = ["branch", "--no-color"]
    if let branches = KZPluginHelper.runShellCommand("/usr/bin/git", arguments: args, currenctDirectoryPath: path) {
        let branchStr: NSString = branches
        let branchArray = branchStr.componentsSeparatedByString("\n")
        var branchName = ""
        for item in branchArray {
            if item.hasPrefix("*") {
                branchName = item
            }
        }
        return branchName
    }
    return nil
}
