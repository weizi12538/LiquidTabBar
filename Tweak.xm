#import "LTB.h"
#import <objc/runtime.h>
#import <objc/message.h>

// ---- Replace WeChat's tab bar with the liquid bar (also polled by LTBManager so we survive other tweaks) ----
%hook UITabBarController
- (void)viewDidLayoutSubviews { %orig; [LTBMgr attach:self]; }
- (void)viewDidAppear:(BOOL)a { %orig; [LTBMgr attach:self]; }
- (void)setSelectedIndex:(NSUInteger)i { %orig; [LTBMgr sync]; }
- (void)setSelectedViewController:(UIViewController *)vc { %orig; [LTBMgr sync]; }
%end

// ---- Entry 1: native WeChat settings page ----
%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    @try {
        Ivar iv = class_getInstanceVariable(object_getClass(self), "m_tableViewInfo");
        id info = iv ? object_getIvar(self, iv) : nil;
        Class S = NSClassFromString(@"MMTableViewSectionInfo"), C = NSClassFromString(@"MMTableViewCellInfo");
        if (!info || !S || !C) return;
        id sec = ((id (*)(Class, SEL))objc_msgSend)(S, NSSelectorFromString(@"sectionInfoDefaut"));
        id cell = ((id (*)(Class, SEL, SEL, id, id, long long))objc_msgSend)(C,
            NSSelectorFromString(@"normalCellForSel:target:title:accessoryType:"),
            @selector(ltb_openSettings), self, @"液态底栏", 1);
        ((void (*)(id, SEL, id))objc_msgSend)(sec, NSSelectorFromString(@"addCell:"), cell);
        ((void (*)(id, SEL, id, long long))objc_msgSend)(info, NSSelectorFromString(@"insertSection:At:"), sec, 0);
        id tv = ((id (*)(id, SEL))objc_msgSend)(info, NSSelectorFromString(@"getTableView"));
        [tv reloadData];
    } @catch (NSException *e) {}
}
%new
- (void)ltb_openSettings { [LTBMgr openSettings]; }
%end

// ---- Entry 3: a floating "液态底栏" pill on LiquidUI-style settings pages (they replace the native page) ----
static BOOL HasText(UIView *v, NSArray *keys, int d, int *budget) {
    if ((*budget)-- <= 0 || d > 14) return NO;
    NSString *t = [v isKindOfClass:[UILabel class]] ? ((UILabel *)v).text : nil;
    if (t.length) for (NSString *k in keys) if ([t isEqualToString:k]) return YES;
    for (UIView *s in v.subviews) if (HasText(s, keys, d + 1, budget)) return YES;
    return NO;
}
static void LTBInject(UIViewController *vc) {
    if (![vc isViewLoaded] || [vc isKindOfClass:[UINavigationController class]] || [vc isKindOfClass:[UITabBarController class]]) return;
    UIView *v = vc.view; if (!v.window || [v viewWithTag:0x4C5442]) return;
    int budget = 900;
    if (!HasText(v, @[@"下载中心", @"UI 商城", @"LiquidUI"], 0, &budget)) return;
    UIView *pill = LTBEntryPill();
    CGFloat w = 118, h = 38, sb = v.safeAreaInsets.bottom;
    pill.frame = CGRectMake(v.bounds.size.width - w - 16, v.bounds.size.height - sb - 130, w, h);
    pill.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [v addSubview:pill];
}
%hook UIViewController
- (void)viewDidAppear:(BOOL)a { %orig; LTBInject(self); }
%end

%ctor {
    %init;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [LTBMgr start];
        // Entry 2: register in the common WeChat plugin list (WCPluginsMgr) if another plugin framework provides it
        @try {
            Class m = NSClassFromString(@"WCPluginsMgr");
            SEL si = NSSelectorFromString(@"sharedInstance"), sr = NSSelectorFromString(@"registerControllerWithTitle:version:controller:");
            if (m && [m respondsToSelector:si]) {
                id mgr = ((id (*)(Class, SEL))objc_msgSend)(m, si);
                if ([mgr respondsToSelector:sr]) ((void (*)(id, SEL, id, id, id))objc_msgSend)(mgr, sr, @"液态底栏", @"1.1.0", @"LTBSettingsVC");
            }
        } @catch (NSException *e) {}
    });
}
