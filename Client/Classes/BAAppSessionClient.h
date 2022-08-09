//
//  BAAppSessionClient.h
//  BAAppSession
//
//  Created by BenArvin on 2022/4/14.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BAASCLogLevel) {
    BAASCLogLevelQuite   = 0,
    BAASCLogLevelBrief   = 1,
    BAASCLogLevelDetail  = 2,
    BAASCLogLevelVerbose = 3,
};

@class BAAppSessionClient;

@protocol BAAppSessionClientDelegate <NSObject>
@optional
- (void)appSessionConnected:(BAAppSessionClient *)session;
- (void)appSessionDisconnected:(BAAppSessionClient *)session;
- (void)appSession:(BAAppSessionClient *)session onPushReceived:(NSData *)data;
- (void)appSessionLog:(NSString *)log;

@end

@interface BAAppSessionClient : NSObject

@property (nonatomic, weak) id<BAAppSessionClientDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPort:(uint16_t)port;

- (void)connect;
- (void)disconnect;
- (BOOL)isConnected;

- (void)request:(NSString *)cmd data:(NSData *)data completion:(void(^)(BOOL success, NSData *response, NSError *error))completion;
- (void)request:(NSString *)cmd data:(NSData *)data overtime:(NSInteger)overtime completion:(void(^)(BOOL success, NSData *response, NSError *error))completion;

- (void)setLogLevel:(BAASCLogLevel)level;

@end
