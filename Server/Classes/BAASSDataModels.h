//
//  BAASSDataModels.h
//  
//
//  Created by BenArvin on 2022/4/26.
//

#import <Foundation/Foundation.h>
#import "BAASSGCDAsyncSocket.h"

@interface BAASSClientInfo : NSObject

@property (nonatomic) NSInteger ID;
@property (nonatomic) BAASSGCDAsyncSocket *socket;
@property (atomic) NSDate *lastPingTime;

@end

@interface BAASSResponse : NSObject

@property (nonatomic) NSInteger client;
@property (nonatomic) NSInteger resID;
@property (nonatomic) NSMutableArray *slices;
@property (nonatomic) void(^completion)(BOOL success, NSError *error);

@end

@interface BAASSReqSliceTin : NSObject

@property (nonatomic) NSInteger client;
@property (nonatomic) NSInteger reqID;
@property (nonatomic) NSUInteger count;
@property (nonatomic) NSMutableDictionary *packageParts;

- (BOOL)isFull;
- (NSData *)fullPackage;

@end
