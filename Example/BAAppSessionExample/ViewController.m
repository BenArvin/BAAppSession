//
//  ViewController.m
//  TOAppSessionExample
//
//  Created by BenArvin on 2022/4/19.
//

#import "ViewController.h"
#import <BAAppSessionClient/BAAppSessionClient.h>

@interface ViewController () <BAAppSessionClientDelegate>

@property (nonatomic) UILabel *modeTipsLabel;
@property (nonatomic) UISwitch *modeSwitch;
@property (nonatomic) UITextView *resTextView;
@property (nonatomic) UITextView *logTextView;
@property (nonatomic) UITextView *inputTextView;
@property (nonatomic) UIButton *sendButton;
@property (nonatomic) BAAppSessionClient *session;
@property (nonatomic) BOOL useBoardcastMode;

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
    if (self.resTextView.superview != self.view) {
        self.modeTipsLabel = [[UILabel alloc] init];
        self.modeTipsLabel.textColor = [UIColor blackColor];
        self.modeTipsLabel.font = [UIFont systemFontOfSize:14];
        self.modeTipsLabel.textAlignment = NSTextAlignmentLeft;
        self.modeTipsLabel.text = @"current mode:";
        
        self.modeSwitch = [[UISwitch alloc] init];
        if (@available(iOS 14.0, *)) {
            [self.modeSwitch setPreferredStyle:UISwitchStyleCheckbox];
        }
        [self.modeSwitch addTarget:self action:@selector(onModeSwitchSelected) forControlEvents:UIControlEventValueChanged];
        
        self.resTextView = [[UITextView alloc] init];
        self.resTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        self.resTextView.layer.borderWidth = 1;
        self.resTextView.textColor = [UIColor blackColor];
        self.resTextView.font = [UIFont systemFontOfSize:12];
        self.resTextView.textAlignment = NSTextAlignmentLeft;
        self.resTextView.editable = NO;
        
        self.logTextView = [[UITextView alloc] init];
        self.logTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        self.logTextView.layer.borderWidth = 1;
        self.logTextView.textColor = [UIColor blackColor];
        self.logTextView.font = [UIFont systemFontOfSize:12];
        self.logTextView.textAlignment = NSTextAlignmentLeft;
        self.logTextView.editable = NO;
        
        self.inputTextView = [[UITextView alloc] init];
        self.inputTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        self.inputTextView.layer.borderWidth = 1;
        self.inputTextView.textColor = [UIColor blackColor];
        self.inputTextView.font = [UIFont systemFontOfSize:18];
        self.inputTextView.textAlignment = NSTextAlignmentLeft;
        self.inputTextView.editable = YES;
        
        self.sendButton = [[UIButton alloc] init];
        self.sendButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
        self.sendButton.layer.borderWidth = 1;
        [self.sendButton setTitle:@"send" forState:UIControlStateNormal];
        [self.sendButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        self.sendButton.titleLabel.font = [UIFont systemFontOfSize:18];
        self.sendButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.sendButton addTarget:self action:@selector(sendBtnAction) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:self.modeTipsLabel];
        [self.view addSubview:self.modeSwitch];
        [self.view addSubview:self.resTextView];
        [self.view addSubview:self.logTextView];
        [self.view addSubview:self.inputTextView];
        [self.view addSubview:self.sendButton];
        
        UITapGestureRecognizer *tapGest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBgTapped)];
        [self.view addGestureRecognizer:tapGest];
    }
}

- (void)onReqCompletion:(BOOL)success response:(NSData *)response error:(NSError *)error {
    if (!success || response.length <= 0) {
        NSAssert(NO, @"");
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        NSString *next = [NSString stringWithFormat:@"%ld", str.integerValue + 1];
        __weak typeof(strongSelf) weakSelf2 = strongSelf;
        [strongSelf.session request:@"numAdd" data:[next dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSData *response, NSError *error) {
            __strong typeof(weakSelf2) strongSelf2 = weakSelf2;
            [strongSelf2 onReqCompletion:success response:response error:error];
        }];
    });
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.modeSwitch.frame = CGRectMake(100, 50, 100, 50);
    self.modeTipsLabel.frame = CGRectMake(CGRectGetMaxX(self.modeSwitch.frame) + 10, CGRectGetMinY(self.modeSwitch.frame) + 5, self.view.bounds.size.width - CGRectGetMaxX(self.modeSwitch.frame) - 10, 20);
    self.inputTextView.frame = CGRectMake(10, CGRectGetMaxY(self.modeSwitch.frame) + 20, self.view.bounds.size.width - 20, 20);
    self.sendButton.frame = CGRectMake(floor((self.view.bounds.size.width - 50) / 2), CGRectGetMaxY(self.inputTextView.frame) + 20, 50, 30);
    CGFloat height = (self.view.bounds.size.height - CGRectGetMaxY(self.sendButton.frame) - 40 - 20) / 2;
    self.resTextView.frame = CGRectMake(10, CGRectGetMaxY(self.sendButton.frame) + 20, self.view.bounds.size.width - 20, height);
    self.logTextView.frame = CGRectMake(10, CGRectGetMaxY(self.resTextView.frame) + 20, self.view.bounds.size.width - 20, height);
}

- (void)appSession:(BAAppSessionClient *)session onPushReceived:(NSData *)data {
    if (data.length <= 0) {
        NSAssert(NO, @"");
        return;
    }
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *next = [NSString stringWithFormat:@"client response for %@", str];
    [self.session request:@"broadRes" data:[next dataUsingEncoding:NSUTF8StringEncoding] completion:nil];
}

- (void)appSessionLog:(NSString *)log {
    NSLog(@">>>>>>>>> %@", log);
}

- (void)onBgTapped {
    [self.inputTextView resignFirstResponder];
}

- (void)sendBtnAction {
    if (!self.inputTextView.text || self.inputTextView.text.length == 0) {
        return;
    }
    NSString *text = self.inputTextView.text;
    self.inputTextView.text = nil;
    [self printResData:[NSString stringWithFormat:@"Send request%@: %@", self.useBoardcastMode ? @"(boardcast)" : @"", text?:@"NULL"]];
    if (self.useBoardcastMode) {
        [self.session request:@"boardcastReq" data:[text dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSData *response, NSError *error) {
            if (error) {
                [self printResData:[NSString stringWithFormat:@"Response of boardcastReq received: failed, %@", [error localizedDescription]]];
            } else {
                if (response) {
                    NSString *resStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                    [self printResData:[NSString stringWithFormat:@"Response of boardcastReq received: %@", resStr]];
                } else {
                    [self printResData:@"Response of boardcastReq received: NULL"];
                }
            }
        }];
    } else {
        [self.session request:@"regularReq" data:[text dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSData *response, NSError *error) {
            if (error) {
                [self printResData:[NSString stringWithFormat:@"Response of regularReq received: failed, %@", [error localizedDescription]]];
            } else {
                if (response) {
                    NSString *resStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                    [self printResData:[NSString stringWithFormat:@"Response of regularReq received: %@", resStr]];
                } else {
                    [self printResData:@"Response of regularReq received: NULL"];
                }
            }
        }];
    }
}

- (void)printResData:(NSString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.resTextView.text) {
            self.resTextView.text = str?:@"NULL";
        } else {
            self.resTextView.text = [NSString stringWithFormat:@"%@\n%@", self.resTextView.text, str];
            if(self.resTextView.text.length > 0 ) {
                NSRange bottom = NSMakeRange(self.resTextView.text.length -1, 1);
                [self.resTextView scrollRangeToVisible:bottom];
            }
        }
    });
}

- (void)onModeSwitchSelected {
    self.useBoardcastMode = [self.modeSwitch isOn];
}

@end
