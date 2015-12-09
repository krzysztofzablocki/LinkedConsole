//
//  KZFunctions.m
//  KZLinkedConsole
//
//  Created by Krzysztof Zabłocki on 09/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//
@import AppKit;
#import "KZFunctions.h"

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

@end
