//
// Created by Krzysztof Zabłocki on 05/12/15.
// Copyright (c) 2015 pixle. All rights reserved.
//

import Foundation
import AppKit

extension NSTextView {
    func kz_mouseDown(_ event: NSEvent) {
        let pos = convert(event.locationInWindow, from:nil)
        let idx = characterIndexForInsertion(at: pos)

        guard let expectedClass = NSClassFromString("IDEConsoleTextView")
            , isKind(of: expectedClass) && attributedString().length > 1 && idx < attributedString().length else {
                kz_mouseDown(event)
            return
        }
        
        let attr = attributedString().attributes(at: idx, effectiveRange: nil)
        
        guard let fileName = attr[KZLinkedConsole.Strings.linkedFileName] as? String,
            let lineNumber = attr[KZLinkedConsole.Strings.linkedLine] as? String else {
                kz_mouseDown(event)
                return
        }
        
        KZLinkedConsole.openFile(fromTextView: self, fileName: fileName, lineNumber: lineNumber)
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
func kz_findFile(_ workspacePath : String, _ fileName : String) -> String? {
    var thisWorkspaceCache = kz_filePathCache[workspacePath] ?? [:]
    if let result = thisWorkspaceCache[fileName] {
        if FileManager.default.fileExists(atPath: result) {
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
        searchPath = (searchPath as NSString).deletingLastPathComponent
        searchCount += 1
        let searchPathCount = searchPath.components(separatedBy: "/").count
        if searchPathCount <= 3 || searchCount >= 2 {
            return nil
        }
    }
}

func kz_findFile(_ fileName : String, _ searchPath : String, _ prevSearchPath : String?) -> String? {
    let args = (prevSearchPath == nil ?
        ["-L", searchPath, "-name", fileName, "-print", "-quit"] :
        ["-L", searchPath, "-name", prevSearchPath!, "-prune", "-o", "-name", fileName, "-print", "-quit"])
    return KZPluginHelper.runShellCommand("/usr/bin/find", arguments: args)
}
