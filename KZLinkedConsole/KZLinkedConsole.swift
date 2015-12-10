//
//  KZLinkedConsole.swift
//
//  Created by Krzysztof Zabłocki on 05/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//

import AppKit

var sharedPlugin: KZLinkedConsole?

class KZLinkedConsole: NSObject {

    internal struct Strings {
        static let linkedPath = "KZLinkedPath"
        static let linkedLine = "KZLinkedLine"
    }

    private var bundle: NSBundle
    private let center = NSNotificationCenter.defaultCenter()

    override static func initialize() {
        swizzleMethods()
    }

    init(bundle: NSBundle) {
        self.bundle = bundle

        super.init()
        center.addObserver(self, selector: "didChange:", name: "IDEControlGroupDidChangeNotificationName", object: nil)
    }

    deinit {
        center.removeObserver(self)
    }

    func didChange(notification: NSNotification) {
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

    static func swizzleMethods() {
        guard let storageClass = NSClassFromString("NSTextStorage") as? NSObject.Type,
            let textViewClass = NSClassFromString("NSTextView") as? NSObject.Type else {
                return
        }
        
        do {
            try storageClass.jr_swizzleMethod("fixAttributesInRange:", withMethod: "kz_fixAttributesInRange:")
            try textViewClass.jr_swizzleMethod("mouseDown:", withMethod: "kz_mouseDown:")
        }
        catch {
            Swift.print("Swizzling failed")
        }
    }
}