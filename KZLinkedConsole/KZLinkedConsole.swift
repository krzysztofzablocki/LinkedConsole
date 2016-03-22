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
        static let linkedFileName = "KZLinkedFileName"
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
        let didChangeSelector = #selector(KZLinkedConsole.didChange(_:))
        center.addObserver(self, selector: didChangeSelector, name: "IDEControlGroupDidChangeNotificationName", object: nil)
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