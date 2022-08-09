//
//  BAASCDataWorkshop.h
//  BAAppSessionClient
//
//  Created by BenArvin on 2022/4/20.
//

#import <Foundation/Foundation.h>

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
+ (NSArray <NSData *> *)cutPackageIntoSlices:(NSInteger)reqID package:(NSData *)package;
+ (NSInteger)disassembleSliceHeader:(NSData *)header;
+ (BOOL)disassembleSliceBody:(NSData *)body reqID:(NSInteger *)reqID count:(NSUInteger *)count index:(NSUInteger *)index data:(NSData **)data;

@end
