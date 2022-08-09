//
//  NSError+BAASSExtension.h
//
//
//  Created by BenArvin on 2020/7/17.
//  Copyright © 2019 BenArvin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (BAASSExtension)

+ (NSError * _Nonnull)baass_errorWith:(NSString * _Nonnull)domain
                                 code:(NSInteger)code
                               causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)baass_errorWith:(NSString * _Nonnull)domain
                                 code:(NSInteger)code
                          description:(NSString * _Nullable)description
                               causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)baass_errorWith:(NSString * _Nonnull)domain
                                 code:(NSInteger)code
                          description:(NSString * _Nullable)description
                               reason:(NSString * _Nullable)reason
                               causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)baass_errorWith:(NSString * _Nonnull)domain
                                 code:(NSInteger)code
                          description:(NSString * _Nullable)description
                               reason:(NSString * _Nullable)reason
                   recoverySuggestion:(NSString * _Nullable)recoverySuggestion
                               causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

@end
