//
// Created by Krzysztof Zabłocki on 05/12/15.
// Copyright (c) 2015 pixle. All rights reserved.
//

import Foundation
import AppKit

extension NSTextStorage {

    private struct AssociatedKeys {
        static var isConsoleKey = "isConsoleKey"
    }

    var kz_isUsedInXcodeConsole: Bool {
        get {
            guard let value = objc_getAssociatedObject(self, &AssociatedKeys.isConsoleKey) as? NSNumber else {
                return false
            }

            return value.boolValue
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isConsoleKey, NSNumber(bool: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func kz_fixAttributesInRange(range: NSRange) {
        kz_fixAttributesInRange(range) //! call original implementation first

        if !self.kz_isUsedInXcodeConsole {
            return
        }

        injectLinksIntoLogs()
    }

    private func injectLinksIntoLogs() {
        let text = string as NSString

        let matches = pattern.matchesInString(string, options: .ReportProgress, range: editedRange)
        for result in matches where result.numberOfRanges == 5 {
            let fullRange = result.rangeAtIndex(0)
            let fileNameRange = result.rangeAtIndex(1)
            let maybeParensRange = result.rangeAtIndex(3)
            let lineRange = result.rangeAtIndex(4)

            let ext: String
            if maybeParensRange.location == NSNotFound {
                let extensionRange = result.rangeAtIndex(2)
                ext = text.substringWithRange(extensionRange)
            } else {
                ext = "swift"
            }
            let fileName = "\(text.substringWithRange(fileNameRange)).\(ext)"

            addAttribute(NSLinkAttributeName, value: "", range: fullRange)
            addAttribute(KZLinkedConsole.Strings.linkedFileName, value: fileName, range: fullRange)
            addAttribute(KZLinkedConsole.Strings.linkedLine, value: text.substringWithRange(lineRange), range: fullRange)
        }
    }

    private var pattern: NSRegularExpression {
        // The second capture is either a file extension (default) or a function name (SwiftyBeaver format).
        // Callers should check for the presence of the third capture to detect if it is SwiftyBeaver or not.
        //
        // (If this gets any more complicated there will need to be a formal way to walk through multiple
        // patterns and check if each one matches.)
        return try! NSRegularExpression(pattern: "([\\w\\+]+)\\.(\\w+)(\\(.*\\))?:(\\d+)", options: .CaseInsensitive)
    }
}