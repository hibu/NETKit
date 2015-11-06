//
//  NETRequest.m
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

#import "NETRequest.h"

static NSUInteger gUID = 0;
NSString * const NETRequestDidStartNotification = @"NETRequestDidStartNotification";
NSString * const NETRequestDidEndNotification = @"NETRequestDidEndNotification";

@interface NETIntent ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSUInteger uid;
@property (nonatomic, assign) NSUInteger detached_uid;
@property (nonatomic, strong, readonly) NSURLSession *session;
@property (nonatomic, strong) id <NETIntentProviderProtocol> provider;

@end

@interface NETRequest ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, assign) NSUInteger uid;
@property (nonatomic, strong) NSURLComponents *builder;
@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, weak) NETIntent *intent;
@property (nonatomic, strong) NSDictionary *intentFlags;

@end

@implementation NETRequest

#pragma mark - init / dealloc

+ (instancetype)requestWithSession:(NSURLSession*)session {
    return [[[self class] alloc] initWithSession:session];
}

+ (instancetype)request {
    return [[[self class] alloc] initWithSession:NSURLSession.sharedSession];
}

- (instancetype)initWithSession:(NSURLSession*)session {
    if (( self = [super init] )) {
        _session = session;
        _method = @"GET";
        @synchronized(self.class) {
            _uid = ++gUID;
        }
#ifndef DEBUG
        _quiet = YES;
#endif

#ifdef NETRequest_logRawResponseData
        _logRawResponseData = YES;
#endif
    }
    return self;
}

- (void)dealloc {
    if (!self.quiet) {
        NSLog(@"%@ - dealloc", self.description);
    }
}

#pragma mark - getters / setters

- (void)setMethod:(NSString *)method {
    _method = [method.uppercaseString copy];
}

- (NSURLComponents*)builder {
    if (!_builder) {
        _builder = [[NSURLComponents alloc] init];
        
        if (!self.urlString) {
            self.builder.scheme = @"http";
            self.builder.port = @80;
        }
    }
    return _builder;
}

- (void)urlBuilder:(void (^)(NSURLComponents *builder))builderBlock {
    builderBlock(self.builder);
}

- (NSString*)urlString {
    if (_builder) return _builder.URL.absoluteString;
    return nil;
}

- (void)setUrlString:(NSString *)urlString {
    self.url = [NSURL URLWithString:urlString];
}

- (NSURL*)url {
    if (_builder) return _builder.URL;
    return nil;
}

- (void)setUrl:(NSURL *)url {
    _builder = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
}


- (void)setQuery:(NSDictionary*)parameters {
    self.builder.query = nil;
    [self addQueryEntriesFromDictionary:parameters];
}

- (void)addQueryEntriesFromDictionary:(NSDictionary*)parameters {
    NSMutableArray *mItems = [NSMutableArray new];
    
    NSCharacterSet *allowedCharacters = [NETRequest URLQueryParameterPartAllowedCharacterSet];
    if ([self.intent.provider respondsToSelector:@selector(queryParametersAllowedCharacterSetForIntent:)]) {
        allowedCharacters = [self.intent.provider queryParametersAllowedCharacterSetForIntent:self.intent];
    }

    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self stringifyObject:obj usingBlock:^(NSString *value) {
            NSString *theKey = [key stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
            NSString *theValue = [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
            [mItems addObject:@{ theKey : theValue }];
        }];
    }];
    
    NSMutableString *mString = [NSMutableString string];
    [mItems enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        if (idx > 0) [mString appendString:@"&"];
        NSString *key = item.allKeys.firstObject;
        [mString appendString:key];
        [mString appendString:@"="];
        [mString appendString:item[key]];
    }];
    
    NSString *query = self.builder.percentEncodedQuery;
    if (query && query.length > 0) {
        self.builder.percentEncodedQuery = [query stringByAppendingFormat:@"&%@", mString];
    } else self.builder.percentEncodedQuery = mString;
}

- (void)addHeaderEntriesFromDictionary:(NSDictionary*)additionalHeaders {
    self.headers = [self addEntriesFromDictionary:additionalHeaders toDictionary:self.headers];
}

#pragma mark - start / cancel

- (void)startRequestWithCompletion:(void(^)(id object, NSHTTPURLResponse *response, NSError *error))completion {
    NSAssert(completion, @"completion cannot be nil");
    
    if (self.executing) {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:nil];
        [self completeWithObject:nil data:nil response:nil error:error completion:completion];
        return;
    }
    
    void (^workBlock)(dispatch_block_t completionBlk) = ^ (dispatch_block_t completionBlk) {
    
        dispatch_block_t mainThreadBlock = ^{
            
            if (self.cancelled) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self completeWithObject:nil data:nil response:nil error:error completion:completion];
                return;
            }
            
            self.executing = YES;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                if (self.intent && [self.intent.provider respondsToSelector:@selector(configureRequest:intent:flags:)]) {
                    NSError *error = [self.intent.provider configureRequest:self intent:self.intent flags:self.intentFlags];
                    if (error) {
                        [self completeWithObject:nil data:nil response:nil error:error completion:completion];
                        return;
                    }
                }

                [self urlRequestCompletion:^(NSMutableURLRequest *request) {
                    
                    if (self.intent && [self.intent.provider respondsToSelector:@selector(configureURLRequest:intent:flags:request:)]) {
                        NSError *error = [self.intent.provider configureURLRequest:request intent:self.intent flags:self.intentFlags request:self];
                        if (error) {
                            [self completeWithObject:nil data:nil response:nil error:error completion:completion];
                            return;
                        }
                    }
                    
                    if (!self.isQuiet) {
                        NSString *description = self.intent ? self.intent.fullName : (self.session.sessionDescription ?: (self.session == [NSURLSession sharedSession] ? @"shared session" : @""));
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSLog(@"\n");
                            NSLog(@"****** %@ REQUEST #%ld %@ ******", self.method, (unsigned long)self.uid, description);
                            NSLog(@"URL = %@", self.url);
                            NSLog(@"Headers = %@", self.headers);
                            NSLog(@"****** \\REQUEST #%ld ******", (unsigned long)self.uid);
                            NSLog(@"\n");
                        });
                    }
                    
                    @try {
                        self.dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NETRequestDidEndNotification object:self];
                            });
                            
                            NSHTTPURLResponse *httpResponse = (id)response;
                            
                            if (completionBlk) {
                                completionBlk();
                            }
                            
                            if (self.cancelled || self.dataTask.state == NSURLSessionTaskStateCanceling) {
                                NSError *cancelError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                                [self completeWithObject:nil data:nil response:nil error:cancelError completion:completion];
                                return;
                            }
                            
                            // We dispatch async to not block the networking serial queue
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                id result = nil;
                                
                                if (!error && httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                                    result = [self convertData:data contentType:httpResponse.allHeaderFields[@"Content-Type"]];
                                }
                                
                                if (!self.isQuiet) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        BOOL logRaw = NO;
                                        NSLog(@"\n");
                                        NSLog(@"****** RESPONSE #%ld status: %ld ******", (unsigned long)self.uid, (long)httpResponse.statusCode);
                                        NSLog(@"URL = %@", self.url);
                                        NSLog(@"Headers = %@", httpResponse.allHeaderFields);
                                        if (error) {
                                            NSLog(@"Error = %@", error);
                                        }
                                        
                                        NSString *contentEncoding = httpResponse.allHeaderFields[@"Content-Encoding"];
                                        NSUInteger size = [httpResponse.allHeaderFields[@"Content-Length"] intValue];
                                        
                                        if (size == 0) {
                                            size = data.length;
                                        }
                                        
                                        NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
                                        NSString *sizeString = [formatter stringFromByteCount:size];
                                        
                                        if (contentEncoding) {
                                            sizeString = [NSString stringWithFormat:@"%@ %@", contentEncoding, sizeString];
                                        }
                                        
                                        if (result) NSLog(@"Body (%@) = %@", sizeString, result);
                                        else logRaw = YES;
                                        if ((self.logRawResponseData || logRaw) && data) {
                                            NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                            if (dataStr) {
                                                NSLog(@"Body (raw, %@) = %@", sizeString, dataStr);
                                            } else {
                                                NSLog(@"Body (raw, %@) = %@", sizeString, data);
                                            }
                                        }
                                        NSLog(@"****** \\RESPONSE #%ld ******", (unsigned long)self.uid);
                                        NSLog(@"\n");
                                    });
                                }
                                
                                self.executing = NO;
                                self.dataTask = nil;
                                
                                [self completeWithObject:result data:data response:httpResponse error:error completion:completion];
                            });
                        }];

                    }
                    @catch (NSException *exception) {
                        // session is invalid, cannot create a data task.
                        self.dataTask = nil;
                    }
                    
                    if (!self.dataTask) {
                        NSError *cancelError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                        [self completeWithObject:nil data:nil response:nil error:cancelError completion:completion];
                        return;
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NETRequestDidStartNotification object:self];
                        });

                        [self.dataTask resume];
                    }

                }];
            });
        };
        
        if ([NSThread mainThread]) {
            mainThreadBlock();
        } else {
            dispatch_async(dispatch_get_main_queue(), mainThreadBlock);
        }
        
    };
        
    if (self.intent && [self.intent.provider respondsToSelector:@selector(controlPointBlock:intent:)]) {
        [self.intent.provider controlPointBlock:workBlock intent:self.intent];
    } else {
        workBlock(nil);
    }
}

- (void)cancel {
    self.cancelled = YES;
    [self.dataTask cancel];
}

- (void)completeWithObject:(id)object data:data response:(NSHTTPURLResponse*)response error:(NSError*)error completion:(void(^)(id object, NSHTTPURLResponse *response, NSError *error))completion {
    
    id theObject = object;
    NSHTTPURLResponse *theResponse = response;
    NSError *theError = error;
    
    if ([self.intent.provider respondsToSelector:@selector(receivedObject:data:response:error:intent:)]) {
        (void)[self.intent.provider receivedObject:&theObject data:data response:&theResponse error:&theError intent:self.intent];
    }
    
    if ([NSThread isMainThread]) {
        if (self.completesOnBackgroundThread) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(theObject, theResponse, theError);
            });
        } else {
            completion(theObject, theResponse, theError);
        }
    } else {
        if (self.completesOnBackgroundThread) {
            completion(theObject, theResponse, theError);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(theObject, theResponse, theError);
            });
        }
    }
    
}

#pragma mark - helpers

- (void)urlRequestCompletion:(void(^)(NSMutableURLRequest*))completion {
    dispatch_group_t group = dispatch_group_create();
    NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:self.url];
    mRequest.HTTPMethod = self.method;
    
    if (self.body) {
        dispatch_group_enter(group);
        [self.body partDataRepresentationCompletion:^(NSData *data) {
            mRequest.HTTPBody = data;
            [mRequest setValue:[NSString stringWithFormat:@"%ld", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
            [mRequest setValue:self.body.mimeType forHTTPHeaderField:@"Content-Type"];
            dispatch_group_leave(group);
        }];
    }
    
    [self.headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [mRequest setValue:obj forHTTPHeaderField:key];
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion(mRequest);
    });
}

- (void)stringifyObject:(id)object usingBlock:(void(^)(NSString *value))block {
    if ([object isKindOfClass:NSString.class]) {
        block(object);
    } else if ([object isKindOfClass:NSNumber.class]) {
        block([object stringValue]);
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id obj in object) {
            [self stringifyObject:obj usingBlock:block];
        }
    }
}

- (NSDictionary*)addEntriesFromDictionary:(NSDictionary*)fromDictionary toDictionary:(NSDictionary*)toDictionary {
    if (toDictionary && fromDictionary) {
        NSMutableDictionary *params = [toDictionary mutableCopy];
        [params addEntriesFromDictionary:fromDictionary];
        return [params copy];
    }
    return fromDictionary ? fromDictionary : toDictionary;
}

- (id)convertData:(NSData*)data contentType:(NSString*)contentType {
    NSArray *components = [contentType componentsSeparatedByString:@";"];
    NSString *type = [components.firstObject lowercaseString];
    components = [components.lastObject componentsSeparatedByString:@"="];
    NSString *charset = [components.firstObject isEqualToString:@"charset"] ? components.lastObject : nil;
    NSStringEncoding encoding = NSUTF8StringEncoding;
    
    if (charset) {
        CFStringEncoding coding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef) charset);
        encoding = CFStringConvertEncodingToNSStringEncoding(coding);
    }
    
    if ([type isEqualToString:@"text/html"]) {
        return [[NSString alloc] initWithData:data encoding:encoding];
    }
    
    for (Class class in NETMimePart.subclasses) {
        
        for (NSString *mimeType in [class mimeTypes]) {
            if ([mimeType isEqualToString:type]) {
                return [class partFromData:data encoding:encoding];
            }
        }
    }
    
    return data;
}

+ (NSCharacterSet*)URLQueryParameterPartAllowedCharacterSet {
    static NSCharacterSet *set = nil;
    
    if (!set) {
        NSMutableCharacterSet *mset = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [mset removeCharactersInString:@"?&="];
        set = [mset copy];
    }
    return set;
}

@end



@implementation NETRequest (NETIntent)

#pragma mark - Intents

+ (instancetype)requestWithIntent:(NETIntent*)intent flags:(NSDictionary*)flags {
    NETRequest *request = [NETRequest requestWithSession:intent.session];
    request.intent = intent;
    request.intentFlags = flags;
    return request;
}

+ (instancetype)requestWithIntent:(NETIntent*)intent {
    return [self requestWithIntent:intent flags:nil];
}

@end



@implementation NETIntent

@synthesize session = _session;

+ (instancetype)intentWithName:(NSString*)name
                      provider:(id <NETIntentProviderProtocol>)provider {
    return [[self.class alloc] initWithName:name uid:0 provider:provider];
}

- (instancetype)initWithName:(NSString*)name uid:(NSUInteger)uid provider:(id <NETIntentProviderProtocol>)provider {
    if (( self = [super init] )) {
        self.name = name;
        self.uid = uid;
        self.provider = provider;
    }
    return self;
}

- (void)dealloc {
    if (self.finishTasksAndInvalidateSessionOnDealloc) {
        [_session finishTasksAndInvalidate];
    } else {
        [_session invalidateAndCancel];
    }
    NSLog(@"NETIntent %@ - dealloc", self.fullName);
}

- (NSString *)fullName {
    if (self.uid) {
        return [NSString stringWithFormat:@"%@ - %ld", self.name, (unsigned long)self.uid];
    }
    return self.name;
}

- (instancetype)detachedIntent {
    NETIntent *intent = nil;
    if (self.uid == 0) {
        @synchronized(self) {
            self.detached_uid++;
            intent = [[self.class alloc] initWithName:self.name uid:self.detached_uid provider:self.provider];
        }
    }
    
    return intent;
}

- (NSURLSession*)session {
    if (!_session) {
        _session = [self.provider sessionCreatedForIntent:self];
    }
    return _session;
}

@end


