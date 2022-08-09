//
//  BAASCDataModels.h
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/26.
//

#import <Foundation/Foundation.h>

@interface BAASCReqInfo : NSObject

@property (nonatomic) NSInteger reqID;
@property (nonatomic) void(^completion)(BOOL success, NSData *response, NSError *error);
@property (nonatomic) NSDate *startTime;
@property (nonatomic) CGFloat overtime;

- (instancetype)initWithReqID:(long)reqID completion:(void(^)(BOOL success, NSData *response, NSError *error))completion startTime:(NSDate *)startTime overtime:(CGFloat)overtime;

@end

@interface BAASCResSliceTin : NSObject

@property (nonatomic) NSInteger resID;
@property (nonatomic) NSUInteger count;
@property (nonatomic) NSMutableDictionary *packageParts;

- (BOOL)isFull;
- (NSData *)fullPackage;

@end
