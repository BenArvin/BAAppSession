//
//  BAASSDataWorkshop.m
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/20.
//

#import "BAASSDataWorkshop.h"
#import "BAASSDefines.h"

#define BAASS_SLICE_LEN (1024.0 * 10.0)

NSInteger BAASSDataVersion_1 = 1;

static NSString *const gBAASSPackageKeyCmd = @"cmd";
static NSString *const gBAASSPackageKeyType = @"type";
static NSString *const gBAASSPackageKeyClient = @"client";
static NSString *const gBAASSPackageKeyData = @"data";
static NSString *const gBAASSPackageKeyReqID = @"reqID";
static NSString *const gBAASSPackageTypeStrReq = @"req";
static NSString *const gBAASSPackageTypeStrRes = @"res";
static NSString *const gBAASSPackageTypeStrPush = @"pus";
static NSString *const gBAASSPackageTypeStrPing = @"pin";
static NSString *const gBAASSPackageTypeStrUnk = @"unk";

@implementation BAASSDataWorkshop

+ (BOOL)encodeResPackage:(NSData *)data reqID:(NSInteger)reqID toClient:(NSInteger)client package:(NSData **)package error:(NSError **)error {
    return [self encodePackage:data type:BAASSPackageTypeRes reqID:reqID client:client package:package error:error];
}

+ (BOOL)encodePushPackage:(NSData *)data toClient:(NSInteger)client package:(NSData **)package error:(NSError **)error {
    return [self encodePackage:data type:BAASSPackageTypePush reqID:-1 client:client package:package error:error];
}

+ (BOOL)decodePackage:(NSData *)package cmd:(NSString **)cmd type:(BAASSPackageType *)type data:(NSData **)data error:(NSError **)error {
    if (package.length <= 0) {
        BAASSSetPointerValue(error, BAASSEasyError(20001, @"invalid package", nil));
        return NO;
    }
    NSError *jsonError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:package options:kNilOptions error:&jsonError];
    if (jsonError) {
        BAASSSetPointerValue(error, BAASSEasyError(20002, @"conver package data to json obj failed", jsonError, nil));
        return NO;
    }
    if (![obj isKindOfClass:[NSDictionary class]]) {
        BAASSSetPointerValue(error, BAASSEasyError(20003, @"package obj is not dic", nil));
        return NO;
    }
    NSDictionary *dic = (NSDictionary *)obj;
    
    NSString *cmdTmp = [dic objectForKey:gBAASSPackageKeyCmd];
    BAASSSetPointerValue(cmd, cmdTmp);
    
    BAASSSetPointerValue(type, [self packageTypeFromStr:[dic objectForKey:gBAASSPackageKeyType]]);
    
    NSString *dataStr = [dic objectForKey:gBAASSPackageKeyData];
    if (dataStr) {
        BAASSSetPointerValue(data, [[NSData alloc] initWithBase64EncodedString:dataStr options:kNilOptions]);
    } else {
        BAASSSetPointerValue(data, nil);
    }
    return YES;
}

+ (NSArray <NSData *> *)cutPackageIntoSlices:(NSInteger)reqID package:(NSData *)package dataVersion:(NSInteger)dataVersion {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (package.length <= 0) {
        return result;
    }
    NSUInteger fullLen = package.length;
    NSUInteger count = ceil(fullLen / BAASS_SLICE_LEN);
    NSUInteger pos = 0;
    NSUInteger index = 0;
    while (YES) {
        if (pos >= fullLen) {
            break;
        }
        NSUInteger size = BAASS_SLICE_LEN;
        if (pos + size > fullLen) {
            size = fullLen - pos;
        }
        if (size <= 0) {
            break;
        }
        NSData *slice = [package subdataWithRange:NSMakeRange(pos, size)];
        [result addObject:[self assembleSlice:dataVersion reqID:reqID count:count index:index data:slice]];
        pos = pos + size;
        index++;
    }
    return result;
}

+ (NSInteger)sliceHeaderLength {
    return sizeof(int64_t);
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

+ (BOOL)disassembleSliceBody:(NSData *)body dataVersion:(NSInteger *)dataVersion reqID:(NSInteger *)reqID count:(NSUInteger *)count index:(NSUInteger *)index data:(NSData **)data {
    int32_t versionLen = sizeof(int32_t);
    int32_t dataStartLen = sizeof(int32_t);
    int32_t keyLen = sizeof(int32_t);
    int32_t countLen = sizeof(int32_t);
    int32_t indexLen = sizeof(int32_t);
    int32_t minLen = versionLen + dataStartLen + keyLen + countLen + indexLen;
    if (body.length < minLen) {
        return NO;
    }
    NSUInteger pos = 0;
    
    NSData *versionData = [body subdataWithRange:NSMakeRange(pos, versionLen)];
    NSInteger versionTmp = 0;
    [versionData getBytes:&versionTmp length:versionLen];
    pos = pos + versionLen;
    BAASSSetPointerValue(dataVersion, versionTmp);
    
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
    BAASSSetPointerValue(reqID, keyTmp);
    
    NSData *countData = [body subdataWithRange:NSMakeRange(pos, countLen)];
    NSUInteger countTmp = 0;
    [countData getBytes:&countTmp length:countLen];
    pos = pos + countLen;
    BAASSSetPointerValue(count, countTmp);
    
    NSData *indexData = [body subdataWithRange:NSMakeRange(pos, indexLen)];
    NSUInteger indexTmp = 0;
    [indexData getBytes:&indexTmp length:indexLen];
    pos = pos + indexLen;
    BAASSSetPointerValue(index, indexTmp);
    
    BAASSSetPointerValue(data, [body subdataWithRange:NSMakeRange(dataStart, body.length - dataStart)])
    return YES;
}

#pragma mark - private methods
+ (NSData *)assembleSlice:(NSInteger)version reqID:(NSInteger)reqID count:(NSUInteger)count index:(NSUInteger)index data:(NSData *)data {
    int32_t versionLength = sizeof(int32_t);
    int32_t keyLength = sizeof(int32_t);
    int32_t countLength = sizeof(int32_t);
    int32_t indexLength = sizeof(int32_t);
    int32_t dataStart = sizeof(int32_t) + versionLength + keyLength + countLength + indexLength;
    int64_t fullLength = versionLength + sizeof(dataStart) + keyLength + countLength + indexLength + data.length;
    
    NSData *fullLengthData = [NSData dataWithBytes:&fullLength length:sizeof(fullLength)];
    NSData *versionData = [NSData dataWithBytes:&version length:versionLength];
    NSData *dataStartData = [NSData dataWithBytes:&dataStart length:sizeof(dataStart)];
    NSData *keyData = [NSData dataWithBytes:&reqID length:keyLength];
    NSData *countData = [NSData dataWithBytes:&count length:countLength];
    NSData *indexData = [NSData dataWithBytes:&index length:indexLength];
    
    NSMutableData *fullData = [[NSMutableData alloc] init];
    [fullData appendData:fullLengthData];
    [fullData appendData:versionData];
    [fullData appendData:dataStartData];
    [fullData appendData:keyData];
    [fullData appendData:countData];
    [fullData appendData:indexData];
    [fullData appendData:data];
    return fullData;
}

+ (NSString *)packageTypeToStr:(BAASSPackageType)type {
    switch (type) {
        case BAASSPackageTypeReq:
            return gBAASSPackageTypeStrReq;
        case BAASSPackageTypeRes:
            return gBAASSPackageTypeStrRes;
        case BAASSPackageTypePush:
            return gBAASSPackageTypeStrPush;
        case BAASSPackageTypePing:
            return gBAASSPackageTypeStrPing;
        default:
            return gBAASSPackageTypeStrUnk;
    }
}

+ (BAASSPackageType)packageTypeFromStr:(NSString *)str {
    if ([str isEqualToString:gBAASSPackageTypeStrReq]) {
        return BAASSPackageTypeReq;
    } else if ([str isEqualToString:gBAASSPackageTypeStrRes]) {
        return BAASSPackageTypeRes;
    } else if ([str isEqualToString:gBAASSPackageTypeStrPush]) {
        return BAASSPackageTypePush;
    } else if ([str isEqualToString:gBAASSPackageTypeStrPing]) {
        return BAASSPackageTypePing;
    } else {
        return BAASSPackageTypeUnk;
    }
}

+ (BOOL)encodePackage:(NSData *)data type:(BAASSPackageType)type reqID:(NSInteger)reqID client:(NSInteger)client package:(NSData **)package error:(NSError **)error {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary: @{
        gBAASSPackageKeyType: [self packageTypeToStr:type]
    }];
    if (type == BAASSPackageTypeRes) {
        [dic setObject:@(reqID) forKey:gBAASSPackageKeyReqID];
    }
    [dic setObject:@(client) forKey:gBAASSPackageKeyClient];
    NSString *dataStr = [data base64EncodedStringWithOptions:kNilOptions];
    if (dataStr) {
        [dic setObject:dataStr forKey:gBAASSPackageKeyData];
    }
    NSError *jsonError = nil;
    NSData *resultTmp = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&jsonError];
    if (jsonError) {
        BAASSSetPointerValue(error, BAASSEasyError(10001, @"convert package dic to data failed", jsonError, nil));
        return NO;
    }
    if (resultTmp.length <= 0) {
        BAASSSetPointerValue(error, BAASSEasyError(10002, @"package data is null", nil));
        return NO;
    }
    BAASSSetPointerValue(package, resultTmp);
    return YES;
}

@end
