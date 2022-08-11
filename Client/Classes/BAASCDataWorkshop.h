//
//  BAASCDataWorkshop.h
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/20.
//

#import <Foundation/Foundation.h>

/*
 Version 1
 - full length: int64_t
 - version: int32_t
 - data start: int32_t
 - request ID: int32_t
 - count: int32_t
 - index: int32_t
 - data
 */
extern NSInteger BAASCDataVersion_1;

typedef NS_ENUM(NSUInteger, BAASCPackageType) {
    BAASCPackageTypeUnk,
    BAASCPackageTypeReq,
    BAASCPackageTypeRes,
    BAASCPackageTypePush,
    BAASCPackageTypePing
};

@interface BAASCDataWorkshop : NSObject

+ (BOOL)encodeReqPackage:(NSString *)cmd data:(NSData *)data package:(NSData **)package error:(NSError **)error;
+ (BOOL)encodePinPackage:(NSData **)package error:(NSError **)error;
+ (BOOL)decodePackage:(NSData *)package type:(BAASCPackageType *)type reqID:(NSInteger *)reqID client:(NSInteger *)client data:(NSData **)data error:(NSError **)error;

+ (NSInteger)sliceHeaderLength;
+ (NSArray <NSData *> *)cutPackageIntoSlices:(NSInteger)reqID package:(NSData *)package dataVersion:(NSInteger)dataVersion;
+ (NSInteger)disassembleSliceHeader:(NSData *)header;
+ (BOOL)disassembleSliceBody:(NSData *)body dataVersion:(NSInteger *)dataVersion reqID:(NSInteger *)reqID count:(NSUInteger *)count index:(NSUInteger *)index data:(NSData **)data;

@end
