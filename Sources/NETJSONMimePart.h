//
//  NETJSONMimePart.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETMimePart.h"

@interface NETJSONMimePart : NETMimePart

- (instancetype)initWithJSONString:(NSString*)jsonString;
- (instancetype)initWithJSONDictionary:(NSDictionary*)jsonDictionary;

@end
