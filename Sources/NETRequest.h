//
//  NETRequest.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

@import Foundation;

#import "NETMimePart.h"

@class NETIntent;

extern NSString * const NETRequestDidStartNotification;
extern NSString * const NETRequestDidEndNotification;

@interface NETRequest : NSObject

@property (nonatomic, readonly) NSURLSession *session;
@property (nonatomic, readonly) NSUInteger uid;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong, readonly) NSURLComponents *builder;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, strong) NETMimePart *body;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, readonly, getter=isExecuting) BOOL executing;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, assign) BOOL completesOnBackgroundThread;
@property (nonatomic, assign, getter=isQuiet) BOOL quiet;

// create a request
+ (instancetype)request;
+ (instancetype)requestWithSession:(NSURLSession*)session;

// build URL
- (void)urlBuilder:(void (^)(NSURLComponents *builder))builderBlock;

// setting query / headers
- (void)setQuery:(NSDictionary*)parameters;
- (void)addQueryEntriesFromDictionary:(NSDictionary*)additionalParameters;
- (void)addHeaderEntriesFromDictionary:(NSDictionary*)additionalHeaders;

// start / cancel request
- (void)startRequestWithCompletion:(void(^)(id object, NSHTTPURLResponse *response, NSError *error))completion;
- (void)cancel;

@end

@interface NETRequest (Intents)

+ (instancetype)requestWithIntent:(NETIntent*)intent;
+ (instancetype)requestWithIntent:(NETIntent*)intent flags:(NSDictionary*)flags;

@end

@protocol NETIntentProviderProtocol <NSObject>

@required

// Always creates and returns a new session.
// Will never be called twice for the same intent. Will be called once for
// every detached intent.
- (NSURLSession*)sessionCreatedForIntent:(NETIntent*)intent;

@optional

// Called after the -startRequestWithCompletion: method is called.
// Will be called on a background thread
- (void)configureRequest:(NETRequest*)request
                  intent:(NETIntent*)intent
                   flags:(NSDictionary*)flags;

// Called after the -startRequestWithCompletion: method is called.
// Will be called on a background thread, just before creating the data task. This is the place to add security headers or parameters.
- (void)configureURLRequest:(NSMutableURLRequest *)request
                     intent:(NETIntent*)intent
                      flags:(NSDictionary*)flags;

// Use this control point if you want to enqueue or pause requests.
// Execute the block on any thread to resume the request. The optional completionBlk you pass in will get executed on a background queue
// as soon as the response is available.
- (void)controlPointBlock:(void (^)(dispatch_block_t completionBlk))block intent:(NETIntent*)intent;

@end

@interface NETIntent : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) NSUInteger uid;
@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, assign) BOOL finishTasksAndInvalidateSessionOnDealloc;

+ (instancetype)intentWithName:(NSString*)name
                            provider:(id <NETIntentProviderProtocol>)provider;

/*
 Typical use of detached intents is to store them in a property of your
 View Controlers. When they get released, so will the detached intent.
 It will call invalidateAndCancel on its session in its dealloc method.
 You can set the finishTasksAndInvalidateSessionOnDealloc flag if you want your tasks
 to finish.
*/
- (instancetype)detachedIntent;

@end
