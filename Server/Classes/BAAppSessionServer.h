//
//  BAAppSessionServer.h
//  BAAppSession
//
//  Created by BenArvin on 2022/4/14.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BAASSLogLevel) {
    BAASSLogLevelQuite   = 0,
    BAASSLogLevelBrief   = 1,
    BAASSLogLevelDetail  = 2,
    BAASSLogLevelVerbose = 3,
};

extern NSString *const BAASSClientConnectedNotification;
extern NSString *const BAASSClientDisconnectedNotification;
extern NSString *const BAASSNotificationUserInfoKeyClient;

@class BAAppSessionServer;

@protocol BAAppSessionServerObserverProtocol <NSObject>
@optional
- (void)appSession:(BAAppSessionServer *)session onRequest:(NSInteger)reqID client:(NSInteger)client cmd:(NSString *)cmd data:(NSData *)data;

@end

@protocol BAAppSessionServerLogReceiverProtocol <NSObject>
@optional
- (void)appSession:(BAAppSessionServer *)session onLog:(NSString *)log;

@end

@interface BAAppSessionServer : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPort:(uint16_t)port;

- (void)registerObserver:(id <BAAppSessionServerObserverProtocol>)observer forCmd:(NSString *)cmd;
- (void)unregisterObserver:(id <BAAppSessionServerObserverProtocol>)observer forCmd:(NSString *)cmd;
- (void)unregisterObserver:(id <BAAppSessionServerObserverProtocol>)observer;

- (void)start;
- (void)stop;

- (void)response:(NSData *)data to:(NSInteger)client withReqID:(NSInteger)reqID completion:(void(^)(BOOL success, NSError *error))completion;
- (void)push:(NSData *)data to:(NSInteger)client completion:(void(^)(BOOL success, NSError *error))completion;
- (void)broadcast:(NSData *)data completion:(void(^)(void))completion;

- (void)setLogLevel:(BAASSLogLevel)level;
- (void)registerLogReceiver:(id <BAAppSessionServerLogReceiverProtocol>)receiver;
- (void)unregisterLogReceiver:(id <BAAppSessionServerLogReceiverProtocol>)receiver;

@end
