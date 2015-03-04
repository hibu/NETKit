//
//  NETRequest.h
//  NetKit
//
//  Created by Marc Palluat de Besset on 16/12/2014.
//  Copyright (c) 2014 hibu. All rights reserved.
//

@import Foundation;

#import "NETMimePart.h"

/* Uncomment the following define to log the raw response data in all NETRequests */
//#define NETRequest_logRawResponseData 1

@class NETIntent;

extern NSString * const NETRequestDidStartNotification;
extern NSString * const NETRequestDidEndNotification;

/*
 NETRequest is a wrapper around NSURLSession and its dataTasks. It makes things easy, while still providing access to the underliying
 NSURL... objects. Typical use is as follow:
 
 NETRequest *request = [NETRequest request];
 request urlBuilder:^(NSURLComponents *builder) {
    builder.path = @"/maps/api/geocode/json";
    builder.host = @"maps.googleapis.com";
    builder.port = 443;
    builder.scheme = @"https";
    builder.query = @{@"sensor" : @"true", @"latlng" : latlon};
 };
 request.headers = @{@"Accept" : @"application/json"};
 
 [request startRequestWithCompletion:^(NSDictionary *json, NSHTTPURLResponse *response, NSError *error) {
 
 }];
 
*/
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
@property (nonatomic, assign) BOOL logRawResponseData;

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
- (NSError*)configureRequest:(NETRequest*)request
                  intent:(NETIntent*)intent
                   flags:(NSDictionary*)flags;

// Called after the -startRequestWithCompletion: method is called.
// Will be called on a background thread, just before creating the data task. This is the place to add security headers or parameters.
- (NSError*)configureURLRequest:(NSMutableURLRequest *)request
                     intent:(NETIntent*)intent
                      flags:(NSDictionary*)flags
                    request:(NETRequest*)netRequest;

// Use this control point if you want to enqueue or pause requests.
// Execute the block on any thread to resume the request. The optional completionBlk you pass in will get executed on a background queue
// as soon as the response is available.
- (void)controlPointBlock:(void (^)(dispatch_block_t completionBlk))block intent:(NETIntent*)intent;

- (BOOL)receivedObject:(id*)object data:(NSData*)data response:(NSHTTPURLResponse**)response error:(NSError**)error intent:(NETIntent*)intent;

- (NSCharacterSet*)queryParametersAllowedCharacterSetForIntent:(NETIntent*)intent;

@end


/*
 Intents (not a good name, sorry) are used to easily configure NETRequests for talking to a particular API.
 Its delegate which conforms to the <NETIntentProviderProtocol> protocol provides a configured NSURLSession, and implements optionally some callbacks for late additions of parameters, security, ...
*/
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
