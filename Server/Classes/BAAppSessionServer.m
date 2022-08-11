//
//  BAAppSessionServer.m
//  BAAppSession
//
//  Created by BenArvin on 2022/4/14.
//

#import "BAAppSessionServer.h"
#import "BAASSGCDAsyncSocket.h"
#import "BAASSGCDAsyncUdpSocket.h"
#import "NSError+BAASSExtension.h"
#import "BAASSDataWorkshop.h"
#import "BAASSDefines.h"
#import "BAASSCounter.h"
#import "BAASSDataModels.h"

typedef NS_ENUM(NSUInteger, BAASSLogPriority) {
    BAASSLogPriorityInfo    = BAASSLogLevelVerbose,
    BAASSLogPriorityWarning = BAASSLogLevelDetail,
    BAASSLogPriorityError   = BAASSLogLevelBrief,
};

#define BAASS_TAG_HEADER 1001
#define BAASS_TAG_BODY 1002
#define OVERTIME_MAX 30.0
#define TIMEINTERVAL_PING_MISS_MAX 30.0
#define TIMEINTERVAL_WATCHDOG 1.0

#define BAASSInfoLog(...) BAASSLogV(__FILE__, __FUNCTION__, __LINE__, BAASSLogPriorityInfo, self, __VA_ARGS__)
#define BAASSWarningLog(...) BAASSLogV(__FILE__, __FUNCTION__, __LINE__, BAASSLogPriorityWarning, self, __VA_ARGS__)
#define BAASSErrorLog(...) BAASSLogV(__FILE__, __FUNCTION__, __LINE__, BAASSLogPriorityError, self, __VA_ARGS__)

NSString *const BAASSClientConnectedNotification = @"BAASSClientConnectedNotification";
NSString *const BAASSClientDisconnectedNotification = @"BAASSClientDisconnectedNotification";
NSString *const BAASSNotificationUserInfoKeyClient = @"client";

@interface BAAppSessionServer() <BAASSGCDAsyncSocketDelegate> {
}

@property (nonatomic) uint16_t port;
@property (atomic) BOOL running;
@property (nonatomic) BAASSGCDAsyncSocket *socket;
@property (nonatomic) dispatch_queue_t actionQueue;
@property (nonatomic) dispatch_queue_t outputQueue;
@property (nonatomic) NSMutableDictionary *clients;
@property (nonatomic) NSMutableDictionary *reqSliceTins;
@property (nonatomic) NSMapTable <NSString *, id> *observers;
@property (nonatomic) BAASSCounter *resIDCounter;
@property (nonatomic) BAASSCounter *resSliceCounter;
@property (nonatomic) BAASSCounter *clientCounter;
@property (nonatomic) NSMutableArray *responses;
@property (nonatomic) dispatch_source_t watchdogTimer;
@property (atomic) NSUInteger currentLogLevel;
@property (nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) NSPointerArray *logReceivers;

- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(BAASSLogPriority)priority text:(NSString *)text;

@end

void BAASSLogV(const char *file, const char *func, int line, BAASSLogPriority priority, BAAppSessionServer *receiver, NSString *format, ...) {
    NSDate *date = [NSDate date];
    va_list args;
    va_start(args, format);
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [receiver log:date file:file func:func line:line priority:priority text:logStr];
}

@implementation BAAppSessionServer

- (instancetype)init {
    self = [super init];
    if (self) {
        _running = NO;
        _observers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
        _clients = [[NSMutableDictionary alloc] init];
        _reqSliceTins = [[NSMutableDictionary alloc] init];
        _resIDCounter = [[BAASSCounter alloc] initWithMin:0 max:CGFLOAT_MAX];
        _clientCounter = [[BAASSCounter alloc] initWithMin:0 max:CGFLOAT_MAX];
        _resSliceCounter = [[BAASSCounter alloc] initWithMin:0 max:CGFLOAT_MAX];
        _responses = [[NSMutableArray alloc] init];
        _logReceivers = [NSPointerArray weakObjectsPointerArray];
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        _currentLogLevel = BAASSLogLevelDetail;
        _actionQueue = dispatch_queue_create("com.BenArvin.BAAppSessionServer.action", DISPATCH_QUEUE_SERIAL);
        _outputQueue = dispatch_queue_create("com.BenArvin.BAAppSessionServer.output", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (instancetype)initWithPort:(uint16_t)port {
    self = [self init];
    if (self) {
        _port = port;
    }
    return self;
}

#pragma mark - public methods
- (void)start {
    BAASSInfoLog(@"start");
    if (self.running) {
        BAASSWarningLog(@"already running, stop restart");
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        self.running = YES;
        self.socket = [[BAASSGCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.actionQueue];
        
        NSError *error = nil;
        BOOL success = [self.socket acceptOnPort:self.port error:&error];
        if (!success) {
            self.socket = nil;
            self.running = NO;
            BAASSErrorLog(@"acceptOnPort failed: %@", error.localizedDescription ?: @"unknown");
            return;
        }
        [self startWatchdog];
    });
}

- (void)stop {
    BAASSInfoLog(@"stop");
    if (!self.running) {
        BAASSWarningLog(@"already stopped, stop restop");
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        [self stopWatchdog];
        [self.socket disconnect];
        NSArray *allClientKeys = [[self.clients allKeys] copy];
        for (NSString *keyItem in allClientKeys) {
            BAASSClientInfo *item = [self.clients objectForKey:keyItem];
            [item.socket disconnect];
        }
        [self.clients removeAllObjects];
        [self.reqSliceTins removeAllObjects];
        self.running = NO;
    });
}

- (void)registerObserver:(id <BAAppSessionServerObserverProtocol>)observer forCmd:(NSString *)cmd {
    if (cmd.length <= 0 || !observer) {
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        [self.observers setObject:observer forKey:cmd];
        BAASSInfoLog(@"observer of cmd registered, cmd: %@, observer: %@", cmd, observer);
    });
}

- (void)unregisterObserver:(id <BAAppSessionServerObserverProtocol>)observer forCmd:(NSString *)cmd {
    if (cmd.length <= 0 || !observer) {
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        if ([self.observers objectForKey:cmd] != observer) {
            return;
        }
        [self.observers removeObjectForKey:cmd];
    });
}

- (void)unregisterObserver:(id <BAAppSessionServerObserverProtocol>)observer {
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        NSMutableArray *invalidCmds = [[NSMutableArray alloc] init];
        NSEnumerator *enumerator = [self.observers keyEnumerator];
        NSString *cmd = nil;
        while (cmd = [enumerator nextObject]) {
            if ([self.observers objectForKey:cmd] != observer) {
                continue;
            }
            [invalidCmds addObject:cmd];
        }
        for (NSString *item in invalidCmds) {
            [self.observers removeObjectForKey:item];
        }
    });
}

- (void)response:(NSData *)data to:(NSInteger)client withReqID:(NSInteger)reqID completion:(void(^)(BOOL success, NSError *error))completion {
    if (!self.running) {
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(NO, BAASSEasyError(30001, @"not running", nil));
            });
        }
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        [self responseAction:data to:client withReqID:reqID checkConnected:YES completion:completion];
    });
}

- (void)push:(NSData *)data to:(NSInteger)client completion:(void(^)(BOOL success, NSError *error))completion {
    if (!self.running) {
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(NO, BAASSEasyError(40001, @"not running", nil));
            });
        }
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        [self pushAction:data to:client checkConnected:YES completion:completion];
    });
}

- (void)broadcast:(NSData *)data completion:(void(^)(void))completion {
    if (!self.running) {
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion();
            });
        }
        return;
    }
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        __block NSInteger clientsLeft = self.clients.count;
        NSLock *lock = [[NSLock alloc] init];
        for (BAASSClientInfo *item in [self.clients allValues]) {
            [self pushAction:data to:item.ID checkConnected:YES completion:^(BOOL success, NSError *error) {
                BOOL finished = NO;
                [lock lock];
                clientsLeft--;
                if (clientsLeft == 0) {
                    finished = YES;
                }
                [lock unlock];
                if (finished && completion) {
                    completion();
                }
            }];
        }
    });
}

- (void)setLogLevel:(BAASSLogLevel)level {
    self.currentLogLevel = level;
}

- (void)registerLogReceiver:(id <BAAppSessionServerLogReceiverProtocol>)receiver {
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        BOOL finded = NO;
        for (NSInteger i=0; i<self.logReceivers.count; i++) {
            id item = [self.logReceivers pointerAtIndex:i];
            if (item == receiver) {
                finded = YES;
                break;
            }
        }
        if (!finded) {
            [self.logReceivers addPointer:(__bridge void *_Nullable)(receiver)];
        }
    });
}

- (void)unregisterLogReceiver:(id <BAAppSessionServerLogReceiverProtocol>)receiver {
    __weakObjS(self);
    dispatch_async(self.actionQueue, ^{
        __strongObjS(self);
        for (NSInteger i=0; i<self.logReceivers.count; i++) {
            id item = [self.logReceivers pointerAtIndex:i];
            if (item != receiver) {
                continue;
            }
            [self.logReceivers removePointerAtIndex:i];
            break;
        }
    });
}

#pragma mark - BAASSGCDAsyncSocketDelegate
- (void)socket:(BAASSGCDAsyncSocket *)sock didAcceptNewSocket:(BAASSGCDAsyncSocket *)newSocket {
    BAASSClientInfo *info = [[BAASSClientInfo alloc] init];
    info.socket = newSocket;
    info.ID = [self.clientCounter next];
    info.lastPingTime = [NSDate date];
    [self.clients setObject:info forKey:@(info.ID)];
    [newSocket readDataToLength:[BAASSDataWorkshop sliceHeaderLength] withTimeout:-1 tag:BAASS_TAG_HEADER];
    BAASSInfoLog(@"socket of client(%ld) accepted", info.ID);
    [self postOnClientConnectedMessage:info.ID];
}

- (void)socketDidDisconnect:(BAASSGCDAsyncSocket *)sock withError:(NSError *)err {
    NSInteger clientID = [self getClientIDOfSocket:sock];
    if (clientID == -1) {
        BAASSWarningLog(@"unknown socket disconnected");
        return;
    }
    [self.clients removeObjectForKey:@(clientID)];
    NSArray *tinKeys = [[self.reqSliceTins allKeys] copy];
    for (NSString *item in tinKeys) {
        BAASSReqSliceTin *tin = [self.reqSliceTins objectForKey:item];
        if (tin.client == clientID) {
            [self.reqSliceTins removeObjectForKey:item];
        }
    }
    BAASSInfoLog(@"socket of client(%ld) disconnected", clientID);
    [self postOnClientDisconnectedMessage:clientID];
}

- (void)socket:(BAASSGCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSInteger clientID = [self getClientIDOfSocket:sock];
    if (clientID == -1) {
        BAASSWarningLog(@"data received from unknown socket");
        return;
    }
    if (tag == BAASS_TAG_HEADER) {
        NSInteger bodyLen = [BAASSDataWorkshop disassembleSliceHeader:data];
        if (bodyLen < 0) {
            BAASSErrorLog(@"slice header value < 0");
            return;
        }
        [sock readDataToLength:bodyLen withTimeout:-1 tag:BAASS_TAG_BODY];
    } else if (tag == BAASS_TAG_BODY) {
        [self processReqSliceBody:data client:clientID];
        [sock readDataToLength:[BAASSDataWorkshop sliceHeaderLength] withTimeout:-1 tag:BAASS_TAG_HEADER];
    } else {
        BAASSWarningLog(@"unknown data tag: %ld", tag);
    }
}

#pragma mark - private methods
#pragma mark request methods
- (NSString *)tinKeyWith:(NSInteger)client reqID:(NSInteger)reqID {
    return [NSString stringWithFormat:@"%ld_%ld", client, reqID];
}

- (void)processReqSliceBody:(NSData *)slice client:(NSInteger)client {
    NSInteger version;
    NSInteger reqID;
    NSUInteger count, index = 0;
    NSData *data = nil;
    BOOL success = [BAASSDataWorkshop disassembleSliceBody:slice dataVersion:&version reqID:&reqID count:&count index:&index data:&data];
    if (!success) {
        BAASSErrorLog(@"disassemble slice body form client %ld failed", client);
        return;
    }
    NSString *tinKey = [self tinKeyWith:client reqID:reqID];
    BAASSReqSliceTin *tin = [self.reqSliceTins objectForKey:tinKey];
    if (!tin) {
        tin = [[BAASSReqSliceTin alloc] init];
        tin.client = client;
        tin.reqID = reqID;
        tin.count = count;
        [self.reqSliceTins setObject:tin forKey:tinKey];
        BAASSInfoLog(@"create slice tin for %ld", reqID);
    }
    [tin.packageParts setObject:data forKey:@(index)];
    BAASSInfoLog(@"insert slice into tin of %ld, data length=%ld", reqID, data.length);
    
    if (![tin isFull]) {
        return;
    }
    BAASSInfoLog(@"slice tin of %ld is fulled", reqID);
    [self.reqSliceTins removeObjectForKey:tinKey];
    [self processFullReqSliceTin:tin];
}

- (void)processFullReqSliceTin:(BAASSReqSliceTin *)tin {
    NSData *fullPackage = [tin fullPackage];
    NSString *cmd;
    BAASSPackageType type = BAASSPackageTypeUnk;
    NSData *data = nil;
    NSError *error;
    BOOL success = [BAASSDataWorkshop decodePackage:fullPackage cmd:&cmd type:&type data:&data error:&error];
    if (!success) {
        BAASSErrorLog(@"decode package from client %ld and reqID=%ld failed", tin.client, tin.reqID, error.localizedDescription ?: @"unknown");
        return;
    }
    BAASSInfoLog(@"req(%ld) package of tin decoded, client=%ld, type=%ld, cmd=%@", tin.reqID, tin.client, type, cmd);
    if (type == BAASSPackageTypeReq) {
        [self onRequestRecived:tin.reqID client:tin.client cmd:cmd data:data];
    } else if (type == BAASSPackageTypePing) {
        [self onPingReceived:tin.client];
    } else {
        BAASSWarningLog(@"unkown package type(%ld) from client %ld and reqID=%ld", type, tin.client, tin.reqID);
    }
}

- (void)onRequestRecived:(NSInteger)reqID client:(NSInteger)client cmd:(NSString *)cmd data:(NSData *)data {
    BAASSInfoLog(@"request from %ld received, reqID=%ld, cmd=%@, data length=%ld", client, reqID, cmd, data.length);
    if (cmd.length <= 0) {
        BAASSWarningLog(@"invalid request from client %ld and reqID=%ld, cmd is null", client, reqID);
        return;
    }
    id observer = [self.observers objectForKey:cmd];
    if (![observer conformsToProtocol:@protocol(BAAppSessionServerObserverProtocol)] || ![observer respondsToSelector:@selector(appSession:onRequest:client:cmd:data:)]) {
        return;
    }
    id<BAAppSessionServerObserverProtocol> observerTmp = observer;
    __weakObjS(self);
    dispatch_async(self.outputQueue, ^{
        __strongObjS(self);
        [observerTmp appSession:self onRequest:reqID client:client cmd:cmd data:data];
    });
}

- (void)onPingReceived:(NSInteger)client {
    BAASSClientInfo *info = [self.clients objectForKey:@(client)];
    if (!info) {
        BAASSWarningLog(@"ping from unkown client %ld", client);
        return;
    }
    info.lastPingTime = [NSDate date];
    BAASSInfoLog(@"ping from %ld received", client);
}

#pragma mark response methods
- (void)responseAction:(NSData *)data to:(NSInteger)client withReqID:(NSInteger)reqID checkConnected:(BOOL)checkConnected completion:(void(^)(BOOL success, NSError *error))completion {
    __weakObjS(self);
    void(^onFinished)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
        __strongObjS(self);
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(success, error);
            });
        }
    };
    BAASSClientInfo *clientInfo = [self.clients objectForKey:@(client)];
    if (!clientInfo) {
        onFinished(NO, BAASSEasyError(10001, @"can not find client", nil));
        return;
    }
    if (checkConnected && ![clientInfo.socket isConnected]) {
        onFinished(NO, BAASSEasyError(10002, @"client not connected", nil));
        return;
    }
    NSData *package = nil;
    NSError *encodeError = nil;
    BOOL encodeSuccess = [BAASSDataWorkshop encodeResPackage:data reqID:reqID toClient:client package:&package error:&encodeError];
    if (!encodeSuccess) {
        onFinished(NO, BAASSEasyError(10003, @"encode response package failed", encodeError, nil));
        return;
    }
    [self cutPackageAndSend:package client:client completion:completion];
}

- (void)pushAction:(NSData *)data to:(NSInteger)client checkConnected:(BOOL)checkConnected completion:(void(^)(BOOL success, NSError *error))completion {
    __weakObjS(self);
    void(^onFinished)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
        __strongObjS(self);
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(success, error);
            });
        }
    };
    BAASSClientInfo *clientInfo = [self.clients objectForKey:@(client)];
    if (!clientInfo) {
        onFinished(NO, BAASSEasyError(20001, @"can not find client", nil));
        return;
    }
    if (checkConnected && ![clientInfo.socket isConnected]) {
        onFinished(NO, BAASSEasyError(20002, @"client not connected", nil));
        return;
    }
    NSData *package = nil;
    NSError *encodeError = nil;
    BOOL encodeSuccess = [BAASSDataWorkshop encodePushPackage:data toClient:client package:&package error:&encodeError];
    if (!encodeSuccess) {
        onFinished(NO, BAASSEasyError(20003, @"encode response package failed", encodeError, nil));
        return;
    }
    [self cutPackageAndSend:package client:client completion:completion];
}

- (void)cutPackageAndSend:(NSData *)package client:(NSInteger)client completion:(void(^)(BOOL success, NSError *error))completion {
    NSInteger resID = [self.resIDCounter next];
    NSArray *slices = [BAASSDataWorkshop cutPackageIntoSlices:resID package:package dataVersion:BAASSDataVersion_1];
    BAASSResponse *res = [[BAASSResponse alloc] init];
    res.client = client;
    res.resID = resID;
    res.slices = [[NSMutableArray alloc] initWithArray:slices];
    res.completion = completion;
    [self.responses addObject:res];
    BAASSInfoLog(@"wakeup and try send responses, resID=%ld", resID);
    [self trySendResponse];
}

- (void)trySendResponse {
    if (self.responses.count <= 0) {
        BAASSInfoLog(@"take a rest, there's no response need send");
        return;
    }
    BAASSResponse *res = [self.responses firstObject];
    BAASSClientInfo *client = [self.clients objectForKey:@(res.client)];
    if (client) {
        if (res.slices.count > 0) {
            NSData *slice = [res.slices firstObject];
            [res.slices removeObjectAtIndex:0];
            [client.socket writeData:slice withTimeout:OVERTIME_MAX tag:[self.resSliceCounter next]];
        } else {
            [self.responses removeObjectAtIndex:0];
            [self onResSendFinish:res success:YES error:nil];
            BAASSInfoLog(@"response(%ld) send finished", res.resID);
        }
    } else {
        BAASSWarningLog(@"unknown clientID: %ld", client);
        [self.responses removeObjectAtIndex:0];
    }
    [self trySendResponse];
}

- (void)onResSendFinish:(BAASSResponse *)res success:(BOOL)success error:(NSError *)error {
    if (!res.completion) {
        return;
    }
    dispatch_async(self.outputQueue, ^{
        res.completion(success, error);
    });
}

#pragma mark watchdog methods
- (void)startWatchdog {
//    self.watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.actionQueue);
//    dispatch_source_set_timer(self.watchdogTimer, dispatch_walltime(NULL, 0), TIMEINTERVAL_WATCHDOG * NSEC_PER_SEC, 0);
//    __weak typeof(self) weakSelf = self;
//    dispatch_source_set_event_handler(self.watchdogTimer, ^{
//        [weakSelf watchdogAction];
//    });
//    dispatch_resume(self.watchdogTimer);
}

- (void)stopWatchdog {
//    if (self.watchdogTimer) {
//        dispatch_source_cancel(self.watchdogTimer);
//        self.watchdogTimer = nil;
//    }
}

- (void)watchdogAction {
    NSDate *now = [NSDate date];
    NSMutableArray *invalidItems = [[NSMutableArray alloc] init];
    for (NSNumber *item in [self.clients allKeys]) {
        BAASSClientInfo *info = [self.clients objectForKey:item];
        if ([now timeIntervalSinceDate:info.lastPingTime] > TIMEINTERVAL_PING_MISS_MAX) {
            [invalidItems addObject:item];
        }
    }
    for (NSNumber *item in invalidItems) {
        BAASSInfoLog(@"client(%ld) overtime no recall", item.integerValue);
        BAASSClientInfo *info = [self.clients objectForKey:item];
        [info.socket disconnect];
    }
}

#pragma mark log methods
- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(BAASSLogPriority)priority text:(NSString *)text {
    if (priority > self.currentLogLevel) {
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
    for (NSInteger i=0; i<self.logReceivers.count; i++) {
        id item = [self.logReceivers pointerAtIndex:i];
        if (![item conformsToProtocol:@protocol(BAAppSessionServerLogReceiverProtocol)] || ![item respondsToSelector:@selector(appSession:onLog:)]) {
            continue;
        }
        __weakObjS(self);
        dispatch_async(self.outputQueue, ^{
            __strongObjS(self);
            [item appSession:self onLog:fullStr];
        });
    }
}

- (NSString *)priorityFlag:(BAASSLogPriority)priority {
    switch (priority) {
        case BAASSLogPriorityError:
            return @"ERRO";
        case BAASSLogPriorityWarning:
            return @"WARN";
        default:
            return @"INFO";
    }
}

#pragma mark protocol methods
- (void)postOnClientConnectedMessage:(NSInteger)client {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.outputQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BAASSClientConnectedNotification object:weakSelf userInfo:@{
            BAASSNotificationUserInfoKeyClient: @(client)
        }];
    });
}

- (void)postOnClientDisconnectedMessage:(NSInteger)client {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.outputQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BAASSClientDisconnectedNotification object:weakSelf userInfo:@{
            BAASSNotificationUserInfoKeyClient: @(client)
        }];
    });
}

#pragma mark others
- (NSInteger)getClientIDOfSocket:(BAASSGCDAsyncSocket *)socket {
    for (NSNumber *item in [self.clients allKeys]) {
        BAASSClientInfo *info = [self.clients objectForKey:item];
        if (info.socket == socket) {
            return item.integerValue;
        }
    }
    return -1;
}

@end
