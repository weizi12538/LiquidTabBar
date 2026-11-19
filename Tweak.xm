#import "LTB.h"
#import <objc/runtime.h>
#import <objc/message.h>

// ---- Replace WeChat's tab bar with the liquid bar ----
%hook UITabBarController
- (void)viewDidLayoutSubviews { %orig; [LTBMgr attach:self]; }
- (void)setSelectedIndex:(NSUInteger)i { %orig; [LTBMgr sync]; }
- (void)setSelectedViewController:(UIViewController *)vc { %orig; [LTBMgr sync]; }
%end

// ---- Entry in  我 → 设置 ----
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
- (void)ltb_openSettings {
    UIViewController *me = (UIViewController *)self;
    LTBSettingsVC *v = [LTBSettingsVC new];
    if (me.navigationController) [me.navigationController pushViewController:v animated:YES];
    else [me presentViewController:[[UINavigationController alloc] initWithRootViewController:v] animated:YES completion:nil];
}
%end
