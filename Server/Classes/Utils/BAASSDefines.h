//
//  BAASSDefines.h
//  Pods
//
//  Created by BenArvin on 2022/4/20.
//

#import "NSError+BAASSExtension.h"

#define __weakObjS(var) __weak typeof(var) Weak_##var = var;
#define __strongObjS(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = Weak_##var; \
_Pragma("clang diagnostic pop")

#define BAASSSetPointerValue(target, value) if (target) { *target = value;}

#define BAASSErrorDomain @"BAAppSessionClient"

#define BAASSEasyError(errorCode, errorDesc, ...) ({ \
    NSError *result = [NSError baass_errorWith:BAASSErrorDomain \
                                          code:errorCode \
                                   description:[NSString stringWithFormat:@"[%@ %@]%@", \
                                        [NSString stringWithUTF8String:__FILE__], \
                                        [NSString stringWithUTF8String:__FUNCTION__], \
                                        errorDesc ?: @""] \
                                        causes:__VA_ARGS__];\
    (result); \
})
