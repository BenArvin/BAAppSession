//
//  BAASCCounter.h
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/24.
//

#import <Foundation/Foundation.h>

@interface BAASCCounter : NSObject

- (instancetype)initWithMin:(long)min max:(long)max;
- (long)next;

@end
