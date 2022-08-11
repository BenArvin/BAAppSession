//
//  ViewController.m
//  BAAppSessionExample
//
//  Created by BenArvin on 2022/4/19.
//

#import "ViewController.h"
#import <BAAppSessionClient/BAAppSessionClient.h>

@interface ViewController () <BAAppSessionClientDelegate>

@property (nonatomic) BAAppSessionClient *session;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.session = [[BAAppSessionClient alloc] initWithPort:1234];
    self.session.delegate = self;
    [self.session connect];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)appSessionConnected:(BAAppSessionClient *)session {
    NSLog(@">>>>>>>>> connected");
}

- (void)appSessionDisconnected:(BAAppSessionClient *)session {
    NSLog(@">>>>>>>>> disconnected");
}

- (void)appSession:(BAAppSessionClient *)session onPushReceived:(NSData *)data {
    if (data.length <= 0) {
        NSAssert(NO, @"push data is nil");
        return;
    }
    NSString *pushStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([pushStr isEqual:@"PushTest"]) {
        [self.session request:@"PushTest-req" data:[@"PushTest-req-data" dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSData *response, NSError *error) {
            NSAssert(success, @"req for PushTest failed");
            NSString *resStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
            NSAssert([resStr isEqualToString:@"PushTest-req-res"], @"unknown res for PushTest-req");
        }];
    } else if ([pushStr isEqual:@"BoardcastTest"]) {
        [self.session request:@"BoardcastTest-req" data:[@"BoardcastTest-req-data" dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSData *response, NSError *error) {
            NSAssert(success, @"req for PushTest failed");
            NSString *resStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
            NSAssert([resStr isEqualToString:@"BoardcastTest-req-res"], @"unknown res for PushTest-req");
        }];
    } else {
        NSAssert(NO, @"unknown push content");
    }
}

- (void)appSessionLog:(NSString *)log {
    NSLog(@">>>>>>>>> %@", log);
}

@end
