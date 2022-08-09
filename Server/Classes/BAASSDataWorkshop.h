//
//  BAASSDataWorkshop.h
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/20.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BAASSPackageType) {
    BAASSPackageTypeUnk,
    BAASSPackageTypeReq,
    BAASSPackageTypeRes,
    BAASSPackageTypePush,
    BAASSPackageTypePing
};

@interface BAASSDataWorkshop : NSObject

+ (BOOL)encodeResPackage:(NSData *)data reqID:(NSInteger)reqID toClient:(NSInteger)client package:(NSData **)package error:(NSError **)error;
+ (BOOL)encodePushPackage:(NSData *)data toClient:(NSInteger)client package:(NSData **)package error:(NSError **)error;
+ (BOOL)decodePackage:(NSData *)package cmd:(NSString **)cmd type:(BAASSPackageType *)type data:(NSData **)data error:(NSError **)error;

+ (NSInteger)sliceHeaderLength;
+ (NSArray <NSData *> *)cutPackageIntoSlices:(NSInteger)reqID package:(NSData *)package;
+ (NSInteger)disassembleSliceHeader:(NSData *)header;
+ (BOOL)disassembleSliceBody:(NSData *)body reqID:(NSInteger *)reqID count:(NSUInteger *)count index:(NSUInteger *)index data:(NSData **)data;

@end
