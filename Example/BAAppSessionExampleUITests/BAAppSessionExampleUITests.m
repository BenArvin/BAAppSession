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
@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) NSInteger count;

@end

@implementation BAAppSessionExampleUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    self.session = [[BAAppSessionServer alloc] initWithPort:1234];
    [self.session registerLogReceiver:self];
    [self.session setLogLevel:BAASSLogLevelVerbose];
    [self.session registerObserver:self forCmd:@"numAdd"];
    [self.session registerObserver:self forCmd:@"broadRes"];
    [self.session start];
    
    [self startBroadcase];
}

- (void)startBroadcase {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0), 1 * NSEC_PER_SEC, 0);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSData *data = [[NSString stringWithFormat:@"broadcast-%ld", strongSelf.count] dataUsingEncoding:NSUTF8StringEncoding];
        [strongSelf.session broadcast:data completion:nil];
        strongSelf.count++;
    });
    dispatch_resume(self.timer);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    KIFRunLoopRunInModeRelativeToAnimationSpeed(kCFRunLoopDefaultMode, 99999999999999999.0, NO);
}

- (void)appSession:(BAAppSessionServer *)session onRequest:(NSInteger)reqID client:(NSInteger)client cmd:(NSString *)cmd data:(NSData *)data {
    if ([cmd isEqualToString:@"numAdd"]) {
        if (data.length <= 0) {
            XCTAssert(NO);
            return;
        }
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@">>>>>> numAdd from %ld, id=%ld: %@", client, reqID, str);
        NSInteger next = str.integerValue + 1;
        NSData *resData = [[NSString stringWithFormat:@"%ld", next] dataUsingEncoding:NSUTF8StringEncoding];
        [session response:resData to:client withReqID:reqID completion:nil];
    } else if ([cmd isEqualToString:@"broadRes"]) {
        if (data.length <= 0) {
            XCTAssert(NO);
            return;
        }
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@">>>>>> broadRes from %ld, id=%ld: %@", client, reqID, str);
        [session response:nil to:client withReqID:reqID completion:nil];
    }
}

@end
