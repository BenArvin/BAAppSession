//
//  NSError+BAASSExtension.m
//
//
//  Created by BenArvin on 2020/7/17.
//  Copyright © 2019 BenArvin. All rights reserved.
//

#import "NSError+BAASSExtension.h"

static NSString *const gTASCErrorUnknown = @"Unknown";
static NSString *const gTASCErrorDomainKey = @"Domain";
static NSString *const gTASCErrorCodeKey = @"Code";
static NSString *const gTASCErrorDescriptionKey = @"Description";
static NSString *const gTASCErrorReasonKey = @"Reason";
static NSString *const gTASCErrorSuggestionKey = @"Suggestion";
static NSString *const gTASCErrorCausesKey = @"Causes";

@implementation NSError (BAASSExtension)

+ (NSError *)baass_errorWith:(NSString *)domain code:(NSInteger)code causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self baass_errorWith:domain code:code description:nil reason:nil recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)baass_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self baass_errorWith:domain code:code description:description reason:nil recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)baass_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self baass_errorWith:domain code:code description:description reason:reason recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)baass_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason recoverySuggestion:(NSString *)recoverySuggestion causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self baass_errorWith:domain code:code description:description reason:reason recoverySuggestion:recoverySuggestion causesItems:causesItems];
}

#pragma mark - private methods
+ (NSError *)baass_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason recoverySuggestion:(NSString *)recoverySuggestion causesItems:(NSArray <NSError *> *)causesItems {
    NSString *domainTmp = domain ? domain : gTASCErrorUnknown;
    NSString *desTmp = [self tasc_buildDes:domain code:code des:description];
    
    NSMutableDictionary *fullDic = [[NSMutableDictionary alloc] init];
    [fullDic setObject:domainTmp forKey:gTASCErrorDomainKey];
    [fullDic setObject:@(code) forKey:gTASCErrorCodeKey];
    if (description) {
        [fullDic setObject:description forKey:gTASCErrorDescriptionKey];
    }
    if (reason) {
        [fullDic setObject:reason forKey:gTASCErrorReasonKey];
    }
    if (recoverySuggestion) {
        [fullDic setObject:recoverySuggestion forKey:gTASCErrorSuggestionKey];
    }
    
    NSMutableArray *causeDics = nil;
    for (NSError *item in causesItems) {
        if (!causeDics) {
            causeDics = [[NSMutableArray alloc] init];
        }
        [causeDics addObject:[self baass_toDic:item]];
    }
    if (causeDics) {
        [fullDic setObject:causeDics forKey:gTASCErrorCausesKey];
    }
    NSString *fullStr = [self baass_toJsonStr:fullDic];
    return [NSError errorWithDomain:domainTmp code:code userInfo:@{
        NSLocalizedDescriptionKey: desTmp,
        NSLocalizedFailureReasonErrorKey: fullStr,
        NSLocalizedRecoverySuggestionErrorKey: fullStr
    }];
}

+ (NSString *)baass_toJsonStr:(NSDictionary *)dic {
    if (!dic) {
        return nil;
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData || error) {
        return nil;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (id)baass_toDic:(NSError *)error {
    NSString *reason = [error localizedFailureReason];
    if (!reason) {
        reason = [self tasc_buildDes:error.domain code:error.code des:error.localizedDescription];
    }
    NSError *errorTmp;
    id result = [NSJSONSerialization JSONObjectWithData:[reason dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&errorTmp];
    return errorTmp ? reason : (NSDictionary *)result;
}

+ (NSString *)tasc_buildDes:(NSString *)domain code:(NSInteger)code des:(NSString *)des {
    return [NSString stringWithFormat:@"[%@-%ld] %@", domain?:gTASCErrorUnknown, (long)code, des?:gTASCErrorUnknown];
}

@end
