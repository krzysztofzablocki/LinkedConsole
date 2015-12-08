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
        center.addObserver(self, selector: Selector("didChange"), name: "IDEControlGroupDidChangeNotificationName", object: nil)
    }

    deinit {
        center.removeObserver(self)
    }

    func didChange() {
        guard let consoleTextView = KZPluginHelper.consoleTextView(),
        let textStorage = consoleTextView.valueForKey("textStorage") as? NSTextStorage else {
            return
        }

        textStorage.kz_isUsedInXcodeConsole = true
    }

    static func swizzleMethods() {
        let original = class_getInstanceMethod(NSClassFromString("NSTextStorage"), Selector("fixAttributesInRange:"))
        method_exchangeImplementations(original, class_getInstanceMethod(NSClassFromString("NSTextStorage"), Selector("kz_fixAttributesInRange:")))

        let original2 = class_getInstanceMethod(NSClassFromString("NSTextView"), Selector("mouseDown:"))
        method_exchangeImplementations(original2, class_getInstanceMethod(NSClassFromString("NSTextView"), Selector("kz_mouseDown:")))
    }
}