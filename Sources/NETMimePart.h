//
//  NETMimePart.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

@import Foundation;

@interface NETMimePart : NSObject // ABSTRACT CLASS

@property (nonatomic, copy, readonly) NSString *mimeType;
@property (nonatomic, strong) NSDictionary *headers; // ContentDisposition, ...

- (instancetype)initWithMimeType:(NSString*)mimeType;
- (void)partDataRepresentationCompletion:(void(^)(NSData*))completion; // needs to be overriden by subclasses

+ (NSArray*)subclasses;
+ (NSArray*)mimeTypes;
+ (id)partFromData:(NSData*)data encoding:(NSStringEncoding)encoding;

@end

