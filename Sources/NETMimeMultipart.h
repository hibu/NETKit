//
//  NETMimeMultipart.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETMimePart.h"

@interface NETMimeMultipart : NETMimePart

// mime types are: multipart/mixed, multipart/alternative, multipart/digest, multipart/parallel
- (instancetype)initWithMimeType:(NSString*)mimeType parts:(NSArray*)parts;

@end
