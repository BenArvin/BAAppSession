//
//  BAAppSessionClient.m
//  BAAppSession
//
//  Created by BenArvin on 2022/4/14.
//

#import "BAAppSessionClient.h"
#import "BAASCGCDAsyncSocket.h"
#import "BAASCGCDAsyncUdpSocket.h"
#import "BAASCDefines.h"
#import "BAASCDataWorkshop.h"
#import "BAASCCounter.h"
#import "BAASCDataModels.h"

NSString *const gBAAppSessionClientNotificationConnected = @"gBAAppSessionClientNotificationConnected";
NSString *const gBAAppSessionClientNotificationDisconnected = @"gBAAppSessionClientNotificationDisconnected";
NSString *const gBAAppSessionClientNotificationPushReceived = @"gBAAppSessionClientNotificationPushReceived";
NSString *const gBAAppSessionClientNotificationKeyData = @"data";

typedef NS_ENUM(NSUInteger, BAASCLogPriority) {
    BAASCLogPriorityInfo    = BAASCLogLevelVerbose,
    BAASCLogPriorityWarning = BAASCLogLevelDetail,
    BAASCLogPriorityError   = BAASCLogLevelBrief,
};

#define BAASC_TAG_HEADER 1001
#define BAASC_TAG_BODY 1002
#define OVERTIME_DEFAULT 30.0
#define TIMEINTERVAL_WATCHDOG 1.0

#define BAASCInfoLog(...) BAASCLogV(__FILE__, __FUNCTION__, __LINE__, BAASCLogPriorityInfo, self, __VA_ARGS__)
#define BAASCWarningLog(...) BAASCLogV(__FILE__, __FUNCTION__, __LINE__, BAASCLogPriorityWarning, self, __VA_ARGS__)
#define BAASCErrorLog(...) BAASCLogV(__FILE__, __FUNCTION__, __LINE__, BAASCLogPriorityError, self, __VA_ARGS__)

@interface BAAppSessionClient() <BAASCGCDAsyncSocketDelegate> {
}

@property (atomic) BOOL connected;
@property (nonatomic) uint16_t port;
@property (nonatomic) BAASCGCDAsyncSocket *socket;
@property (nonatomic) dispatch_queue_t actionQueue;
@property (nonatomic) dispatch_queue_t outputQueue;
@property (nonatomic) NSMutableDictionary *reqInfos;
@property (nonatomic) NSMutableArray *reqSlices;
@property (nonatomic) BAASCCounter *reqIDCounter;
@property (nonatomic) BAASCCounter *sendTagCounter;
@property (nonatomic) NSMutableDictionary *resSliceTins;
@property (nonatomic) dispatch_source_t watchdogTimer;
@property (atomic) NSUInteger currentLogLevel;
@property (nonatomic) NSDateFormatter *dateFormatter;

- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(BAASCLogPriority)priority text:(NSString *)text;

@end

void BAASCLogV(const char *file, const char *func, int line, BAASCLogPriority priority, BAAppSessionClient *receiver, NSString *format, ...) {
    NSDate *date = [NSDate date];
    va_list args;
    va_start(args, format);
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [receiver log:date file:file func:func line:line priority:priority text:logStr];
}

@implementation BAAppSessionClient

- (instancetype)initWithPort:(uint16_t)port {
    self = [self init];
    if (self) {
        _port = port;
        _connected = NO;
        _reqIDCounter = [[BAASCCounter alloc] initWithMin:0 max:CGFLOAT_MAX];
        _sendTagCounter = [[BAASCCounter alloc] initWithMin:0 max:CGFLOAT_MAX];
        _reqInfos = [[NSMutableDictionary alloc] init];
        _reqSlices = [[NSMutableArray alloc] init];
        _resSliceTins = [[NSMutableDictionary alloc] init];
        _currentLogLevel = BAASCLogLevelDetail;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        _actionQueue = dispatch_queue_create("com.BenArvin.BAAppSessionClient.action", DISPATCH_QUEUE_SERIAL);
        _outputQueue = dispatch_queue_create("com.BenArvin.BAAppSessionClient.output", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - public methods
- (void)connect {
    if ([self isConnected]) {
        BAASCWarningLog(@"already connected, stop reconnect");
        return;
    }
    __weakObjC(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjC(self);
        BAASCInfoLog(@"connect");
        self.socket = [[BAASCGCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.actionQueue];
        
        NSError *error = nil;
        if (![self.socket connectToHost:@"127.0.0.1" onPort:self.port error:&error]) {
            BAASCErrorLog(@"connect to localhost failed: %@", error.localizedDescription ?: @"unknown");
            self.socket = nil;
            return;
        }
        [self startWatchdog];
    });
}

- (void)disconnect {
    BAASCInfoLog(@"disconnect");
    if (![self isConnected]) {
        BAASCWarningLog(@"already disconnected, stop redisconnect");
        return;
    }
    __weakObjC(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjC(self);
        [self.socket disconnect];
    });
}

- (BOOL)isConnected {
    return self.connected;
}

- (void)request:(NSString *)cmd data:(NSData *)data completion:(void(^)(BOOL success, NSData *response, NSError *error))completion {
    [self request:cmd data:data overtime:OVERTIME_DEFAULT completion:completion];
}

- (void)request:(NSString *)cmd data:(NSData *)data overtime:(NSInteger)overtime completion:(void(^)(BOOL success, NSData *response, NSError *error))completion {
    if (![self isConnected]) {
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(NO, nil, BAASCEasyError(10001, @"not connected", nil));
            });
        }
        return;
    }
    if (cmd.length <= 0) {
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(NO, nil, BAASCEasyError(10002, @"invalid cmd", nil));
            });
        }
        return;
    }
    __weakObjC(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjC(self);
        long reqID = [self.reqIDCounter next];
        BAASCReqInfo *req = [[BAASCReqInfo alloc] initWithReqID:reqID completion:completion startTime:[NSDate date] overtime:overtime];
        [self.reqInfos setObject:req forKey:@(reqID)];
        
        NSData *fullPackage = nil;
        NSError *encodeError = nil;
        BOOL encodeSuccess = [BAASCDataWorkshop encodeReqPackage:cmd data:data package:&fullPackage error:&encodeError];
        if (!encodeSuccess) {
            [self onReqFailed:reqID error:encodeError];
            return;
        }
        [self cutPackageAndSend:fullPackage reqID:reqID];
    });
}

- (void)setLogLevel:(BAASCLogLevel)level {
    self.currentLogLevel = level;
}

#pragma mark - BAASCGCDAsyncSocketDelegate
- (void)socket:(BAASCGCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.connected = YES;
    [self onConnected];
    [sock readDataToLength:[BAASCDataWorkshop sliceHeaderLength] withTimeout:-1 tag:BAASC_TAG_HEADER];
    BAASCInfoLog(@"socket connected");
}

- (void)socketDidDisconnect:(BAASCGCDAsyncSocket *)sock withError:(NSError *)err {
    [self stopWatchdog];
    self.socket = nil;
    [self.resSliceTins removeAllObjects];
    [self.reqSlices removeAllObjects];
    NSArray *reqKeys = [[self.reqInfos allKeys] copy];
    for (NSNumber *item in reqKeys) {
        [self onReqFailed:item.integerValue error:BAASCEasyError(80001, @"disconnected", nil)];
    }
    self.connected = NO;
    [self onDisconnected];
    BAASCInfoLog(@"socket disconnected");
}

- (void)socket:(BAASCGCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (tag == BAASC_TAG_HEADER) {
        NSInteger bodyLen = [BAASCDataWorkshop disassembleSliceHeader:data];
        if (bodyLen < 0) {
            BAASCErrorLog(@"slice header value < 0");
            return;
        }
        [sock readDataToLength:bodyLen withTimeout:-1 tag:BAASC_TAG_BODY];
    } else if (tag == BAASC_TAG_BODY) {
        [self processResSliceBody:data];
        [sock readDataToLength:[BAASCDataWorkshop sliceHeaderLength] withTimeout:-1 tag:BAASC_TAG_HEADER];
    } else {
        BAASCWarningLog(@"unknown data tag: %ld", tag);
    }
}

#pragma mark - private methods
#pragma mark request methods
- (void)cutPackageAndSend:(NSData *)package reqID:(NSInteger)reqID {
    NSArray *slices = [BAASCDataWorkshop cutPackageIntoSlices:reqID package:package dataVersion:BAASCDataVersion_1];
    if (slices.count <= 0) {
        BAASCErrorLog(@"count of slices cut form package is 0, reqID=%ld, package len=%ld", reqID, package.length);
        [self onReqFailed:reqID error:BAASCEasyError(20001, @"slices count is zero", nil)];
        return;
    }
    [self.reqSlices addObjectsFromArray:slices];
    BAASCInfoLog(@"wakeup and try send slices, reqID=%ld", reqID);
    [self trySendSlices];
}

- (void)trySendSlices {
    if (self.reqSlices.count <= 0) {
        BAASCInfoLog(@"take a rest, there's no slice need send");
        return;
    }
    NSData *item = [self.reqSlices objectAtIndex:0];
    [self.reqSlices removeObjectAtIndex:0];
    [self.socket writeData:item withTimeout:OVERTIME_DEFAULT tag:[self.sendTagCounter next]];
    [self trySendSlices];
}

- (void)onReqFailed:(long)reqID error:(NSError *)error {
    BAASCInfoLog(@"req(%ld) failed: %@", reqID, error.localizedDescription ?: @"unknown");
    BAASCReqInfo *req = [self.reqInfos objectForKey:@(reqID)];
    if (!req) {
        BAASCErrorLog(@"can't find reqInfo of %ld", reqID);
        return;
    }
    [self.reqInfos removeObjectForKey:@(reqID)];
    if (req.completion) {
        req.completion(NO, nil, error);
    }
}

#pragma mark response methods
- (void)processResSliceBody:(NSData *)slice {
    NSInteger version;
    NSInteger resID;
    NSUInteger count, index = 0;
    NSData *data = nil;
    BOOL success = [BAASCDataWorkshop disassembleSliceBody:slice dataVersion:&version reqID:&resID count:&count index:&index data:&data];
    if (!success) {
        BAASCErrorLog(@"disassemble slice body failed");
        return;
    }
    BAASCResSliceTin *tin = [self.resSliceTins objectForKey:@(resID)];
    if (!tin) {
        tin = [[BAASCResSliceTin alloc] init];
        tin.resID = resID;
        tin.count = count;
        [self.resSliceTins setObject:tin forKey:@(resID)];
        BAASCInfoLog(@"create slice tin for %ld", resID);
    }
    BAASCInfoLog(@"insert slice into tin of %ld, data length=%ld", resID, data.length);
    [tin.packageParts setObject:data forKey:@(index)];
    
    if (![tin isFull]) {
        return;
    }
    BAASCInfoLog(@"slice tin of %ld is fulled", resID);
    [self.resSliceTins removeObjectForKey:@(resID)];
    [self processFullResSliceTin:tin];
}

- (void)processFullResSliceTin:(BAASCResSliceTin *)tin {
    NSData *fullPackage = [tin fullPackage];
    NSInteger reqID;
    BAASCPackageType type = BAASCPackageTypeUnk;
    NSData *data = nil;
    NSError *error;
    BOOL success = [BAASCDataWorkshop decodePackage:fullPackage type:&type reqID:&reqID client:nil data:&data error:&error];
    if (!success) {
        BAASCErrorLog(@"decode package failed: %@", error.localizedDescription ?: @"unknown");
        return;
    }
    BAASCInfoLog(@"res(%ld) package of tin decoded, type=%ld, reqID=ld", tin.resID, type, reqID);
    if (type == BAASCPackageTypePush) {
        [self onPushReceived:data];
    } else if (type == BAASCPackageTypeRes) {
        [self onResReceived:reqID data:data];
    } else {
        BAASCWarningLog(@"unknown package type: %ld", type);
    }
}

- (void)onResReceived:(NSInteger)reqID data:(NSData *)data {
    BAASCInfoLog(@"response of %ld received, date length=%ld", reqID, data.length);
    BAASCReqInfo *info = [self.reqInfos objectForKey:@(reqID)];
    if (!info) {
        BAASCErrorLog(@"can't find reqInfo of %ld", reqID);
        return;
    }
    [self.reqInfos removeObjectForKey:@(reqID)];
    if (!info.completion) {
        return;
    }
    dispatch_async(self.outputQueue, ^{
        info.completion(YES, data, nil);
    });
}

#pragma mark delegate methods
- (void)onPushReceived:(NSData *)data {
    BAASCInfoLog(@"push received, date length=%ld", data.length);
    if (![self.delegate respondsToSelector:@selector(appSession:onPushReceived:)]) {
        return;
    }
    __weakObjC(self);
    dispatch_async(self.outputQueue, ^{
        __strongObjC(self);
        [self.delegate appSession:self onPushReceived:data];
    });
}

- (void)onConnected {
    if (![self.delegate respondsToSelector:@selector(appSessionConnected:)]) {
        return;
    }
    __weakObjC(self);
    dispatch_async(self.outputQueue, ^{
        __strongObjC(self);
        [self.delegate appSessionConnected:self];
    });
}

- (void)onDisconnected {
    if (![self.delegate respondsToSelector:@selector(appSessionDisconnected:)]) {
        return;
    }
    __weakObjC(self);
    dispatch_async(self.outputQueue, ^{
        __strongObjC(self);
        [self.delegate appSessionDisconnected:self];
    });
}

#pragma mark watchdog methods
- (void)startWatchdog {
    self.watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.actionQueue);
    dispatch_source_set_timer(self.watchdogTimer, dispatch_walltime(NULL, 0), TIMEINTERVAL_WATCHDOG * NSEC_PER_SEC, 0);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.watchdogTimer, ^{
        [weakSelf watchdogAction];
    });
    dispatch_resume(self.watchdogTimer);
}

- (void)stopWatchdog {
    if (self.watchdogTimer) {
        dispatch_source_cancel(self.watchdogTimer);
        self.watchdogTimer = nil;
    }
}

- (void)watchdogAction {
    [self checkOvertimeRequests];
//    [self sendPingRequest];
}

- (void)checkOvertimeRequests {
    NSMutableArray *overtimeItems = [[NSMutableArray alloc] init];
    NSDate *now = [NSDate date];
    for (NSNumber *item in self.reqInfos) {
        BAASCReqInfo *info = [self.reqInfos objectForKey:item];
        if ([now timeIntervalSinceDate:info.startTime] > info.overtime) {
            [overtimeItems addObject:item];
        }
    }
    for (NSNumber *item in overtimeItems) {
        BAASCInfoLog(@"request(%ld) overtimed", item.integerValue);
        [self onReqFailed:item.integerValue error:BAASCEasyError(90001, @"overtime", nil)];
    }
}

- (void)sendPingRequest {
    long reqID = [self.reqIDCounter next];
    NSData *package = nil;
    NSError *encodeError = nil;
    BOOL encodeSuccess = [BAASCDataWorkshop encodePinPackage:&package error:&encodeError];
    if (!encodeSuccess) {
        BAASCErrorLog(@"encode ping package failed: %@", encodeError.localizedDescription ?: @"unknown");
        return;
    }
    [self cutPackageAndSend:package reqID:reqID];
}

#pragma mark log methods
- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(BAASCLogPriority)priority text:(NSString *)text {
    if (priority > self.currentLogLevel) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(appSessionLog:)]) {
        return;
    }
    NSString *dateStr = [self.dateFormatter stringFromDate:date];
    NSString *fileStr = nil;
    NSURL *fileUrl = nil;
    NSString *fileName = nil;
    if (file) {
        fileStr = [NSString stringWithUTF8String:file];
    }
    if (fileStr) {
        fileUrl = [[NSURL alloc] initFileURLWithPath:fileStr];
    }
    if (fileUrl) {
        fileName = [fileUrl lastPathComponent];
    }
    NSString *fullStr = [NSString stringWithFormat:@"[%@][%@][%@:%d]%s:%@", dateStr, [self priorityFlag:priority], fileName, line, func, text?:@""];
#ifdef DEBUG
    NSLog(@"%@", fullStr);
#endif
    __weakObjC(self);
    dispatch_async(self.outputQueue, ^{
        __strongObjC(self);
        [self.delegate appSessionLog:fullStr];
    });
}

- (NSString *)priorityFlag:(BAASCLogPriority)priority {
    switch (priority) {
        case BAASCLogPriorityError:
            return @"ERRO";
        case BAASCLogPriorityWarning:
            return @"WARN";
        default:
            return @"INFO";
    }
}

@end
