//
//  KZFunctions.m
//  KZLinkedConsole
//
//  Created by Krzysztof Zabłocki on 09/12/15.
//  Copyright © 2015 pixle. All rights reserved.
//

@import AppKit;
@import Foundation;

@interface KZFunctions: NSObject
+ (NSString*)workspacePath;
+ (void)scrollXcode9TextViewInWindow:(NSWindow *)window toLine:(NSInteger)line;
@end
