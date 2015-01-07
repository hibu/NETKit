//
//  NETImageMimePart.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
@import UIKit;
#else
@import AppKit;
#endif

#import "NETMimePart.h"

@interface NETImageMimePart : NETMimePart

@property (nonatomic, assign) BOOL encodeUsingBase64;

#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
- (instancetype)initWithMimeType:(NSString*)mimeType image:(UIImage*)image;
#else
- (instancetype)initWithMimeType:(NSString*)mimeType image:(NSImage*)image;
#endif
- (instancetype)initWithMimeType:(NSString*)mimeType imageName:(NSString*)imageName;
- (instancetype)initWithMimeType:(NSString*)mimeType imageURL:(NSURL*)imageURL;

@end
