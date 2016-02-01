//
// Created by Krzysztof Zabłocki on 05/12/15.
// Copyright (c) 2015 pixle. All rights reserved.
//

import Foundation
import AppKit


let DEBUG_LOGGING = false

func DLog(@autoclosure msgClosure : () -> String?) {
    if DEBUG_LOGGING {
        guard let msg = msgClosure() else {
            return
        }
        NSLog("%@ %@", NSDate(), msg)
    }
}


extension NSTextStorage {

    private struct AssociatedKeys {
        static var isConsoleKey = "isConsoleKey"
        static var linkInjectorKey = "linkInjectorKey"
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

    var kz_linkInjector: KZLinkInjector {
        get {
            if let result = objc_getAssociatedObject(self, &AssociatedKeys.linkInjectorKey) as? KZLinkInjector {
                return result
            }
            else {
                let result = KZLinkInjector(textStorage: self)
                objc_setAssociatedObject(self, &AssociatedKeys.linkInjectorKey, result, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return result
            }
        }
    }

    func kz_fixAttributesInRange(range: NSRange) {
        kz_fixAttributesInRange(range) //! call original implementation first

        if !self.kz_isUsedInXcodeConsole {
            return
        }

        if !self.editedMask.contains(.EditedCharacters) {
            return
        }

        self.kz_linkInjector.injectLinks(self.editedRange)
    }
}

/**
 This class does the actual work of finding filename / line number pairs in the
 log file and adding text attributes to turn them into clickable links.

 This involves parsing the log, which can be quite expensive if there's a lot of text.
 To reduce this cost, we make a critical assumption, which is that the text can only
 change at the end, and can't change sections that we've already processed.  This
 wouldn't be true of course for a generic NSTextStorage instance, but it should be
 true for an Xcode console log.

 To further reduce the impact on Xcode performance, we perform the log parsing on
 a background thread if the region in question is large.  The results (regions to be
 marked as links) are then dispatched back onto the main thread to update Xcode's
 NSTextStorage.  This relies on our assumption that the log is only changing at the
 end, because otherwise all the ranges in the regex parsing would be offset by any
 parallel text changes.

 This class also batches up any changes to the NSTextStorage, so that we can use
 beginEditing() / endEditing() to reduce the impact of change notifications.
*/
final class KZLinkInjector {
    typealias LinkDetails = (fileName: String, line: String, range: NSRange)

    /**
     If the edited range is small, then we process it on the main thread
     because the processing should be cheap and we can avoid
     the bouncing between threads.

     If the range is large, then we do the parsing work on a background
     thread and batch it before applying the changes on the main thread.

     This threshold defines "large" above, and the 2000 character value
     is a complete guess.
     */
    private let syncThreshold = 2000

    private let pendingLinksBatchTime = dispatch_time(DISPATCH_TIME_NOW, 300000000)

    /**
     Xcode's NSTextStorage instance.  Unowned to avoid a retain cycle since
     this NSTextStorage holds a reference to this KZLinkInjector as an
     associated object using kz_linkInjector above.

     May only be accessed from the main thread.
    */
    private unowned let textStorage : NSTextStorage

    /**
     Link info that has been computed on a background thread, and is now
     waiting for pendingLinksBatchTime so that it can be set on textStorage
     on the main thread.

     May only be accessed under pendingLinksLock.
    */
    private var pendingLinks : [LinkDetails] = []

    /**
     A revision counter for the validity of pendingLinks across
     pendingLinksBatchTime delay.  If this counter has changed in that time,
     then pendingLinks is known to have been updated and we wait a little
     longer before proceeding.

     This means that the contents of pendingLinks are not processed at all
     until they have stopped changing for at least pendingLinksBatchTime.

     May only be accessed under pendingLinksLock.
     */
    private var pendingLinksCounter = 1

    private let pendingLinksLock = NSLock()

    /**
     Queue used for log parsing work.
     */
    private var queue : dispatch_queue_t {
        return dispatch_queue_create("KZLinkedConsole.KZLinkInjector.queue", DISPATCH_QUEUE_SERIAL)
    }

    init(textStorage : NSTextStorage) {
        self.textStorage = textStorage
    }

    /**
     Append the given newLinks to pendingLinks, increment pendingLinksCounter,
     and do these both under the protection of pendingLinksLock.

     This is how new LinkDetails from the background thread are saved until
     pendingLinksBatchDelay has elapsed.
     */
    private func appendPendingLinks(newLinks : [LinkDetails]) -> Int {
        DLog("Appending \(newLinks.count) \(newLinks.first!.range)")
        return KZLinkInjector.withLock(pendingLinksLock) { [unowned self] () -> Int in
            self.pendingLinks += newLinks
            self.pendingLinksCounter++
            return self.pendingLinksCounter
        }
    }

    /**
     If the given myPendingLinksCounter matches self.pendingLinksCounter,
     return the contents of self.pendingLinks, and clear it.  Return nil
     otherwise.  Do that under the protection of pendingLinksLock.

     This is how new LinkDetails from self.pendingLinks are retrieved by
     the main thread when pendingLinksBatchDelay has elapsed.
     */
    private func getPendingLinksMatchingCounter(myPendingLinksCounter : Int) -> [LinkDetails]? {
        return KZLinkInjector.withLock(pendingLinksLock) { [unowned self] () -> [LinkDetails]? in
            if self.pendingLinksCounter != myPendingLinksCounter {
                return nil
            }
            let result = self.pendingLinks
            if result.count == 0 {
                return nil
            }
            self.pendingLinks = []
            return result
        }
    }

    private func injectLinks(range : NSRange) {
        if (range.length <= syncThreshold) {
            self.injectLinksIntoTextSync(range)
        }
        else {
            self.injectLinksIntoTextAsync(range)
        }
    }

    private func injectLinksIntoTextSync(range : NSRange) {
        guard let newLinks = KZLinkInjector.findLinksInText(textStorage.string, range: range) else {
            return
        }

        DLog("Sync adding \(newLinks.count)")
        self.addLinksToTextStorage(newLinks)
    }

    private func injectLinksIntoTextAsync(range : NSRange) {
        let myText = String(textStorage.string)
        dispatch_async(queue) { [weak self] () -> Void in
            self?.injectLinksIntoTextBackground(myText, range: range)
        }
    }

    private func injectLinksIntoTextBackground(myText : String, range : NSRange) {
        guard let newLinks = KZLinkInjector.findLinksInText(myText, range: range) else {
            return
        }
        let myPendingLinksCounter = self.appendPendingLinks(newLinks)
        self.handlePendingLinksAfterDelay(myPendingLinksCounter)
    }

    private func handlePendingLinksAfterDelay(myPendingLinksCounter : Int) {
        dispatch_after(pendingLinksBatchTime, dispatch_get_main_queue()) { [weak self] () -> Void in
            self?.handlePendingLinks(myPendingLinksCounter)
        }
    }

    private func handlePendingLinks(myPendingLinksCounter : Int) {
        guard let myPendingLinks = self.getPendingLinksMatchingCounter(myPendingLinksCounter) else {
            return;
        }

        DLog("Pending: \(myPendingLinks.count) \(myPendingLinksCounter) \(myPendingLinks.first!.range)")
        self.addLinksToTextStorage(myPendingLinks)
    }

    private func addLinksToTextStorage(links : [LinkDetails]) {
        textStorage.beginEditing()
        for (fileName, line, range) in links {
            textStorage.addAttributes(
                [NSLinkAttributeName: "",
                    KZLinkedConsole.Strings.linkedFileName: fileName,
                    KZLinkedConsole.Strings.linkedLine: line
                ], range: range)
        }
        textStorage.endEditing()
    }

    private static func findLinksInText(string : String, range : NSRange) -> [LinkDetails]? {
        let text = string as NSString
        var links : [LinkDetails] = []
        let matches = pattern.matchesInString(string, options: [], range: range)
        for result in matches {
            let fullRange = result.rangeAtIndex(1)
            let fileNameRange = result.rangeAtIndex(2)
            let maybeParensRange = result.rangeAtIndex(4)
            let lineRange = result.rangeAtIndex(5)

            let ext: String
            if maybeParensRange.location == NSNotFound {
                let extensionRange = result.rangeAtIndex(3)
                ext = text.substringWithRange(extensionRange)
            } else {
                ext = "swift"
            }
            let fileName = "\(text.substringWithRange(fileNameRange)).\(ext)"
            let line = text.substringWithRange(lineRange)

            links.append((fileName, line, fullRange))
        }

        return (links.count > 0 ? links : nil)
    }

    private static var pattern: NSRegularExpression {
        // Default format:
        // <Start of line><Ignored stuff> <File name>.<File extension>:<Line no>
        //
        // SwiftyBeaver format, with .swift file extension missing and assumed:
        // <Start of line><Ignored stuff> <File name>.<Function name>():<Line no>
        //
        // The third capture is either a file extension (default) or a function name (SwiftyBeaver format).
        // Callers should check for the presence of the fourth capture to detect if it is SwiftyBeaver or not.
        //
        // (If this gets any more complicated there will need to be a formal way to walk through multiple
        // patterns and check if each one matches.)
        //
        // In both formats, <Ignored stuff> is capped at 200 chars.  This is to avoid
        // performance problems when parsing very long lines (e.g. debug data printed by lldb).
        return try! NSRegularExpression(pattern: "^.{1,200} (([\\w\\+]+)\\.(\\w+)(\\([^)]*\\))?:(\\d+))", options: .AnchorsMatchLines)
    }

    private static func withLock<T>(lock: NSLock, block: () -> T) -> T {
        lock.lock()
        let result = block()
        lock.unlock()
        return result
    }
}
