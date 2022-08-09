//
//  BAASSCounter.m
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/24.
//

#import "BAASSCounter.h"

@interface BAASSCounter() {
}

@property (atomic) long min;
@property (atomic) long max;
@property (atomic) long cur;

@end

@implementation BAASSCounter

- (instancetype)initWithMin:(long)min max:(long)max {
    self = [self init];
    if (self) {
        _min = min;
        _max = max;
        _cur = min;
    }
    return self;
}

- (long)next {
    if (self.cur >= self.max) {
        self.cur = self.max;
    }
    long result = self.cur;
    self.cur++;
    return result;
}

@end
