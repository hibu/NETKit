//
//  NETJSONMimePart.m
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETJSONMimePart.h"

@interface NETJSONMimePart ()

@property (nonatomic, copy) NSData *jsonData;

@end

@implementation NETJSONMimePart

- (instancetype)initWithJSONData:(NSData*)jsonData {
    if (( self = [super initWithMimeType:@"application/json"] )) {
        self.jsonData = jsonData;
    }
    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary*)jsonDictionary {
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:NSJSONWritingPrettyPrinted error:nil];
    return [self initWithJSONData:data];
}

- (instancetype)initWithJSONString:(NSString *)jsonString {
    return [self initWithJSONData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)partDataRepresentationCompletion:(void(^)(NSData*))completion {
    completion(self.jsonData);
}

+ (NSArray*)mimeTypes {
    return @[@"application/json", @"application/x-javascript", @"text/javascript", @"text/x-javascript", @"text/x-json"];
}

+ (id)partFromData:(NSData*)data encoding:(NSStringEncoding)encoding {
    if (data) {
        return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    }
    return nil;
}

@end
