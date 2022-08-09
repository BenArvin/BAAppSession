//
//  BAASCDefines.h
//  Pods
//
//  Created by BenArvin on 2022/4/20.
//

#import "NSError+BAASCExtension.h"

#define __weakObjC(var) __weak typeof(var) Weak_##var = var;
#define __strongObjC(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = Weak_##var; \
_Pragma("clang diagnostic pop")

#define BAASCSetPointerValue(target, value) if (target) { *target = value;}

#define BAASCErrorDomain @"BAAppSessionClient"

#define BAASCEasyError(errorCode, errorDesc, ...) ({ \
    NSError *result = [NSError baasc_errorWith:BAASCErrorDomain \
                                          code:errorCode \
                                   description:[NSString stringWithFormat:@"[%@ %@]%@", \
                                        [NSString stringWithUTF8String:__FILE__], \
                                        [NSString stringWithUTF8String:__FUNCTION__], \
                                        errorDesc ?: @""] \
                                        causes:__VA_ARGS__];\
    (result); \
})
