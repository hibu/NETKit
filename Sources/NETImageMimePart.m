//
//  NETImageMimePart.m
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//


#import "NETImageMimePart.h"

@interface NETImageMimePart ()

#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
@property (nonatomic, strong) UIImage *image;
#else
@property (nonatomic, strong) NSImage *image;
#endif
@property (nonatomic, strong) NSURL *imageURL;

@end

@implementation NETImageMimePart

#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
- (instancetype)initWithMimeType:(NSString*)mimeType image:(UIImage*)image {
#else
- (instancetype)initWithMimeType:(NSString*)mimeType image:(NSImage*)image {
#endif
    if (( self = [super initWithMimeType:mimeType] )) {
        self.image = image;
    }
    
    return self;
}

- (instancetype)initWithMimeType:(NSString*)mimeType imageName:(NSString*)imageName {
#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
    return [self initWithMimeType:mimeType image:[UIImage imageNamed:imageName]];
#else
    return [self initWithMimeType:mimeType image:[NSImage imageNamed:imageName]];
#endif
}

- (instancetype)initWithMimeType:(NSString*)mimeType imageURL:(NSURL*)imageURL {
    NETImageMimePart *part = [self initWithMimeType:mimeType image:nil];
    part.imageURL = imageURL;
    return part;
}

- (void)partDataRepresentationCompletion:(void(^)(NSData*))completion {
    
    dispatch_block_t dataConverter = ^{
        if (!self.image) {
            completion(nil);
        } else {
            NSData *image = nil;
            if ([self.mimeType hasSuffix:@"png"]) {
#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
                image = UIImagePNGRepresentation(self.image);
#else
                CGImageRef cgRef = [self.image CGImageForProposedRect:NULL context:nil hints:nil];
                NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
                [imageRep setSize:self.image.size];   // if you want the same resolution
                image = [imageRep representationUsingType:NSPNGFileType properties:nil];
#endif
            } else {
#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
                image = UIImageJPEGRepresentation(self.image, 0.8);
#else
                NSDictionary *props = @{ NSImageCompressionFactor : @0.8};
                CGImageRef cgRef = [self.image CGImageForProposedRect:NULL context:nil hints:nil];
                NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
                image = [imageRep representationUsingType: NSJPEGFileType properties:props];
#endif
            }
            
            if (self.encodeUsingBase64) {
                completion([[image base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength] dataUsingEncoding:NSUTF8StringEncoding]);
            } else {
                completion(image);
            }
        }
    };
    
    if (self.imageURL && !self.image) {
        NSURLSession *session = [NSURLSession sharedSession];
        [session dataTaskWithURL:self.imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && ((NSHTTPURLResponse*)response).statusCode == 200 && data) {
#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
                self.image = [[UIImage alloc] initWithData:data scale:0];
#else
                self.image = [[NSImage alloc] initWithData:data];
#endif
                dataConverter();
            } else {
                completion(nil);
            }
        }];
    } else {
        dataConverter();
    }
}
    
+ (NSArray*)mimeTypes {
    return @[@"image/png", @"image/jpg", @"image/jpeg", @"image/*", @"image/gif"];
}

+ (id)partFromData:(NSData*)data encoding:(NSStringEncoding)encoding {
    if (!data) return nil;
    
#if TARGET_OS_IPHONE | TARGET_OS_SIMULATOR
    return [UIImage imageWithData:data scale:0];
#else
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
    NSSize imageSize = NSMakeSize(CGImageGetWidth([imageRep CGImage]), CGImageGetHeight([imageRep CGImage]));
    NSImage *image = [[NSImage alloc] initWithSize:imageSize];
    [image addRepresentation:imageRep];
    return image;
#endif
}


@end
