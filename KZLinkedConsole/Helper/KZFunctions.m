//
//  KZFunctions.m
//  KZLinkedConsole
//
//  Created by Krzysztof Zabłocki on 09/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//
@import AppKit;
#import "KZFunctions.h"

@interface NSObject (SourceEditorView_Private)

- (void)_moveDownBy:(long long)arg1;

@end

@implementation KZFunctions

+ (NSString*)workspacePath {
    @try {
        NSDocument *document = [NSApp orderedDocuments].firstObject;
        return [[document valueForKeyPath:@"_workspace.representingFilePath.fileURL"] URLByDeletingLastPathComponent].path;
    }
    @catch (NSException *exception) {
        return nil;
    }
    return nil;
}

+ (void)scrollXcode9TextViewInWindow:(NSWindow *)window toLine:(NSInteger)line {

    // Based on class dump at https://github.com/XVimProject/XVim2/blob/master/XVim2/Xcode/SourceEditor/SourceEditorView.h

    // Opening file is not immediate operation at least in Xcode 9
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView /*SourceEditorView*/ *textView = [window valueForKeyPath:@"windowController.editorArea.lastActiveEditorContext.editor.textView"];
        
        if (nil == textView) {
            NSLog(@"Couldn't locate textView in %@", window);
        }
        
        if (![textView respondsToSelector:@selector(_moveDownBy:)]) {
            NSLog(@"textView doesn't respond to _moveDownBy: %@", textView);
            return;
        }
        [textView moveToBeginningOfDocument:nil];
        [textView _moveDownBy:(line - 1)];
        [textView selectLine:nil];
    });
}

@end
