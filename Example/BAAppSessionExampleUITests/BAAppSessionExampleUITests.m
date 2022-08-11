//
//  BAAppSessionExampleUITests.m
//  BAAppSessionExampleUITests
//
//  Created by BenArvin on 2022/4/19.
//

#import <XCTest/XCTest.h>
#import <KIF/KIF.h>
#import <KIF/UIApplication-KIFAdditions.h>
#import <BAAppSessionServer/BAAppSessionServer.h>

@interface BAAppSessionExampleUITests : XCTestCase <BAAppSessionServerObserverProtocol, BAAppSessionServerLogReceiverProtocol>

@property (nonatomic) BAAppSessionServer *session;
@property (atomic) BOOL boardcastTestSuccess;
@property (atomic) BOOL pushTestSuccess;
@property (atomic) NSInteger client;

@end

@implementation BAAppSessionExampleUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    
    self.client = -1;

    self.session = [[BAAppSessionServer alloc] initWithPort:1234];
    [self.session registerLogReceiver:self];
    [self.session setLogLevel:BAASSLogLevelVerbose];
    [self.session registerObserver:self forCmd:@"BoardcastTest-req"];
    [self.session registerObserver:self forCmd:@"PushTest-req"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onClientConnected:) name:BAASSClientConnectedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onClientDisconnected:) name:BAASSClientDisconnectedNotification object:self.session];
    [self.session start];
    
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
    KIFRunLoopRunInModeRelativeToAnimationSpeed(kCFRunLoopDefaultMode, 3.0, NO);
}

- (void)tearDown {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.session unregisterObserver:self];
    [self.session unregisterLogReceiver:self];
    [self.session stop];
}

- (void)testBoardcast {
    self.boardcastTestSuccess = NO;
    
    [self.session broadcast:[@"BoardcastTest" dataUsingEncoding:NSUTF8StringEncoding] completion:nil];

    KIFRunLoopRunInModeRelativeToAnimationSpeed(kCFRunLoopDefaultMode, 5.0, NO);
    
    XCTAssert(self.boardcastTestSuccess);
}

- (void)testPush {
    self.pushTestSuccess = NO;
    
    XCTAssert(self.client != -1);
    [self.session push:[@"PushTest" dataUsingEncoding:NSUTF8StringEncoding] to:self.client completion:^(BOOL success, NSError *error) {
        XCTAssert(success);
        if (!success) {
            NSLog(@"push failed %@", error.localizedDescription ?: @"unknown");
        }
    }];

    KIFRunLoopRunInModeRelativeToAnimationSpeed(kCFRunLoopDefaultMode, 5.0, NO);
    
    XCTAssert(self.pushTestSuccess);
}

- (void)appSession:(BAAppSessionServer *)session onRequest:(NSInteger)reqID client:(NSInteger)client cmd:(NSString *)cmd data:(NSData *)data {
    if ([cmd isEqualToString:@"BoardcastTest-req"]) {
        if (data.length <= 0) {
            XCTAssert(NO);
            return;
        }
        NSString *reqStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssert([reqStr isEqualToString:@"BoardcastTest-req-data"]);
        NSData *resData = [@"BoardcastTest-req-res" dataUsingEncoding:NSUTF8StringEncoding];
        [session response:resData to:client withReqID:reqID completion:^(BOOL success, NSError *error) {
            XCTAssert(success);
            self.boardcastTestSuccess = YES;
            if (!success) {
                NSLog(@"response for BoardcastTest-req failed: %@", error.localizedDescription ?: @"unknown");
            }
        }];
    } else if ([cmd isEqualToString:@"PushTest-req"]) {
        if (data.length <= 0) {
            XCTAssert(NO);
            return;
        }
        NSString *reqStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssert([reqStr isEqualToString:@"PushTest-req-data"]);
        NSData *resData = [@"PushTest-req-res" dataUsingEncoding:NSUTF8StringEncoding];
        [session response:resData to:client withReqID:reqID completion:^(BOOL success, NSError *error) {
            XCTAssert(success);
            self.pushTestSuccess = YES;
            if (!success) {
                NSLog(@"response for PushTest-req failed: %@", error.localizedDescription ?: @"unknown");
            }
        }];
    } else {
        XCTAssert(NO);
    }
}

- (void)onClientConnected:(NSNotification *)notification {
    NSNumber *clientObj = [notification.userInfo objectForKey:BAASSNotificationUserInfoKeyClient];
    if (clientObj) {
        self.client = clientObj.integerValue;
    }
}

- (void)onClientDisconnected:(NSNotification *)notification {
    self.client = -1;
}

@end
