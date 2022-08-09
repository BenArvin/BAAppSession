//
//  BAASCDataWorkshop.m
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/20.
//

#import "BAASCDataWorkshop.h"
#import "BAASCDefines.h"

#define BAASC_SLICE_LEN (1024.0 * 10.0)

static NSString *const gBAASCPackageKeyCmd = @"cmd";
static NSString *const gBAASCPackageKeyType = @"type";
static NSString *const gBAASCPackageKeyClient = @"client";
static NSString *const gBAASCPackageKeyData = @"data";
static NSString *const gBAASCPackageKeyReqID = @"reqID";
static NSString *const gBAASCPackageTypeStrReq = @"req";
static NSString *const gBAASCPackageTypeStrRes = @"res";
static NSString *const gBAASCPackageTypeStrPush = @"pus";
static NSString *const gBAASCPackageTypeStrPing = @"pin";
static NSString *const gBAASCPackageTypeStrUnk = @"unk";

@implementation BAASCDataWorkshop

+ (BOOL)encodeReqPackage:(NSString *)cmd data:(NSData *)data package:(NSData **)package error:(NSError **)error {
    if (cmd.length <= 0) {
        BAASCSetPointerValue(error, BAASCEasyError(10001, @"invalid cmd", nil));
        return NO;
    }
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary: @{
        gBAASCPackageKeyCmd: cmd,
        gBAASCPackageKeyType: gBAASCPackageTypeStrReq
    }];
    NSString *dataStr = [data base64EncodedStringWithOptions:kNilOptions];
    if (dataStr) {
        [dic setObject:dataStr forKey:gBAASCPackageKeyData];
    }
    NSError *jsonError = nil;
    NSData *resultTmp = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&jsonError];
    if (jsonError) {
        BAASCSetPointerValue(error, BAASCEasyError(10002, @"convert package dic to data failed", jsonError, nil));
        return NO;
    }
    if (resultTmp.length <= 0) {
        BAASCSetPointerValue(error, BAASCEasyError(10003, @"package data is null", nil));
        return NO;
    }
    BAASCSetPointerValue(package, resultTmp);
    return YES;
}

+ (BOOL)encodePinPackage:(NSData **)package error:(NSError **)error {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary: @{
        gBAASCPackageKeyType: gBAASCPackageTypeStrPing
    }];
    NSError *jsonError = nil;
    NSData *resultTmp = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&jsonError];
    if (jsonError) {
        BAASCSetPointerValue(error, BAASCEasyError(30001, @"convert package dic to data failed", jsonError, nil));
        return NO;
    }
    if (resultTmp.length <= 0) {
        BAASCSetPointerValue(error, BAASCEasyError(30002, @"package data is null", nil));
        return NO;
    }
    BAASCSetPointerValue(package, resultTmp);
    return YES;
}

+ (BOOL)decodePackage:(NSData *)package type:(BAASCPackageType *)type reqID:(NSInteger *)reqID client:(NSInteger *)client data:(NSData **)data error:(NSError **)error {
    if (package.length <= 0) {
        BAASCSetPointerValue(error, BAASCEasyError(20001, @"invalid package", nil));
        return NO;
    }
    NSError *jsonError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:package options:kNilOptions error:&jsonError];
    if (jsonError) {
        BAASCSetPointerValue(error, BAASCEasyError(20002, @"conver package data to json obj failed", jsonError, nil));
        return NO;
    }
    if (![obj isKindOfClass:[NSDictionary class]]) {
        BAASCSetPointerValue(error, BAASCEasyError(20003, @"package obj is not dic", nil));
        return NO;
    }
    NSDictionary *dic = (NSDictionary *)obj;
    
    BAASCSetPointerValue(type, [self packageTypeFromStr:[dic objectForKey:gBAASCPackageKeyType]]);
    
    NSInteger clientTmp = -1;
    id clientObj = [dic objectForKey:gBAASCPackageKeyClient];
    if ([clientObj isKindOfClass:[NSNumber class]]) {
        clientTmp = ((NSNumber *)clientObj).integerValue;
    }
    BAASCSetPointerValue(client, clientTmp);
    
    NSInteger reqIDTmp = -1;
    id reqIDObj = [dic objectForKey:gBAASCPackageKeyReqID];
    if ([reqIDObj isKindOfClass:[NSNumber class]]) {
        reqIDTmp = ((NSNumber *)reqIDObj).integerValue;
    }
    BAASCSetPointerValue(reqID, reqIDTmp);
    
    NSString *dataStr = [dic objectForKey:gBAASCPackageKeyData];
    if (dataStr) {
        BAASCSetPointerValue(data, [[NSData alloc] initWithBase64EncodedString:dataStr options:kNilOptions]);
    } else {
        BAASCSetPointerValue(data, nil);
    }
    return YES;
}

+ (NSInteger)sliceHeaderLength {
    return sizeof(int64_t);
}

+ (NSArray <NSData *> *)cutPackageIntoSlices:(NSInteger)reqID package:(NSData *)package {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (package.length <= 0) {
        return result;
    }
    NSUInteger fullLen = package.length;
    NSUInteger count = ceil(fullLen / BAASC_SLICE_LEN);
    NSUInteger pos = 0;
    NSUInteger index = 0;
    while (YES) {
        if (pos >= fullLen) {
            break;
        }
        NSUInteger size = BAASC_SLICE_LEN;
        if (pos + size > fullLen) {
            size = fullLen - pos;
        }
        if (size <= 0) {
            break;
        }
        NSData *slice = [package subdataWithRange:NSMakeRange(pos, size)];
        [result addObject:[self assembleSlice:reqID count:count index:index data:slice]];
        pos = pos + size;
        index++;
    }
    return result;
}

+ (NSInteger)disassembleSliceHeader:(NSData *)header {
    int32_t lenDataLen = sizeof(int64_t);
    if (lenDataLen > header.length) {
        return -1;
    }
    NSData *lenData = [header subdataWithRange:NSMakeRange(0, lenDataLen)];
    int64_t result = 0;
    [lenData getBytes:&result length:lenDataLen];
    return result;
}

+ (BOOL)disassembleSliceBody:(NSData *)body reqID:(NSInteger *)reqID count:(NSUInteger *)count index:(NSUInteger *)index data:(NSData **)data {
    int32_t dataStartLen = sizeof(int32_t);
    int32_t keyLen = sizeof(int32_t);
    int32_t countLen = sizeof(int32_t);
    int32_t indexLen = sizeof(int32_t);
    int32_t minLen = dataStartLen + keyLen + countLen + indexLen;
    if (body.length < minLen) {
        return NO;
    }
    NSUInteger pos = 0;
    NSData *dataStartData = [body subdataWithRange:NSMakeRange(pos, dataStartLen)];
    int32_t dataStart = 0;
    [dataStartData getBytes:&dataStart length:dataStartLen];
    pos = pos + dataStartLen;
    if (dataStart >= body.length) {
        return NO;
    }
    NSData *keyData = [body subdataWithRange:NSMakeRange(pos, keyLen)];
    NSInteger keyTmp = 0;
    [keyData getBytes:&keyTmp length:keyLen];
    pos = pos + keyLen;
    BAASCSetPointerValue(reqID, keyTmp);
    
    NSData *countData = [body subdataWithRange:NSMakeRange(pos, countLen)];
    NSUInteger countTmp = 0;
    [countData getBytes:&countTmp length:countLen];
    pos = pos + countLen;
    BAASCSetPointerValue(count, countTmp);
    
    NSData *indexData = [body subdataWithRange:NSMakeRange(pos, indexLen)];
    NSUInteger indexTmp = 0;
    [indexData getBytes:&indexTmp length:indexLen];
    pos = pos + indexLen;
    BAASCSetPointerValue(index, indexTmp);
    
    BAASCSetPointerValue(data, [body subdataWithRange:NSMakeRange(dataStart, body.length - dataStart)])
    return YES;
}

#pragma mark - private methods
+ (NSData *)assembleSlice:(NSInteger)reqID count:(NSUInteger)count index:(NSUInteger)index data:(NSData *)data {
    int32_t keyLength = sizeof(int32_t);
    int32_t countLength = sizeof(int32_t);
    int32_t indexLength = sizeof(int32_t);
    int32_t dataStart = sizeof(int32_t) + keyLength + countLength + indexLength;
    int64_t fullLength = sizeof(dataStart) + keyLength + countLength + indexLength + data.length;
    
    NSData *fullLengthData = [NSData dataWithBytes:&fullLength length:sizeof(fullLength)];
    NSData *dataStartData = [NSData dataWithBytes:&dataStart length:sizeof(dataStart)];
    NSData *keyData = [NSData dataWithBytes:&reqID length:keyLength];
    NSData *countData = [NSData dataWithBytes:&count length:countLength];
    NSData *indexData = [NSData dataWithBytes:&index length:indexLength];
    
    NSMutableData *fullData = [[NSMutableData alloc] init];
    [fullData appendData:fullLengthData];
    [fullData appendData:dataStartData];
    [fullData appendData:keyData];
    [fullData appendData:countData];
    [fullData appendData:indexData];
    [fullData appendData:data];
    return fullData;
}

+ (NSString *)packageTypeToStr:(BAASCPackageType)type {
    switch (type) {
        case BAASCPackageTypeReq:
            return gBAASCPackageTypeStrReq;
        case BAASCPackageTypeRes:
            return gBAASCPackageTypeStrRes;
        case BAASCPackageTypePush:
            return gBAASCPackageTypeStrPush;
        case BAASCPackageTypePing:
            return gBAASCPackageTypeStrPing;
        default:
            return gBAASCPackageTypeStrUnk;
    }
}

+ (BAASCPackageType)packageTypeFromStr:(NSString *)str {
    if ([str isEqualToString:gBAASCPackageTypeStrReq]) {
        return BAASCPackageTypeReq;
    } else if ([str isEqualToString:gBAASCPackageTypeStrRes]) {
        return BAASCPackageTypeRes;
    } else if ([str isEqualToString:gBAASCPackageTypeStrPush]) {
        return BAASCPackageTypePush;
    } else if ([str isEqualToString:gBAASCPackageTypeStrPing]) {
        return BAASCPackageTypePing;
    } else {
        return BAASCPackageTypeUnk;
    }
}

@end
