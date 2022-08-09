//
//  BAASSDataModels.m
//
//
//  Created by BenArvin on 2022/4/26.
//

#import "BAASSDataModels.h"

@implementation BAASSClientInfo

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

@end

@implementation BAASSResponse

@end

@implementation BAASSReqSliceTin

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
