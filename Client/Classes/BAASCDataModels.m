//
//  BAASCDataModels.m
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/26.
//

#import "BAASCDataModels.h"

@implementation BAASCReqInfo

- (instancetype)initWithReqID:(long)reqID completion:(void(^)(BOOL success, NSData *response, NSError *error))completion startTime:(NSDate *)startTime overtime:(CGFloat)overtime {
    self = [self init];
    if (self) {
        _reqID = reqID;
        _completion = completion;
        _startTime = startTime;
        _overtime = overtime;
    }
    return self;
}

@end

@implementation BAASCResSliceTin

- (instancetype)init {
    self = [super init];
    if (self) {
        _packageParts = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)isFull {
    return (self.packageParts.count == self.count);
}

- (NSData *)fullPackage {
    NSMutableData *result = [[NSMutableData alloc] init];
    for (NSInteger i=0; i<self.count; i++) {
        NSData *item = [self.packageParts objectForKey:@(i)];
        if (item) {
            [result appendData:item];
        }
    }
    return result;
}

@end
