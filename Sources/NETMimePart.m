//
//  NETMimePart.m
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETMimePart.h"

#import <objc/runtime.h>

@interface NETMimePart ()

@property (nonatomic, copy) NSString *mimeType;

@end

@implementation NETMimePart

- (instancetype)initWithMimeType:(NSString*)mimeType {
    if (( self = [super init] )) {
        self.mimeType = [mimeType lowercaseString];
    }
    return self;
}

- (void)partDataRepresentationCompletion:(void(^)(NSData*))completion {}

+ (NSArray*)subclasses {
    return @[@"NETJSONMimePart", @"NETImageMimePart"];
}

+ (NSArray*)mimeTypes {
    return @[];
}

+ (id)partFromData:(NSData*)data encoding:(NSStringEncoding)encoding { return nil; }

@end

