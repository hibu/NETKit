//
//  NETMimeMultipart.m
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETMimeMultipart.h"

static char MULTIPART_CHARS[] = "-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

static long RandomNumberBetween(long start, long end) {
    long min = MIN( start, end );
    long max = MAX( start, end ) + 1;
    double randValue = (double)arc4random() / (1.0 + (double)UINT32_MAX);
    return (long)((max - min) * randValue + min);
}

@interface NETMimeMultipart ()

@property (nonatomic, copy, readonly) NSString *boundary;
@property (nonatomic, strong) NSArray *parts;

@end

@implementation NETMimeMultipart

@synthesize boundary = _boundary;

- (NSString*)boundary {
    if (!_boundary) {
        unsigned long MULTIPART_CHARS_LEN = strlen(MULTIPART_CHARS);
        NSUInteger count = RandomNumberBetween(30, 40);
        _boundary = @"";
        char car[2] = " \0";
        for (NSUInteger i = 0; i < count; i++) {
            car[0] = MULTIPART_CHARS[RandomNumberBetween(0, MULTIPART_CHARS_LEN - 1)];
            _boundary = [_boundary stringByAppendingString:[NSString stringWithCString:car encoding:NSUTF8StringEncoding]];
        }
    }
    
    return _boundary;
}

- (instancetype)initWithMimeType:(NSString*)mimeType parts:(NSArray*)parts {
    if (( self = [super initWithMimeType:mimeType] )) {
        self.parts = parts;
    }
    return self;
}

- (NSString*)mimeType {
    return [NSString stringWithFormat:@"%@; boundary=%@", [super mimeType], self.boundary];
}

- (void)partDataRepresentationCompletion:(void(^)(NSData*))completion {
    if (!self.parts || self.parts.count == 0) {
        completion(nil);
    }
    
    __block NSMutableData *content = [[NSMutableData alloc] init];
    [content appendData:[[NSString stringWithFormat:@"--%@\r\n",self.boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [self.parts enumerateObjectsUsingBlock:^(NETMimePart *part, NSUInteger idx, BOOL *stop) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (part.headers) {
                    [part.headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop2) {
                        [content appendData:[[NSString stringWithFormat:@"%@: %@\r\n", key, value] dataUsingEncoding:NSUTF8StringEncoding]];
                    }];
                }
                [content appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", part.mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
                [part partDataRepresentationCompletion:^(NSData *data) {
                    if (data) {
                        [content appendData:data];
                    } else {
                        NSLog(@"*** unable to get data from part %@ ***", part);
                    }
                    dispatch_group_leave(group);
                }];
                
                [content appendData:[[NSString stringWithFormat:@"\r\n--%@%@\r\n", self.boundary, idx == self.parts.count - 1 ? @"--" : @""] dataUsingEncoding:NSUTF8StringEncoding]];
            });
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(content);
        });
    });
}




@end
