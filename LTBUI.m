#import "LTB.h"
#import <objc/runtime.h>
#import <objc/message.h>
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"

#pragma mark - helpers
static UIColor *Red(void) { return [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1]; }
static UIColor *Dyn(CGFloat lw, CGFloat la, CGFloat dw, CGFloat da) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:dw alpha:da] : [UIColor colorWithWhite:lw alpha:la];
    }];
}
static UIImage *SF(NSString *n, CGFloat pt, UIImageSymbolWeight w) {
    return [UIImage systemImageNamed:n withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:pt weight:w]];
}
static UIImage *Thumb(UIImage *i, CGFloat s) {
    if (!i) return nil;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, s, s) cornerRadius:s / 2] addClip];
        [i drawInRect:CGRectMake(0, 0, s, s)];
    }];
}
static UIButton *Btn(NSString *sym, CGFloat pt, id t, SEL s) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:SF(sym, pt, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    b.tintColor = [UIColor labelColor];
    [b addTarget:t action:s forControlEvents:UIControlEventTouchUpInside];
    return b;
}

// Quick panel items (same grid as the reference video). "u" = WeChat URL, "a" = internal action, neither = not wired yet
static NSArray *QuickItems(void) {
    return @[
        @{@"id": @"scan", @"t": @"扫一扫", @"s": @"viewfinder", @"a": @"scan"},
        @{@"id": @"pay", @"t": @"收付款", @"s": @"creditcard", @"u": @"weixin://dl/offlinepay/"},
        @{@"id": @"wallet", @"t": @"钱包", @"s": @"wallet.pass", @"u": @"weixin://dl/wallet"},
        @{@"id": @"myqr", @"t": @"我的二维码", @"s": @"qrcode", @"u": @"weixin://dl/qrcode"},
        @{@"id": @"fav", @"t": @"收藏", @"s": @"shippingbox", @"u": @"weixin://dl/favorites"},
        @{@"id": @"addf", @"t": @"添加朋友", @"s": @"person.badge.plus", @"u": @"weixin://dl/addfriend"},
        @{@"id": @"group", @"t": @"发起群聊", @"s": @"envelope", @"u": @"weixin://dl/groupchat"},
        @{@"id": @"readall", @"t": @"一键已读", @"s": @"envelope.fill"},
        @{@"id": @"mini", @"t": @"小程序", @"s": @"link", @"u": @"weixin://dl/miniprogram"},
        @{@"id": @"note", @"t": @"笔记", @"s": @"note.text", @"u": @"weixin://dl/notes"},
        @{@"id": @"dark", @"t": @"深色模式", @"s": @"moon.fill", @"a": @"dark"},
        @{@"id": @"bg", @"t": @"聊天背景", @"s": @"photo", @"a": @"liquidui"},
        @{@"id": @"font", @"t": @"字体 Font", @"s": @"textformat", @"a": @"liquidui"},
        @{@"id": @"card", @"t": @"首页卡片", @"s": @"rectangle.stack", @"a": @"liquidui"},
        @{@"id": @"acct", @"t": @"切换账号", @"s": @"person.text.rectangle.fill"},
        @{@"id": @"ltbset", @"t": @"底栏设置", @"s": @"slider.horizontal.3", @"a": @"settings"},
        @{@"id": @"wxset", @"t": @"微信设置", @"s": @"gearshape", @"a": @"wxsettings"},
    ];
}

@interface LTBManager (Private)
- (void)toast:(NSString *)t;
@end

// Open a weixin:// deep link INSIDE this process. Never hand it to the system, otherwise iOS routes it to the original WeChat app.
static void OpenWX(NSString *s) {
    NSURL *url = [NSURL URLWithString:s]; UIApplication *app = [UIApplication sharedApplication]; id d = app.delegate; BOOL handled = NO, tried = NO;
    @try {
        if ([d respondsToSelector:@selector(application:openURL:options:)]) { tried = YES; handled = [d application:app openURL:url options:@{}]; }
        else if ([d respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]) { tried = YES; handled = [d application:app openURL:url sourceApplication:nil annotation:@{}]; }
    } @catch (NSException *e) {}
    (void)handled;
    if (!tried) [LTBMgr toast:@"该入口暂不可用"];
}
static NSString *AvatarURL(void) {
    @try {
        Class sc = NSClassFromString(@"MMServiceCenter"), cm = NSClassFromString(@"CContactMgr"); if (!sc || !cm) return nil;
        id center = ((id (*)(Class, SEL))objc_msgSend)(sc, NSSelectorFromString(@"defaultCenter"));
        id mgr = ((id (*)(id, SEL, Class))objc_msgSend)(center, NSSelectorFromString(@"getService:"), cm);
        id me = ((id (*)(id, SEL))objc_msgSend)(mgr, NSSelectorFromString(@"getSelfContact"));
        for (NSString *k in @[@"m_nsHeadHDImgUrl", @"m_nsHeadImgUrl"]) {
            @try { id v = [me valueForKey:k]; if ([v isKindOfClass:[NSString class]] && [v length]) return v; } @catch (NSException *e) {}
        }
    } @catch (NSException *e) {}
    return nil;
}
// ---- simulate a tap on a row of WeChat's own UI (works without knowing internal class names)
static UILabel *FindLabel(UIView *v, NSString *text, int d, int *budget) {
    if ((*budget)-- <= 0 || d > 22) return nil;
    if ([v isKindOfClass:[UILabel class]] && [((UILabel *)v).text isEqualToString:text] && !v.hidden && v.window) return (UILabel *)v;
    for (UIView *s in v.subviews) { UILabel *r = FindLabel(s, text, d + 1, budget); if (r) return r; }
    return nil;
}
static BOOL FireGR(UIGestureRecognizer *g) {
    BOOL did = NO;
    @try {
        NSArray *targets = [g valueForKey:@"targets"];
        for (id t in targets) {
            id tgt = [t valueForKey:@"target"]; Ivar iv = class_getInstanceVariable([t class], "_action"); if (!tgt || !iv) continue;
            SEL a = *(SEL *)((uint8_t *)(__bridge void *)t + ivar_getOffset(iv)); if (!a || ![tgt respondsToSelector:a]) continue;
            ((void (*)(id, SEL, id))objc_msgSend)(tgt, a, g); did = YES;
        }
    } @catch (NSException *e) {}
    return did;
}
static BOOL FireTap(UIView *v) {
    int depth = 0;
    for (UIView *x = v; x && depth < 9; x = x.superview, depth++) {
        if ([x isKindOfClass:[UITableViewCell class]]) {
            UITableView *tv = nil; for (UIView *p = x.superview; p; p = p.superview) if ([p isKindOfClass:[UITableView class]]) { tv = (UITableView *)p; break; }
            NSIndexPath *ip = tv ? [tv indexPathForCell:(UITableViewCell *)x] : nil;
            if (tv && ip && [tv.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) { [tv.delegate tableView:tv didSelectRowAtIndexPath:ip]; return YES; }
        }
        if ([x isKindOfClass:[UICollectionViewCell class]]) {
            UICollectionView *cv = nil; for (UIView *p = x.superview; p; p = p.superview) if ([p isKindOfClass:[UICollectionView class]]) { cv = (UICollectionView *)p; break; }
            NSIndexPath *ip = cv ? [cv indexPathForCell:(UICollectionViewCell *)x] : nil;
            if (cv && ip && [cv.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [cv.delegate collectionView:cv didSelectItemAtIndexPath:ip]; return YES; }
        }
        if ([x isKindOfClass:[UIControl class]] && ((UIControl *)x).allTargets.count) { [(UIControl *)x sendActionsForControlEvents:UIControlEventTouchUpInside]; return YES; }
        for (UIGestureRecognizer *g in x.gestureRecognizers) if ([g isKindOfClass:[UITapGestureRecognizer class]] && FireGR(g)) return YES;
    }
    return NO;
}

#pragma mark - shapes
// rounded "pillow" (used by panels)
static UIBezierPath *Pillow(CGRect r, CGFloat cr, CGFloat btop, CGFloat bbot, CGFloat bside) {
    CGFloat l = r.origin.x + bside, t = r.origin.y + btop, rr = CGRectGetMaxX(r) - bside, bt = CGRectGetMaxY(r) - bbot;
    CGFloat mx = CGRectGetMidX(r), my = (t + bt) / 2;
    CGFloat m = MIN(rr - l, bt - t) / 2; cr = MAX(1.0, MIN(cr, m));
    BOOL side = (bt - t - 2 * cr) > 1, top = (rr - l - 2 * cr) > 1;
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(l + cr, t)];
    if (top) [p addQuadCurveToPoint:CGPointMake(rr - cr, t) controlPoint:CGPointMake(mx, t - 2 * btop)];
    [p addQuadCurveToPoint:CGPointMake(rr, t + cr) controlPoint:CGPointMake(rr, t)];
    if (side) [p addQuadCurveToPoint:CGPointMake(rr, bt - cr) controlPoint:CGPointMake(rr + 2 * bside, my)];
    [p addQuadCurveToPoint:CGPointMake(rr - cr, bt) controlPoint:CGPointMake(rr, bt)];
    if (top) [p addQuadCurveToPoint:CGPointMake(l + cr, bt) controlPoint:CGPointMake(mx, bt + 2 * bbot)];
    [p addQuadCurveToPoint:CGPointMake(l, bt - cr) controlPoint:CGPointMake(l, bt)];
    if (side) [p addQuadCurveToPoint:CGPointMake(l, t + cr) controlPoint:CGPointMake(l - 2 * bside, my)];
    [p addQuadCurveToPoint:CGPointMake(l + cr, t) controlPoint:CGPointMake(l, t)];
    [p closePath];
    return p;
}
// bent band (the reference's banana shape): mid half-thickness `rad`, both ends are `dh` thicker, the whole band bends down by `drop` at the ends
static CGFloat BandU(CGRect r, CGFloat rad, CGFloat dh, CGFloat x, CGFloat *hsOut) {
    CGFloat hs = MAX(1.0, r.size.width / 2 - (rad + dh)); if (hsOut) *hsOut = hs;
    return MAX(-1.0, MIN(1.0, (x - CGRectGetMidX(r)) / hs));
}
static CGFloat CapCY(CGRect r, CGFloat rad, CGFloat drop, CGFloat dh, CGFloat x) {
    CGFloat u = BandU(r, rad, dh, x, NULL); return r.origin.y + rad + drop * u * u;
}
static CGFloat CapAngle(CGRect r, CGFloat rad, CGFloat drop, CGFloat dh, CGFloat x) {
    CGFloat hs, u = BandU(r, rad, dh, x, &hs); return atan(2 * drop * u / hs);
}
static UIBezierPath *ArcCapsule(CGRect r, CGFloat rad, CGFloat drop, CGFloat dh) {
    CGFloat rEnd = rad + dh, x0 = r.origin.x + rEnd, x1 = CGRectGetMaxX(r) - rEnd, mx = (x0 + x1) / 2, hs = MAX(1.0, (x1 - x0) / 2);
    int N = 40, C = 16; UIBezierPath *p = [UIBezierPath bezierPath];
    void (^fr)(CGFloat, CGFloat *, CGFloat *, CGFloat *, CGFloat *, CGFloat *, CGFloat *) = ^(CGFloat x, CGFloat *cy, CGFloat *half, CGFloat *nx, CGFloat *ny, CGFloat *tx, CGFloat *ty) {
        CGFloat u = (x - mx) / hs, s = 2 * drop * u / hs, k = sqrt(1 + s * s);
        *cy = r.origin.y + rad + drop * u * u; *half = rad + dh * u * u; *nx = s / k; *ny = -1 / k; *tx = 1 / k; *ty = s / k;
    };
    CGFloat cy, hf, nx, ny, tx, ty;
    for (int i = 0; i <= N; i++) {
        CGFloat x = x0 + (x1 - x0) * i / N; fr(x, &cy, &hf, &nx, &ny, &tx, &ty);
        CGPoint pt = CGPointMake(x + hf * nx, cy + hf * ny); if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
    }
    fr(x1, &cy, &hf, &nx, &ny, &tx, &ty);
    for (int j = 1; j < C; j++) { CGFloat th = M_PI * j / C; [p addLineToPoint:CGPointMake(x1 + hf * (cos(th) * nx + sin(th) * tx), cy + hf * (cos(th) * ny + sin(th) * ty))]; }
    for (int i = N; i >= 0; i--) {
        CGFloat x = x0 + (x1 - x0) * i / N; fr(x, &cy, &hf, &nx, &ny, &tx, &ty); [p addLineToPoint:CGPointMake(x - hf * nx, cy - hf * ny)];
    }
    fr(x0, &cy, &hf, &nx, &ny, &tx, &ty);
    for (int j = 1; j < C; j++) { CGFloat th = M_PI + M_PI * j / C; [p addLineToPoint:CGPointMake(x0 + hf * (cos(th) * nx + sin(th) * tx), cy + hf * (cos(th) * ny + sin(th) * ty))]; }
    [p closePath];
    return p;
}

#pragma mark - liquid glass look (self-drawn): milky fill + sheen + inner glow + bright rim
@interface LTBFX : NSObject
- (instancetype)initWithHost:(CALayer *)host;
- (void)update:(CGPathRef)path bounds:(CGRect)b traits:(UITraitCollection *)tc;
- (void)setHidden:(BOOL)h;
@end
@implementation LTBFX {
    CAShapeLayer *_fill, *_glow, *_glowMask, *_rim, *_sheenMask; CAGradientLayer *_sheen;
}
- (instancetype)initWithHost:(CALayer *)host {
    if (!(self = [super init])) return nil;
    _fill = [CAShapeLayer layer];
    _sheen = [CAGradientLayer layer]; _sheen.locations = @[@0, @0.36, @0.70, @1]; _sheen.startPoint = CGPointMake(0.5, 0); _sheen.endPoint = CGPointMake(0.5, 1);
    _sheenMask = [CAShapeLayer layer]; _sheen.mask = _sheenMask;
    _glow = [CAShapeLayer layer]; _glow.fillColor = nil; _glow.lineWidth = 8; _glowMask = [CAShapeLayer layer]; _glow.mask = _glowMask;
    _rim = [CAShapeLayer layer]; _rim.fillColor = nil; _rim.lineWidth = 2.2;
    for (CALayer *l in @[_fill, _sheen, _glow, _rim]) [host addSublayer:l];
    return self;
}
- (void)setHidden:(BOOL)h { for (CALayer *l in @[_fill, _sheen, _glow, _rim]) l.hidden = h; }
- (void)update:(CGPathRef)path bounds:(CGRect)b traits:(UITraitCollection *)tc {
    BOOL dark = tc.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *W = UIColor.whiteColor, *K = UIColor.blackColor, *C0 = [UIColor colorWithWhite:1 alpha:0];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    for (CAShapeLayer *l in @[_fill, _glow, _rim, _sheenMask, _glowMask]) { l.frame = b; l.path = path; }
    _sheen.frame = b;
    _fill.fillColor = (dark ? [UIColor colorWithWhite:0.20 alpha:0.62] : [UIColor colorWithWhite:0.97 alpha:0.74]).CGColor;
    _glow.strokeColor = [W colorWithAlphaComponent:dark ? 0.12 : 0.55].CGColor;
    _rim.strokeColor = [W colorWithAlphaComponent:dark ? 0.30 : 0.98].CGColor;
    _sheen.colors = dark ? @[(id)[W colorWithAlphaComponent:0.14].CGColor, (id)C0.CGColor, (id)C0.CGColor, (id)[K colorWithAlphaComponent:0.28].CGColor]
                         : @[(id)[W colorWithAlphaComponent:0.40].CGColor, (id)C0.CGColor, (id)C0.CGColor, (id)[K colorWithAlphaComponent:0.09].CGColor];
    [CATransaction commit];
}
@end

#pragma mark - glass
// iOS 26 Liquid Glass (UIGlassEffect). Falls back to a blurred, self-drawn glass on older systems or when chosen in settings.
static NSString *GlassMode(void) {
    if (!NSClassFromString(@"UIGlassEffect")) return @"blur";
    return [LTBStr(@"glass", @"blur") isEqual:@"flat"] ? @"flat" : @"blur";
}
static UIVisualEffectView *MakeGlass(void) {
    Class gc = NSClassFromString(@"UIGlassEffect"); id e = [[gc alloc] init];
    @try { [(NSObject *)e setValue:@NO forKey:@"interactive"]; } @catch (NSException *x) {}
    return [[UIVisualEffectView alloc] initWithEffect:(UIVisualEffect *)e];
}
static void GlassShape(UIView *v, CGFloat r, BOOL capsule) {
    v.layer.cornerRadius = r; v.layer.cornerCurve = kCACornerCurveContinuous;
    if (capsule) {
        @try {
            Class cc = NSClassFromString(@"UICornerConfiguration"); SEL s = NSSelectorFromString(@"capsuleConfiguration");
            if (cc && [cc respondsToSelector:s]) { id conf = ((id (*)(Class, SEL))objc_msgSend)(cc, s); if (conf) [v setValue:conf forKey:@"cornerConfiguration"]; }
        } @catch (NSException *x) {}
    }
}

@interface LTBGlass : UIView
@property(nonatomic) CGFloat radius, bulge;
@property(nonatomic, readonly) UIView *contentView;
@end
@implementation LTBGlass {
    UIVisualEffectView *_blur, *_gv; LTBFX *_fx; CAShapeLayer *_mask; UIView *_content; BOOL _native;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _radius = 24; _bulge = 0; _native = ![GlassMode() isEqual:@"blur"];
    if (_native) { _gv = MakeGlass(); [self addSubview:_gv]; }
    else {
        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]]; [self addSubview:_blur];
        _fx = [[LTBFX alloc] initWithHost:self.layer];
        _mask = [CAShapeLayer layer]; self.layer.mask = _mask;
    }
    _content = [UIView new]; _content.backgroundColor = UIColor.clearColor; [self addSubview:_content];
    return self;
}
- (UIView *)contentView { return _content; }
- (void)traitCollectionDidChange:(UITraitCollection *)p { [super traitCollectionDidChange:p]; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds; _content.frame = b; if (b.size.width < 2) return;
    if (_native) { _gv.frame = b; CGFloat m = MIN(b.size.width, b.size.height) / 2, r = MIN(_radius, m); GlassShape(_gv, r, r >= m - 0.5); return; }
    _blur.frame = b;
    UIBezierPath *p = Pillow(b, _radius, _bulge, _bulge * 0.5, _bulge * 0.4);
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _mask.frame = b; _mask.path = p.CGPath; [CATransaction commit];
    [_fx update:p.CGPath bounds:b traits:self.traitCollection];
}
@end

@interface LTBHost : UIView
@end
@implementation LTBHost
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { UIView *v = [super hitTest:p withEvent:e]; return v == self ? nil : v; }
@end

#pragma mark - bar
@interface LTBBar : UIView <UIScrollViewDelegate>
@property(nonatomic, weak) UITabBarController *tbc;
@property(nonatomic, readonly) CGFloat stripTop;
@property(nonatomic) BOOL quickOpen;
- (instancetype)initWithFrame:(CGRect)f controller:(UITabBarController *)t;
- (void)syncSelection;
- (void)syncBadges;
- (void)refreshCenter;
@end

@implementation LTBBar {
    UIVisualEffectView *_blur, *_tabHost, *_stripG, *_lG, *_rG; NSMutableArray<UIVisualEffectView *> *_segs;
    LTBFX *_fx; CAShapeLayer *_mask; BOOL _glass; NSString *_mode;
    UIView *_pill, *_p0, *_p1, *_trk, *_fil;
    NSMutableArray<UIButton *> *_items; NSMutableArray<UILabel *> *_badges; NSMutableArray<NSString *> *_badgeCache;
    UIButton *_prev, *_play, *_next, *_lb, *_rb;
    UIImageView *_art, *_disc; UIScrollView *_sv; UIPageControl *_pc;
    UILabel *_title, *_artist, *_searchLbl;
    NSInteger _sel; CGFloat _stripTop, _tabRad, _tabDrop, _tabDh; CGRect _tabR, _stripR;
}
- (CGFloat)stripTop { return _stripTop; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { UIView *v = [super hitTest:p withEvent:e]; return v == self ? nil : v; }

- (instancetype)initWithFrame:(CGRect)f controller:(UITabBarController *)t {
    if (!(self = [super initWithFrame:f])) return nil;
    _tbc = t; _items = [NSMutableArray array]; _badges = [NSMutableArray array]; _badgeCache = [NSMutableArray array]; _sel = -1;
    _mode = GlassMode(); _glass = ![_mode isEqual:@"blur"]; _tabRad = 25; _tabDrop = [_mode isEqual:@"flat"] ? 0 : 13; _tabDh = [_mode isEqual:@"flat"] ? 0 : 4;
    _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    [self addSubview:_blur];
    _fx = [[LTBFX alloc] initWithHost:self.layer];
    _mask = [CAShapeLayer layer]; _blur.layer.mask = _mask;
    if (_glass) {
        _blur.hidden = YES; [_fx setHidden:YES];
        // the bent tab bar is several overlapping glass capsules in one glass container so they merge into one liquid shape
        Class gcc = NSClassFromString(@"UIGlassContainerEffect"); id ce = gcc ? [[gcc alloc] init] : nil;
        _tabHost = [[UIVisualEffectView alloc] initWithEffect:(UIVisualEffect *)ce]; [self addSubview:_tabHost];
        _segs = [NSMutableArray array]; int N = [_mode isEqual:@"flat"] ? 1 : 6;
        for (int k = 0; k < N; k++) { UIVisualEffectView *g = MakeGlass(); [_tabHost.contentView addSubview:g]; [_segs addObject:g]; }
        _stripG = MakeGlass(); _lG = MakeGlass(); _rG = MakeGlass(); [self addSubview:_stripG]; [self addSubview:_lG]; [self addSubview:_rG];
    }

    _pill = [UIView new]; _pill.backgroundColor = Dyn(0.0, 0.07, 1.0, 0.10); _pill.layer.cornerCurve = kCACornerCurveContinuous; _pill.userInteractionEnabled = NO;
    [self addSubview:_pill];
    NSArray *sym = @[@"envelope", @"person.2", @"safari", @"person"];
    NSUInteger n = t.viewControllers.count;
    for (NSUInteger i = 0; i < n; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem]; b.tag = i; b.tintColor = [UIColor labelColor];
        UITabBarItem *it = t.viewControllers[i].tabBarItem;
        if (n == 4) [b setImage:SF(sym[i], 24, UIImageSymbolWeightLight) forState:UIControlStateNormal];
        else [b setImage:[it.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(tapItem:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b]; [_items addObject:b];
        UILabel *bg = [UILabel new]; bg.backgroundColor = UIColor.labelColor; bg.textColor = UIColor.systemBackgroundColor; bg.font = [UIFont boldSystemFontOfSize:8.5];
        bg.textAlignment = NSTextAlignmentCenter; bg.layer.cornerRadius = 7; bg.clipsToBounds = YES; bg.hidden = YES; bg.userInteractionEnabled = NO;
        [self addSubview:bg]; [_badges addObject:bg]; [_badgeCache addObject:@""];
    }
    _disc = [UIImageView new]; _disc.contentMode = UIViewContentModeScaleAspectFill; _disc.clipsToBounds = YES; _disc.userInteractionEnabled = YES;
    [_disc addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDisc)]];
    [_disc addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longDisc:)]];
    [self addSubview:_disc];

    _sv = [UIScrollView new]; _sv.pagingEnabled = YES; _sv.showsHorizontalScrollIndicator = NO; _sv.delegate = self; _sv.bounces = NO; [self addSubview:_sv];
    _p0 = [UIView new]; _p1 = [UIView new]; [_sv addSubview:_p0]; [_sv addSubview:_p1];
    _art = [UIImageView new]; _art.contentMode = UIViewContentModeScaleAspectFill; _art.clipsToBounds = YES; _art.userInteractionEnabled = YES;
    [_art addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapMini)]];
    _title = [UILabel new]; _title.font = [UIFont boldSystemFontOfSize:16]; _title.textColor = UIColor.labelColor; _title.userInteractionEnabled = YES;
    [_title addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapMini)]];
    _artist = [UILabel new]; _artist.font = [UIFont systemFontOfSize:12]; _artist.textColor = UIColor.secondaryLabelColor;
    _trk = [UIView new]; _trk.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.25]; _trk.layer.cornerRadius = 1;
    _fil = [UIView new]; _fil.backgroundColor = UIColor.labelColor; _fil.layer.cornerRadius = 1; [_trk addSubview:_fil];
    _prev = Btn(@"backward.end.fill", 12, self, @selector(doPrev)); _play = Btn(@"play.fill", 16, self, @selector(doPlay)); _next = Btn(@"forward.end.fill", 12, self, @selector(doNext));
    for (UIView *v in @[_art, _title, _artist, _trk, _prev, _play, _next]) [_p0 addSubview:v];
    _searchLbl = [UILabel new]; _searchLbl.text = @"搜索音乐、歌手"; _searchLbl.font = [UIFont systemFontOfSize:14]; _searchLbl.textColor = UIColor.secondaryLabelColor; _searchLbl.textAlignment = NSTextAlignmentCenter; _searchLbl.userInteractionEnabled = YES;
    [_searchLbl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapSearch)]];
    [_p1 addSubview:_searchLbl];
    _pc = [UIPageControl new]; _pc.userInteractionEnabled = NO; _pc.transform = CGAffineTransformMakeScale(0.55, 0.55); [self addSubview:_pc];

    _lb = [UIButton buttonWithType:UIButtonTypeSystem]; _rb = [UIButton buttonWithType:UIButtonTypeSystem]; _lb.tintColor = _rb.tintColor = UIColor.labelColor;
    [_lb addTarget:self action:@selector(tapLeft) forControlEvents:UIControlEventTouchUpInside];
    [_rb addTarget:self action:@selector(tapRight) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_lb]; [self addSubview:_rb];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    for (NSString *nn in @[LTBNoteSong, LTBNoteState]) [nc addObserver:self selector:@selector(refresh) name:nn object:nil];
    [nc addObserver:self selector:@selector(progress) name:LTBNoteProgress object:nil];
    [nc addObserver:self selector:@selector(prefs) name:LTBNotePrefs object:nil];
    [self refresh]; [self prefs]; [self syncSelection];
    // the avatar service may not be ready right at launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self refreshCenter]; });
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)setQuickOpen:(BOOL)o { _quickOpen = o; }

static NSString *ActSym(NSString *a) {
    return @{@"scan": @"viewfinder", @"wxsettings": @"gearshape.fill", @"liquidui": @"slider.horizontal.3", @"settings": @"slider.horizontal.3", @"quick": @"puzzlepiece.extension", @"music": @"music.note.list", @"inbox": @"envelope", @"none": @"circle.dashed"}[a] ?: @"circle";
}
- (void)prefs {
    [_lb setImage:SF(ActSym(LTBStr(@"leftAct", @"wxsettings")), 21, UIImageSymbolWeightRegular) forState:UIControlStateNormal];
    [_rb setImage:SF(ActSym(LTBStr(@"rightAct", @"quick")), 21, UIImageSymbolWeightRegular) forState:UIControlStateNormal];
    [self refreshCenter]; [self setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)p { [super traitCollectionDidChange:p]; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    // geometry measured from the reference video (points at a 393pt-wide screen)
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, safe = self.safeAreaInsets.bottom;
    BOOL flat = _tabDrop == 0; CGFloat tabRad = _tabRad, tabDrop = _tabDrop, tabDh = _tabDh;
    CGFloat sRad = 21.5, sDrop = flat ? 0 : 8, sDh = flat ? 0 : 2, bsz = 43, side = round(W * 0.049), mB = MAX(safe - 14, 10);
    NSString *sm = LTBStr(@"stripMode", @"both"); BOOL stripOff = [sm isEqual:@"off"];
    CGFloat tabH = 2 * tabRad + tabDrop + tabDh;
    _tabR = CGRectMake(side, H - mB - tabH, W - 2 * side, tabH);
    CGFloat sTop = _tabR.origin.y - 2 * sRad - 7; _stripTop = sTop;
    BOOL sl = LTBBool(@"showLeft", YES), sr = LTBBool(@"showRight", YES);
    CGFloat bx = round(W * 0.043), x0 = sl ? bx + bsz + 12 : side, x1 = sr ? W - bx - bsz - 12 : W - side;
    _stripR = CGRectMake(x0, sTop, x1 - x0, 2 * sRad + sDrop + sDh);
    CGFloat by = sTop + sRad + sDrop + 8 - bsz / 2; if (flat) by = sTop + sRad - bsz / 2;
    CGRect lr = CGRectMake(bx, by, bsz, bsz), rr = CGRectMake(W - bx - bsz, by, bsz, bsz);
    _lb.hidden = !sl; _rb.hidden = !sr; _lb.frame = lr; _rb.frame = rr;

    if (_glass) {
        _tabHost.frame = _tabR; CGRect lt = CGRectMake(0, 0, _tabR.size.width, _tabR.size.height); NSUInteger N = _segs.count;
        for (NSUInteger k = 0; k < N; k++) {
            UIVisualEffectView *g = _segs[k]; g.transform = CGAffineTransformIdentity;
            g.bounds = CGRectMake(0, 0, lt.size.width, 2 * tabRad); g.center = CGPointMake(lt.size.width / 2, lt.size.height / 2); GlassShape(g, tabRad, YES);
        }
        _stripG.hidden = stripOff; _stripG.frame = CGRectMake(_stripR.origin.x, _stripR.origin.y, _stripR.size.width, 2 * sRad); GlassShape(_stripG, sRad, YES);
        _lG.hidden = !sl; _rG.hidden = !sr; _lG.frame = lr; _rG.frame = rr; GlassShape(_lG, bsz / 2, YES); GlassShape(_rG, bsz / 2, YES);
    } else {
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:ArcCapsule(_tabR, tabRad, tabDrop, tabDh)]; if (!stripOff) [all appendPath:ArcCapsule(_stripR, sRad, sDrop, sDh)];
        if (sl) [all appendPath:[UIBezierPath bezierPathWithOvalInRect:lr]];
        if (sr) [all appendPath:[UIBezierPath bezierPathWithOvalInRect:rr]];
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        _blur.frame = self.bounds; _mask.frame = self.bounds; _mask.path = all.CGPath;
        [CATransaction commit];
        [_fx update:all.CGPath bounds:self.bounds traits:self.traitCollection];
    }

    NSUInteger n = _items.count, slots = n + 1, di = n / 2; CGFloat ix0 = _tabR.origin.x + 12, sw = (_tabR.size.width - 24) / slots;
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger slot = i < di ? i : i + 1; CGFloat cx = ix0 + sw * (slot + 0.5), cy = CapCY(_tabR, tabRad, tabDrop, tabDh, cx);
        _items[i].bounds = CGRectMake(0, 0, MIN(sw, 56), 50); _items[i].center = CGPointMake(cx, cy);
        CGFloat bw = MAX(14, _badges[i].frame.size.width); _badges[i].frame = CGRectMake(cx + 4, cy - 19, bw, 14);
    }
    CGFloat dcx = ix0 + sw * (di + 0.5); _disc.bounds = CGRectMake(0, 0, 38, 38); _disc.center = CGPointMake(dcx, CapCY(_tabR, tabRad, tabDrop, tabDh, dcx)); _disc.layer.cornerRadius = 19;
    [self placePill:NO];

    NSMutableArray *pages = [NSMutableArray array];
    if ([sm isEqual:@"both"] || [sm isEqual:@"mini"]) [pages addObject:_p0];
    if ([sm isEqual:@"both"] || [sm isEqual:@"search"]) [pages addObject:_p1];
    _sv.hidden = stripOff; _p0.hidden = ![pages containsObject:_p0]; _p1.hidden = ![pages containsObject:_p1];
    CGFloat w = _stripR.size.width - 12, h = 2 * sRad + (flat ? 0 : 6);
    _sv.frame = CGRectMake(_stripR.origin.x + 6, _stripR.origin.y, w, h); _sv.contentSize = CGSizeMake(w * MAX(pages.count, 1), h);
    for (NSUInteger k = 0; k < pages.count; k++) ((UIView *)pages[k]).frame = CGRectMake(w * k, 0, w, h);
    _pc.numberOfPages = pages.count; _pc.hidden = stripOff || pages.count < 2; _pc.frame = CGRectMake(_stripR.origin.x, CGRectGetMaxY(_stripR) - 13, _stripR.size.width - 10, 8);
    CGFloat tw2 = w - 46 - 78;
    _art.frame = CGRectMake(5, (flat ? 6 : 10), 31, 31); _art.layer.cornerRadius = 15.5;
    _title.frame = CGRectMake(46, (flat ? 3 : 7), tw2, 20); _artist.frame = CGRectMake(46, (flat ? 22 : 26), tw2, 14);
    _trk.frame = CGRectMake(46, (flat ? 38 : 42), MIN(tw2, 118), 2); [self progress];
    CGFloat cyc = flat ? 22 : 27; CGFloat nxc = w - 20, plc = nxc - 24, pvc = plc - 24;
    _prev.bounds = _play.bounds = _next.bounds = CGRectMake(0, 0, 34, 34);
    _prev.center = CGPointMake(pvc, cyc); _play.center = CGPointMake(plc, cyc); _next.center = CGPointMake(nxc, cyc);
    _searchLbl.frame = CGRectMake(12, 0, w - 24, h);
}
- (void)placePill:(BOOL)anim {
    if (_sel < 0 || _sel >= (NSInteger)_items.count) return;
    UIButton *b = _items[_sel]; CGFloat pw = _tabR.size.width * 0.23, ph = 46;
    CGFloat cx = MAX(_tabR.origin.x + 6 + pw / 2, MIN(b.center.x, CGRectGetMaxX(_tabR) - 6 - pw / 2));
    CGPoint c = CGPointMake(cx, CapCY(_tabR, _tabRad, _tabDrop, _tabDh, cx)); CGFloat ang = CapAngle(_tabR, _tabRad, _tabDrop, _tabDh, cx);
    void (^set)(void) = ^{
        self->_pill.transform = CGAffineTransformIdentity; self->_pill.bounds = CGRectMake(0, 0, pw, ph); self->_pill.center = c;
        self->_pill.layer.cornerRadius = ph / 2; self->_pill.transform = CGAffineTransformMakeRotation(ang);
    };
    if (anim) [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.3 options:0 animations:set completion:nil]; else set();
}
- (void)syncSelection {
    NSInteger s = _tbc.selectedIndex; if (s == _sel) return;
    _sel = s; [self placePill:_pill.bounds.size.width > 0];
}
- (void)syncBadges {
    for (NSUInteger i = 0; i < _badges.count && i < _tbc.viewControllers.count; i++) {
        NSString *v = _tbc.viewControllers[i].tabBarItem.badgeValue ?: @""; if ([v isEqualToString:_badgeCache[i]]) continue;
        _badgeCache[i] = v; UILabel *l = _badges[i]; l.hidden = v.length == 0;
        if (v.length) { l.text = v; CGFloat w = MAX(14, [v sizeWithAttributes:@{NSFontAttributeName: l.font}].width + 7); CGRect f = l.frame; f.size = CGSizeMake(w, 14); l.frame = f; }
    }
}
- (void)tapItem:(UIButton *)b {
    UITabBarController *t = _tbc; if (!t || b.tag >= (NSInteger)t.viewControllers.count) return;
    [LTBMgr closePanels];
    UIViewController *vc = t.viewControllers[b.tag]; BOOL same = t.selectedIndex == b.tag;
    t.selectedViewController = vc;
    if ([t.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [t.delegate tabBarController:t didSelectViewController:vc];
    if (same && [vc isKindOfClass:[UINavigationController class]]) [(UINavigationController *)vc popToRootViewControllerAnimated:YES];
    [[UIImpactFeedbackGenerator new] impactOccurred];
    [self syncSelection];
}
- (void)refresh {
    LTBSong *s = LTBP.song;
    _title.text = s.name ?: @"未在播放"; _artist.text = s.artist ?: @"点击打开音乐面板";
    if (!s.pic) { _art.image = SF(@"music.note", 18, UIImageSymbolWeightRegular); _art.tintColor = UIColor.whiteColor; _art.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1]; _art.contentMode = UIViewContentModeCenter; }
    else LTBImage(s.pic, ^(UIImage *i) { if (LTBP.song == s && i) { self->_art.image = i; self->_art.contentMode = UIViewContentModeScaleAspectFill; } });
    [_play setImage:SF(LTBP.playing ? @"pause.fill" : @"play.fill", 16, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    [self refreshCenter];
}
// what the middle button of the tab bar shows: album cover / my avatar / a picked photo / plus / note / nothing
- (void)refreshCenter {
    NSString *st = LTBStr(@"centerStyle", @"cover"); _disc.hidden = [st isEqual:@"none"]; if (_disc.hidden) return;
    void (^ph)(NSString *) = ^(NSString *sym) {
        self->_disc.image = SF(sym, 20, UIImageSymbolWeightRegular); self->_disc.tintColor = UIColor.whiteColor;
        self->_disc.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1]; self->_disc.contentMode = UIViewContentModeCenter;
    };
    void (^img)(UIImage *) = ^(UIImage *i) { self->_disc.image = i; self->_disc.backgroundColor = UIColor.clearColor; self->_disc.contentMode = UIViewContentModeScaleAspectFill; };
    if ([st isEqual:@"plus"]) { _disc.image = SF(@"plus", 22, UIImageSymbolWeightSemibold); _disc.tintColor = UIColor.labelColor; _disc.backgroundColor = Dyn(1, 1, 0.30, 1); _disc.contentMode = UIViewContentModeCenter; }
    else if ([st isEqual:@"note"]) ph(@"music.note");
    else if ([st isEqual:@"photo"]) { UIImage *i = [UIImage imageWithContentsOfFile:LTBStr(@"centerPhoto", @"")]; if (i) img(i); else ph(@"photo"); }
    else if ([st isEqual:@"avatar"]) {
        NSString *au = AvatarURL(); ph(@"person.fill");
        if (au) LTBImage(au, ^(UIImage *i) { if (i && [LTBStr(@"centerStyle", @"cover") isEqual:@"avatar"]) img(i); });
    } else {
        LTBSong *s = LTBP.song; ph(@"music.note");
        if (s.pic) LTBImage(s.pic, ^(UIImage *i) { if (i && LTBP.song == s && [LTBStr(@"centerStyle", @"cover") isEqual:@"cover"]) img(i); });
    }
}
- (void)progress {
    CGFloat f = LTBP.duration > 0 ? LTBP.current / LTBP.duration : 0; _fil.frame = CGRectMake(0, 0, _trk.bounds.size.width * MIN(MAX(f, 0), 1), 2);
}
- (void)scrollViewDidScroll:(UIScrollView *)s { if (s.bounds.size.width > 0) _pc.currentPage = (NSInteger)lround(s.contentOffset.x / s.bounds.size.width); }
- (void)doPrev { [LTBP prev]; } - (void)doNext { [LTBP next]; } - (void)doPlay { [LTBP toggle]; }
- (void)tapMini { [LTBMgr openMusic:NO]; }
- (void)tapDisc { [LTBMgr runAction:LTBStr(@"centerAct", @"music")]; }
- (void)longDisc:(UILongPressGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan) { [LTBP toggle]; [[UIImpactFeedbackGenerator new] impactOccurred]; } }
- (void)tapSearch { [LTBMgr openMusic:YES]; }
- (void)tapLeft { [LTBMgr runAction:LTBStr(@"leftAct", @"wxsettings")]; }
- (void)tapRight { [LTBMgr runAction:LTBStr(@"rightAct", @"quick")]; }
@end

#pragma mark - panels
@interface LTBPanel : LTBGlass
@property(nonatomic) BOOL hingeLeft;
- (void)willShow;
@end
@implementation LTBPanel
- (void)willShow {}
@end

@interface LTBMusicPanel : LTBPanel <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
- (void)focusSearch;
@end
@implementation LTBMusicPanel {
    UIImageView *_art; UILabel *_title, *_artist, *_lyric; UIButton *_prev, *_play, *_next, *_go, *_mode, *_trash;
    UISlider *_prog; UITextField *_field; UISegmentedControl *_seg; UITableView *_tv; NSArray *_results;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.radius = 38; self.bulge = 14; UIView *c = self.contentView;
    _art = [UIImageView new]; _art.contentMode = UIViewContentModeScaleAspectFill; _art.clipsToBounds = YES; _art.layer.cornerRadius = 28; _art.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.25];
    _title = [UILabel new]; _title.font = [UIFont boldSystemFontOfSize:18]; _title.textColor = UIColor.labelColor;
    _artist = [UILabel new]; _artist.font = [UIFont systemFontOfSize:13]; _artist.textColor = UIColor.secondaryLabelColor;
    _lyric = [UILabel new]; _lyric.font = [UIFont systemFontOfSize:12]; _lyric.textColor = UIColor.tertiaryLabelColor;
    _prev = Btn(@"backward.end.fill", 18, self, @selector(doPrev)); _next = Btn(@"forward.end.fill", 18, self, @selector(doNext));
    _play = Btn(@"play.fill", 22, self, @selector(doPlay)); _play.backgroundColor = UIColor.labelColor; _play.tintColor = UIColor.systemBackgroundColor; _play.layer.cornerRadius = 25;
    _prog = [UISlider new]; [_prog setThumbImage:[UIImage new] forState:UIControlStateNormal]; _prog.minimumTrackTintColor = UIColor.labelColor; _prog.maximumTrackTintColor = [UIColor colorWithWhite:0.5 alpha:0.25];
    [_prog addTarget:self action:@selector(seek) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    _field = [UITextField new]; _field.placeholder = @"歌曲、艺人"; _field.returnKeyType = UIReturnKeySearch; _field.delegate = self; _field.font = [UIFont systemFontOfSize:15];
    _field.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.15]; _field.layer.cornerRadius = 20; _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIImageView *mg = [[UIImageView alloc] initWithImage:SF(@"magnifyingglass", 14, UIImageSymbolWeightRegular)]; mg.tintColor = UIColor.secondaryLabelColor; mg.contentMode = UIViewContentModeCenter; mg.frame = CGRectMake(0, 0, 36, 40);
    _field.leftView = mg; _field.leftViewMode = UITextFieldViewModeAlways;
    _go = [UIButton buttonWithType:UIButtonTypeSystem]; [_go setTitle:@"搜索" forState:UIControlStateNormal]; _go.tintColor = Red(); _go.titleLabel.font = [UIFont boldSystemFontOfSize:15]; [_go addTarget:self action:@selector(doSearch) forControlEvents:UIControlEventTouchUpInside];
    _seg = [[UISegmentedControl alloc] initWithItems:@[@"播放列表", @"搜索结果", @"歌单"]]; _seg.selectedSegmentIndex = 0; [_seg addTarget:self action:@selector(segChanged) forControlEvents:UIControlEventValueChanged];
    _mode = [UIButton buttonWithType:UIButtonTypeSystem]; _mode.tintColor = UIColor.labelColor; [_mode addTarget:self action:@selector(doMode) forControlEvents:UIControlEventTouchUpInside]; _mode.titleLabel.font = [UIFont systemFontOfSize:14];
    _trash = Btn(@"trash", 16, self, @selector(doClear)); _trash.tintColor = UIColor.secondaryLabelColor;
    _tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; _tv.backgroundColor = UIColor.clearColor; _tv.dataSource = self; _tv.delegate = self; _tv.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag; _tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    UILabel *ft = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)]; ft.text = @"滑至底部了"; ft.font = [UIFont systemFontOfSize:12]; ft.textColor = UIColor.tertiaryLabelColor; ft.textAlignment = NSTextAlignmentCenter; _tv.tableFooterView = ft;
    for (UIView *v in @[_art, _title, _artist, _lyric, _prev, _play, _next, _prog, _field, _go, _seg, _mode, _trash, _tv]) [c addSubview:v];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(sync) name:LTBNoteSong object:nil]; [nc addObserver:self selector:@selector(sync) name:LTBNoteState object:nil];
    [nc addObserver:self selector:@selector(progress) name:LTBNoteProgress object:nil];
    [self sync]; return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)willShow { [self sync]; [_tv reloadData]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, p = 28, d = 18, tw = W - p - 68 - 160;
    _art.frame = CGRectMake(p, 14 + d, 56, 56);
    _title.frame = CGRectMake(p + 68, 14 + d, tw, 24); _artist.frame = CGRectMake(p + 68, 38 + d, tw, 18); _lyric.frame = CGRectMake(p + 68, 56 + d, tw, 16);
    _prev.frame = CGRectMake(W - 160, 14 + d, 36, 56); _play.frame = CGRectMake(W - 118, 19 + d, 50, 50); _next.frame = CGRectMake(W - 62, 14 + d, 36, 56);
    _prog.frame = CGRectMake(p, 78 + d, W - 2 * p, 14);
    _field.frame = CGRectMake(p, 100 + d, W - 2 * p, 40); _go.frame = CGRectMake(W - p - 64, 100 + d, 64, 40);
    _seg.frame = CGRectMake(p, 148 + d, W - 2 * p, 32);
    _mode.frame = CGRectMake(p, 186 + d, 130, 30); _mode.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft; _trash.frame = CGRectMake(W - p - 36, 186 + d, 36, 30);
    _tv.frame = CGRectMake(16, 220 + d, W - 32, self.bounds.size.height - 220 - d - 34);
}
- (void)sync {
    LTBSong *s = LTBP.song; _title.text = s.name ?: @"未在播放"; _artist.text = s.artist ?: @"搜索歌曲或选择歌单";
    [_mode setTitle:[@"  " stringByAppendingString:LTBP.modeTitle] forState:UIControlStateNormal];
    [_mode setImage:SF(LTBP.mode == 1 ? @"repeat.1" : (LTBP.mode == 2 ? @"shuffle" : @"repeat"), 14, UIImageSymbolWeightRegular) forState:UIControlStateNormal];
    [_play setImage:SF(LTBP.playing ? @"pause.fill" : @"play.fill", 22, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    if (s.pic) LTBImage(s.pic, ^(UIImage *i) { if (LTBP.song == s) self->_art.image = i; }); else _art.image = nil;
    if (_seg.selectedSegmentIndex == 0) [_tv reloadData];
}
- (void)progress { _lyric.text = LTBP.lyricLine; if (!_prog.tracking && LTBP.duration > 0) _prog.value = LTBP.current / LTBP.duration; }
- (void)seek { [LTBP seek:_prog.value]; }
- (void)doPrev { [LTBP prev]; } - (void)doNext { [LTBP next]; } - (void)doPlay { [LTBP toggle]; }
- (void)doMode { [LTBP cycleMode]; [self sync]; }
- (void)doClear { [LTBP clear]; [_tv reloadData]; }
- (void)segChanged { [_tv reloadData]; }
- (void)focusSearch { [_field becomeFirstResponder]; }
- (BOOL)textFieldShouldReturn:(UITextField *)f { [self doSearch]; return YES; }
- (void)doSearch {
    NSString *kw = [_field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; if (!kw.length) return;
    [_field resignFirstResponder]; _seg.selectedSegmentIndex = 1; _results = @[]; [_tv reloadData];
    [TM search:kw source:LTBStr(@"searchSrc", @"netease") completion:^(NSArray<LTBSong *> *a) { self->_results = a; [self->_tv reloadData]; if (!a.count) [self toast:@"没有搜到结果"]; }];
}
- (void)toast:(NSString *)t {
    UILabel *l = [UILabel new]; l.text = [NSString stringWithFormat:@"  %@  ", t]; l.font = [UIFont systemFontOfSize:13]; l.textColor = UIColor.whiteColor; l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; l.layer.cornerRadius = 14; l.clipsToBounds = YES;
    [l sizeToFit]; l.frame = CGRectMake(0, 0, l.frame.size.width, 28); l.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height - 60); [self addSubview:l];
    [UIView animateWithDuration:0.3 delay:1.6 options:0 animations:^{ l.alpha = 0; } completion:^(BOOL f) { [l removeFromSuperview]; }];
}
- (NSArray *)playlists { return LTBObj(@"playlists") ?: @[]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (_seg.selectedSegmentIndex) { case 0: return LTBP.songs.count; case 1: return _results.count; default: return [self playlists].count + 1; }
}
- (void)rowDelete:(UIButton *)b {
    NSInteger m = _seg.selectedSegmentIndex;
    if (m == 0 && b.tag < (NSInteger)LTBP.songs.count) { [LTBP.songs removeObjectAtIndex:b.tag]; }
    else if (m == 2 && b.tag >= 1) { NSMutableArray *a = [[self playlists] mutableCopy]; if (b.tag - 1 < (NSInteger)a.count) { [a removeObjectAtIndex:b.tag - 1]; LTBSetObj(@"playlists", a); } }
    [_tv reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = UIColor.clearColor; c.textLabel.font = [UIFont systemFontOfSize:16]; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    NSInteger m = _seg.selectedSegmentIndex;
    if (m == 2) {
        if (ip.row == 0) { c.textLabel.text = @"＋ 添加歌单"; c.textLabel.textColor = Red(); c.detailTextLabel.text = @"输入网易云 / QQ音乐歌单 ID"; return c; }
        NSDictionary *d = [self playlists][ip.row - 1];
        c.textLabel.text = d[@"name"]; c.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", [d[@"source"] isEqual:@"qq"] ? @"QQ音乐" : @"网易云", d[@"id"]];
        c.imageView.image = SF(@"music.note.list", 18, UIImageSymbolWeightRegular); c.imageView.tintColor = UIColor.labelColor;
    } else {
        LTBSong *s = m == 0 ? LTBP.songs[ip.row] : _results[ip.row];
        c.textLabel.text = s.name; c.detailTextLabel.text = s.artist;
        if (m == 0 && ip.row == LTBP.index) c.textLabel.textColor = Red();
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40)];
        c.imageView.image = [r imageWithActions:^(UIGraphicsImageRendererContext *x) { [[UIColor colorWithWhite:0.5 alpha:0.25] setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 40, 40)] fill]; }];
        LTBImage(s.pic, ^(UIImage *i) { if (i) { UITableViewCell *cc = [t cellForRowAtIndexPath:ip]; cc.imageView.image = Thumb(i, 40); } });
    }
    if (m != 1) {
        UIButton *x = [UIButton buttonWithType:UIButtonTypeSystem]; [x setTitle:@"—" forState:UIControlStateNormal]; x.tintColor = Red(); x.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        x.frame = CGRectMake(0, 0, 40, 40); x.tag = ip.row; [x addTarget:self action:@selector(rowDelete:) forControlEvents:UIControlEventTouchUpInside]; c.accessoryView = x;
    }
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES]; NSInteger m = _seg.selectedSegmentIndex;
    if (m == 0) { [LTBP playIndex:ip.row]; }
    else if (m == 1) {
        LTBSong *s = _results[ip.row]; NSInteger at = -1;
        for (NSUInteger i = 0; i < LTBP.songs.count; i++) if ([LTBP.songs[i].url isEqual:s.url]) at = i;
        if (at < 0) { [LTBP.songs addObject:s]; at = LTBP.songs.count - 1; }
        [LTBP playIndex:at]; [self toast:@"已加入播放列表"];
    } else if (ip.row == 0) [self addPlaylist];
    else {
        NSDictionary *d = [self playlists][ip.row - 1]; [self toast:@"正在加载歌单…"];
        [TM loadPlaylist:d[@"id"] source:d[@"source"] completion:^(NSArray<LTBSong *> *a) {
            if (!a.count) { [self toast:@"歌单加载失败"]; return; }
            LTBSetStr(@"lastpl", [NSString stringWithFormat:@"%@:%@", d[@"source"], d[@"id"]]);
            [LTBP setSongs:a play:0]; self->_seg.selectedSegmentIndex = 0; [self->_tv reloadData];
        }];
    }
}
- (void)addPlaylist {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加歌单" message:@"网易云：分享链接 id= 后面的数字\nQQ音乐：分享链接 playlist/ 后面的数字" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"歌单 ID"; f.keyboardType = UIKeyboardTypeNumberPad; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"名称（可选）"; }];
    void (^add)(NSString *) = ^(NSString *src) {
        NSString *pid = [a.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; if (!pid.length) return;
        NSString *nm = a.textFields[1].text.length ? a.textFields[1].text : [@"歌单 " stringByAppendingString:pid];
        NSMutableArray *l = [[self playlists] mutableCopy]; [l addObject:@{@"id": pid, @"source": src, @"name": nm}]; LTBSetObj(@"playlists", l); [self->_tv reloadData];
    };
    [a addAction:[UIAlertAction actionWithTitle:@"网易云" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { add(@"netease"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"QQ音乐" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { add(@"qq"); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController; while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:a animated:YES completion:nil];
}
@end

// round raised button with icon + caption, laid out on an arc like the reference
@interface LTBQItem : UIControl
@property(nonatomic, copy) NSString *ident;
- (instancetype)initWithTitle:(NSString *)t symbol:(NSString *)s;
@end
@implementation LTBQItem
- (instancetype)initWithTitle:(NSString *)t symbol:(NSString *)s {
    if (!(self = [super initWithFrame:CGRectMake(0, 0, 76, 84)])) return nil;
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(11, 0, 54, 54)]; c.userInteractionEnabled = NO; c.backgroundColor = Dyn(1, 1, 0.26, 1); c.layer.cornerRadius = 27;
    c.layer.shadowOpacity = 0.12; c.layer.shadowRadius = 8; c.layer.shadowOffset = CGSizeMake(0, 3); c.layer.shadowColor = UIColor.blackColor.CGColor; [self addSubview:c];
    UIImageView *iv = [[UIImageView alloc] initWithImage:SF(s, 21, UIImageSymbolWeightRegular)]; iv.tintColor = UIColor.labelColor; iv.contentMode = UIViewContentModeCenter; iv.frame = c.bounds; [c addSubview:iv];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(-4, 60, 84, 18)]; l.text = t; l.font = [UIFont systemFontOfSize:12]; l.textColor = UIColor.labelColor; l.textAlignment = NSTextAlignmentCenter; l.userInteractionEnabled = NO; [self addSubview:l];
    return self;
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; self.alpha = h ? 0.6 : 1; }
@end

@interface LTBQuickPanel : LTBPanel
@end
@implementation LTBQuickPanel {
    NSMutableArray<LTBQItem *> *_btns;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.radius = 38; self.bulge = 16; _btns = [NSMutableArray array];
    return self;
}
- (void)willShow {
    for (UIView *b in _btns) [b removeFromSuperview]; [_btns removeAllObjects];
    for (NSDictionary *d in QuickItems()) {
        if (!LTBBool([@"qk_" stringByAppendingString:d[@"id"]], YES)) continue;
        LTBQItem *b = [[LTBQItem alloc] initWithTitle:d[@"t"] symbol:d[@"s"]]; b.ident = d[@"id"];
        [b addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:b]; [_btns addObject:b];
    }
    [self setNeedsLayout];
}
- (CGFloat)neededHeight { return 40 + ceil(_btns.count / 5.0) * 100 + 26; }
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat W = self.bounds.size.width, pad = 20, pitch = (W - 2 * pad) / 5, A = 14;
    for (NSUInteger i = 0; i < _btns.count; i++) {
        CGFloat cx = pad + pitch * (i % 5 + 0.5), t = (cx - W / 2) / (W / 2);
        CGFloat cy = 44 + 100 * (i / 5) + 42 + A * t * t - A * 0.6;
        _btns[i].transform = CGAffineTransformIdentity; _btns[i].center = CGPointMake(cx, cy);
        _btns[i].transform = CGAffineTransformMakeRotation(atan(2 * A * t / (W / 2)));
    }
}
- (void)tap:(LTBQItem *)b {
    for (NSDictionary *d in QuickItems()) if ([d[@"id"] isEqual:b.ident]) {
        if (d[@"a"]) { [LTBMgr runAction:d[@"a"]]; return; }
        if (d[@"u"]) { [LTBMgr closePanels]; OpenWX(d[@"u"]); return; }
        [LTBMgr toast:@"该功能暂未接入"];
    }
}
@end

#pragma mark - manager
static BOOL Eligible(UITabBarController *t);
static void ApplyStyle(void) {
    UIUserInterfaceStyle s = LTBBool(@"dark", NO) ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified;
    for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows) w.overrideUserInterfaceStyle = s;
    }
}

@implementation LTBManager {
    __weak UITabBarController *_tbc; LTBHost *_host; LTBBar *_bar; LTBPanel *_panel; UIControl *_dim; NSTimer *_timer, *_scan; BOOL _shown;
}
+ (instancetype)shared { static LTBManager *m; static dispatch_once_t o; dispatch_once(&o, ^{ m = [LTBManager new]; }); return m; }

static BOOL Eligible(UITabBarController *t) {
    NSUInteger n = t.viewControllers.count; if (n < 3 || n > 5 || !t.view.window) return NO;
    return [NSStringFromClass(t.class) containsString:@"MMTabBar"] || t.view.window.rootViewController == t;
}
static UITabBarController *FindTBC(UIViewController *v, int d) {
    if (!v || d > 8) return nil;
    if ([v isKindOfClass:[UITabBarController class]] && Eligible((UITabBarController *)v)) return (UITabBarController *)v;
    for (UIViewController *c in v.childViewControllers) { UITabBarController *r = FindTBC(c, d + 1); if (r) return r; }
    return FindTBC(v.presentedViewController, d + 1);
}
static UIWindow *KeyWin(void) {
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) return w;
    }
    return [UIApplication sharedApplication].keyWindow;
}
static UIViewController *TopVC(void) { UIViewController *t = KeyWin().rootViewController; while (t.presentedViewController) t = t.presentedViewController; return t; }

// polled independently of hooks so we keep working next to other tweaks
- (void)start {
    if (_scan) return;
    _scan = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { [self discover]; }];
}
- (void)discover {
    if (!LTBBool(@"enabled", YES)) return;
    if (_tbc && _host.superview == _tbc.view && _tbc.view.window) return;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)s).windows) {
            UITabBarController *t = FindTBC(w.rootViewController, 0);
            if (t) { [self attach:t]; return; }
        }
    }
}
- (void)attach:(UITabBarController *)t {
    if (!Eligible(t)) return;
    if (!LTBBool(@"enabled", YES)) { [self detach]; return; }
    CGFloat safe = t.view.safeAreaInsets.bottom, H = t.view.bounds.size.height, W = t.view.bounds.size.width, bh = 146 + safe;
    if (_tbc == t && _host.superview == t.view) {
        if (!CGRectEqualToRect(_host.frame, t.view.bounds)) _host.frame = t.view.bounds;
        CGRect bf = CGRectMake(0, H - bh, W, bh); if (!CGRectEqualToRect(_bar.frame, bf)) _bar.frame = bf;
        if (t.tabBar.alpha != 0) t.tabBar.alpha = 0;
        if (t.view.subviews.lastObject != _host) [t.view bringSubviewToFront:_host];
        return;
    }
    [self detach]; _tbc = t;
    _host = [[LTBHost alloc] initWithFrame:t.view.bounds]; _host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CATransform3D p = CATransform3DIdentity; p.m34 = -1.0 / 1000; _host.layer.sublayerTransform = p;
    _bar = [[LTBBar alloc] initWithFrame:CGRectMake(0, H - bh, W, bh) controller:t]; _bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_host addSubview:_bar]; [t.view addSubview:_host]; t.tabBar.alpha = 0; _shown = YES;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged) name:LTBNotePrefs object:nil];
    if (LTBBool(@"dark", NO)) ApplyStyle();
    [LTBP loadDefaultIfNeeded];
}
- (void)detach {
    [_timer invalidate]; _timer = nil; [self closePanelsAnimated:NO];
    if (_tbc) _tbc.tabBar.alpha = 1;
    [_host removeFromSuperview]; _host = nil; _bar = nil; _tbc = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LTBNotePrefs object:nil];
}
- (void)prefsChanged { if (_tbc && !LTBBool(@"enabled", YES)) [self detach]; }
- (void)sync { [_bar syncSelection]; }
- (BOOL)shouldShow {
    UITabBarController *t = _tbc; if (!t) return NO;
    UIViewController *s = t.selectedViewController;
    if ([s isKindOfClass:[UINavigationController class]]) {
        UINavigationController *n = (UINavigationController *)s;
        if (n.viewControllers.count > 1 && (n.topViewController.hidesBottomBarWhenPushed || t.tabBar.hidden)) return NO;
    }
    return YES;
}
- (void)tick {
    if (!_tbc || !_host.superview) { [self detach]; return; }
    if (_tbc.tabBar.alpha != 0) _tbc.tabBar.alpha = 0;
    [_bar syncBadges]; [_bar syncSelection];
    BOOL v = [self shouldShow];
    if (v != _shown) {
        _shown = v; if (!v) [self closePanels];
        [UIView animateWithDuration:0.3 animations:^{ self->_bar.alpha = v ? 1 : 0; self->_bar.transform = v ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 170); }];
    }
}
- (void)toast:(NSString *)t {
    if (!_host) return;
    UILabel *l = [UILabel new]; l.text = [NSString stringWithFormat:@"  %@  ", t]; l.font = [UIFont systemFontOfSize:13]; l.textColor = UIColor.whiteColor; l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75]; l.layer.cornerRadius = 15; l.clipsToBounds = YES;
    [l sizeToFit]; l.frame = CGRectMake(0, 0, l.frame.size.width + 8, 30); l.center = CGPointMake(_host.bounds.size.width / 2, CGRectGetMinY(_bar.frame) + _bar.stripTop - 20); [_host addSubview:l];
    [UIView animateWithDuration:0.3 delay:1.4 options:0 animations:^{ l.alpha = 0; } completion:^(BOOL f) { [l removeFromSuperview]; }];
}
- (void)runAction:(NSString *)a {
    if ([a isEqual:@"wxsettings"]) [self openWeChatSettings];
    else if ([a isEqual:@"liquidui"]) { [self closePanels]; [self tapMeRow:@"插件" native:NO]; }
    else if ([a isEqual:@"settings"]) [self openSettings];
    else if ([a isEqual:@"quick"]) [self openQuick];
    else if ([a isEqual:@"music"]) [self openMusic:NO];
    else if ([a isEqual:@"scan"]) { [self closePanels]; OpenWX(@"weixin://scanqrcode"); }
    else if ([a isEqual:@"inbox"]) {
        [self closePanels]; UITabBarController *t = _tbc; if (!t.viewControllers.count) return;
        t.selectedIndex = 0; UIViewController *v = t.viewControllers[0]; if ([v isKindOfClass:[UINavigationController class]]) [(UINavigationController *)v popToRootViewControllerAnimated:YES];
    }
    else if ([a isEqual:@"dark"]) { LTBSetBool(@"dark", !LTBBool(@"dark", NO)); ApplyStyle(); }
}
- (void)openSettings {
    [self closePanels];
    UIViewController *top = TopVC(); if (!top) return;
    if ([top isKindOfClass:[UINavigationController class]] && [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:[LTBSettingsVC class]]) return;
    [top presentViewController:[[UINavigationController alloc] initWithRootViewController:[LTBSettingsVC new]] animated:YES completion:nil];
}
// open a row of the "我" page of THIS WeChat (e.g. 设置 / 插件) by simulating the tap, so nothing leaves the app
- (void)tapMeRow:(NSString *)name native:(BOOL)native {
    UITabBarController *t = _tbc; if (!t.viewControllers.count) return;
    NSUInteger last = t.viewControllers.count - 1; t.selectedIndex = last;
    UIViewController *v = t.viewControllers[last];
    if ([v isKindOfClass:[UINavigationController class]]) [(UINavigationController *)v popToRootViewControllerAnimated:NO];
    [self attemptRow:name tries:0 native:native];
}
- (void)attemptRow:(NSString *)name tries:(int)n native:(BOOL)native {
    UITabBarController *t = _tbc; if (!t) return;
    UIViewController *v = t.viewControllers.lastObject;
    UIViewController *top = [v isKindOfClass:[UINavigationController class]] ? ((UINavigationController *)v).topViewController : v;
    int budget = 2500; UILabel *l = top.isViewLoaded ? FindLabel(top.view, name, 0, &budget) : nil;
    if (l && FireTap(l)) return;
    if (n < 8) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self attemptRow:name tries:n + 1 native:native]; }); return; }
    if (native && [self pushNativeSettings]) return;
    [self toast:[NSString stringWithFormat:@"未找到“%@”入口", name]];
}
- (BOOL)pushNativeSettings {
    UITabBarController *t = _tbc; Class c = NSClassFromString(@"NewSettingViewController"); if (!t || !c) return NO;
    @try {
        UIViewController *v = t.viewControllers.lastObject;
        if ([v isKindOfClass:[UINavigationController class]]) { UIViewController *vc = [[c alloc] init]; [(UINavigationController *)v pushViewController:vc animated:YES]; return YES; }
    } @catch (NSException *e) {}
    return NO;
}
- (void)openWeChatSettings { [self closePanels]; [self tapMeRow:@"设置" native:YES]; }
- (void)openMusic:(BOOL)focus {
    if ([_panel isKindOfClass:[LTBMusicPanel class]]) { if (focus) [(LTBMusicPanel *)_panel focusSearch]; else [self closePanels]; return; }
    LTBMusicPanel *p = [LTBMusicPanel new]; p.hingeLeft = YES; [self show:p height:560];
    if (focus) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [p focusSearch]; });
}
- (void)openQuick {
    if ([_panel isKindOfClass:[LTBQuickPanel class]]) { [self closePanels]; return; }
    LTBQuickPanel *p = [LTBQuickPanel new]; p.hingeLeft = NO; [p willShow]; [self show:p height:[p neededHeight]];
}
- (void)show:(LTBPanel *)p height:(CGFloat)h {
    if (!_host) return; [self closePanelsAnimated:NO];
    _dim = [[UIControl alloc] initWithFrame:_host.bounds]; _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_dim addTarget:self action:@selector(closePanels) forControlEvents:UIControlEventTouchUpInside]; [_host insertSubview:_dim belowSubview:_bar];
    CGFloat bottom = CGRectGetMinY(_bar.frame) + _bar.stripTop - 12, top = _host.safeAreaInsets.top + 12;
    h = MIN(h, bottom - top); CGRect f = CGRectMake(22, bottom - h, _host.bounds.size.width - 44, h);
    _panel = p; p.layer.anchorPoint = CGPointMake(p.hingeLeft ? 0 : 1, 0.5); p.frame = f;
    [p willShow]; [_host insertSubview:p belowSubview:_bar];
    _bar.quickOpen = [p isKindOfClass:[LTBQuickPanel class]];
    CASpringAnimation *sp = [CASpringAnimation animationWithKeyPath:@"transform.rotation.y"];
    sp.fromValue = @((p.hingeLeft ? -1 : 1) * M_PI_2 * 0.96); sp.toValue = @0; sp.mass = 1; sp.stiffness = 150; sp.damping = 15; sp.duration = sp.settlingDuration;
    [p.layer addAnimation:sp forKey:@"hinge"];
    p.alpha = 0; [UIView animateWithDuration:0.25 animations:^{ p.alpha = 1; }];
}
- (void)closePanels { [self closePanelsAnimated:YES]; }
- (void)closePanelsAnimated:(BOOL)anim {
    LTBPanel *p = _panel; UIView *d = _dim; _panel = nil; _dim = nil; [d removeFromSuperview]; _bar.quickOpen = NO; if (!p) return;
    [p endEditing:YES];
    if (!anim) { [p removeFromSuperview]; return; }
    CGFloat a = (p.hingeLeft ? -1 : 1) * M_PI_2 * 0.96;
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{ [p removeFromSuperview]; p.layer.transform = CATransform3DIdentity; }];
    CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"]; b.fromValue = @0; b.toValue = @(a); b.duration = 0.26;
    b.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]; b.fillMode = kCAFillModeForwards; b.removedOnCompletion = NO;
    [p.layer addAnimation:b forKey:@"close"]; [CATransaction commit];
    [UIView animateWithDuration:0.26 animations:^{ p.alpha = 0; }];
}
@end

#pragma mark - entry pill (injected into other plugins' settings pages)
@interface LTBEntry : LTBGlass
@end
@implementation LTBEntry { UILabel *_l; }
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.radius = 19; self.bulge = 4; self.tag = 0x4C5442;
    _l = [UILabel new]; _l.text = @"⚙︎ 液态底栏"; _l.font = [UIFont boldSystemFontOfSize:14]; _l.textAlignment = NSTextAlignmentCenter; _l.textColor = UIColor.labelColor;
    [self.contentView addSubview:_l];
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[LTBManager shared] action:@selector(openSettings)]];
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; _l.frame = self.contentView.bounds; }
@end
UIView *LTBEntryPill(void) { return [LTBEntry new]; }

#pragma mark - settings
@interface LTBSettingsVC () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end
@implementation LTBSettingsVC { NSArray *_data; }
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"液态底栏";
    if (self.navigationController.viewControllers.firstObject == self)
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [self build];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)build {
    NSArray *src = @[@[@"netease", @"网易云"], @[@"qq", @"QQ音乐"]];
    NSArray *act = @[@[@"scan", @"扫一扫"], @[@"wxsettings", @"微信设置"], @[@"liquidui", @"LiquidUI 设置"], @[@"settings", @"插件设置"], @[@"quick", @"快捷面板"], @[@"music", @"音乐面板"], @[@"inbox", @"微信首页"], @[@"none", @"无操作"]];
    NSArray *strip = @[@[@"both", @"迷你播放器 + 搜索（左右滑动）"], @[@"mini", @"仅迷你播放器"], @[@"search", @"仅搜索"], @[@"off", @"隐藏中间条"]];
    NSArray *center = @[@[@"cover", @"专辑封面"], @[@"avatar", @"我的头像"], @[@"photo", @"自定义图片"], @[@"plus", @"＋ 图标"], @[@"note", @"音符图标"], @[@"none", @"隐藏"]];
    NSArray *glass = @[@[@"blur", @"液态弧形（自绘，与效果图一致）"], @[@"flat", @"系统液态玻璃 · 直条（iOS 26）"]];
    NSMutableArray *qk = [NSMutableArray array];
    for (NSDictionary *d in QuickItems()) [qk addObject:@{@"t": d[@"t"], @"k": [@"qk_" stringByAppendingString:d[@"id"]], @"y": @"sw"}];
    _data = @[
        @{@"h": @"总开关", @"f": @"关闭后恢复微信原生底栏。", @"r": @[@{@"t": @"启用液态底栏", @"k": @"enabled", @"y": @"sw"}]},
        @{@"h": @"底栏上方 · 左侧按钮", @"r": @[
            @{@"t": @"显示", @"k": @"showLeft", @"y": @"sw"},
            @{@"t": @"点击功能（同时决定图标）", @"k": @"leftAct", @"y": @"ch", @"d": @"wxsettings", @"o": act}]},
        @{@"h": @"底栏上方 · 中间条", @"r": @[
            @{@"t": @"显示内容", @"k": @"stripMode", @"y": @"ch", @"d": @"both", @"o": strip}]},
        @{@"h": @"底栏上方 · 右侧按钮", @"r": @[
            @{@"t": @"显示", @"k": @"showRight", @"y": @"sw"},
            @{@"t": @"点击功能（同时决定图标）", @"k": @"rightAct", @"y": @"ch", @"d": @"quick", @"o": act}]},
        @{@"h": @"底栏中间按钮", @"f": @"“我的头像”读取当前登录账号的头像；“自定义图片”从相册选一张。", @"r": @[
            @{@"t": @"显示内容", @"k": @"centerStyle", @"y": @"ch", @"d": @"cover", @"o": center},
            @{@"t": @"点击功能", @"k": @"centerAct", @"y": @"ch", @"d": @"music", @"o": act},
            @{@"t": @"选择自定义图片…", @"k": @"pickimg", @"y": @"ac"}]},
        @{@"h": @"玻璃效果", @"f": @"修改后需重启微信生效。系统液态玻璃仅 iOS 26 可用，且无法做成弧形，只有直条。", @"r": @[
            @{@"t": @"样式", @"k": @"glass", @"y": @"ch", @"d": @"blur", @"o": glass}]},
        @{@"h": @"音乐", @"f": @"QQ 音乐及网易云兜底走 Meting 兼容接口，可换成自己的地址。", @"r": @[
            @{@"t": @"默认搜索来源", @"k": @"searchSrc", @"y": @"ch", @"d": @"netease", @"o": src},
            @{@"t": @"Meting API 地址", @"k": @"meting", @"y": @"tx", @"d": @"https://api.injahow.cn/meting/"},
            @{@"t": @"清空播放列表", @"k": @"clearq", @"y": @"ac"}]},
        @{@"h": @"快捷面板显示项目", @"f": @"没有对应入口的项目点击会提示暂未接入。", @"r": qk},
        @{@"h": @"", @"r": @[@{@"t": @"恢复默认设置", @"k": @"reset", @"y": @"ac"}]},
    ];
}
- (NSDictionary *)row:(NSIndexPath *)ip { return _data[ip.section][@"r"][ip.row]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return _data.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [_data[s][@"r"] count]; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return _data[s][@"h"]; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return _data[s][@"f"]; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *r = [self row:ip]; NSString *y = r[@"y"];
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil]; c.textLabel.text = r[@"t"];
    if ([y isEqual:@"sw"]) {
        UISwitch *s = [UISwitch new]; s.on = LTBBool(r[@"k"], YES); s.tag = ip.section * 100 + ip.row;
        [s addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = s; c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([y isEqual:@"ch"]) {
        NSString *cur = LTBStr(r[@"k"], r[@"d"]); for (NSArray *o in r[@"o"]) if ([o[0] isEqual:cur]) c.detailTextLabel.text = o[1];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([y isEqual:@"tx"]) { c.detailTextLabel.text = LTBStr(r[@"k"], r[@"d"]); c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    else c.textLabel.textColor = [r[@"k"] isEqual:@"reset"] ? UIColor.systemRedColor : self.view.tintColor;
    return c;
}
- (void)swChanged:(UISwitch *)s { NSDictionary *r = _data[s.tag / 100][@"r"][s.tag % 100]; LTBSetBool(r[@"k"], s.on); }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES]; NSDictionary *r = [self row:ip]; NSString *y = r[@"y"];
    if ([y isEqual:@"ch"]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:r[@"t"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSArray *o in r[@"o"]) [a addAction:[UIAlertAction actionWithTitle:o[1] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { LTBSetStr(r[@"k"], o[0]); [t reloadData]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        a.popoverPresentationController.sourceView = [t cellForRowAtIndexPath:ip]; [self presentViewController:a animated:YES completion:nil];
    } else if ([y isEqual:@"tx"]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:r[@"t"] message:nil preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.text = LTBStr(r[@"k"], r[@"d"]); f.keyboardType = UIKeyboardTypeURL; f.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
        [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { LTBSetStr(r[@"k"], a.textFields[0].text); [t reloadData]; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
    } else if ([y isEqual:@"ac"]) {
        NSString *k = r[@"k"];
        if ([k isEqual:@"clearq"]) [LTBP clear];
        else if ([k isEqual:@"pickimg"]) {
            UIImagePickerController *p = [UIImagePickerController new]; p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary; p.delegate = self;
            [self presentViewController:p animated:YES completion:nil];
        } else { LTBResetPrefs(); [t reloadData]; }
    }
}
- (void)imagePickerController:(UIImagePickerController *)p didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) {
        CGFloat s = 256; UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
        UIImage *sq = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
            CGFloat m = MIN(img.size.width, img.size.height), k = s / m; CGFloat w = img.size.width * k, h = img.size.height * k;
            [img drawInRect:CGRectMake((s - w) / 2, (s - h) / 2, w, h)];
        }];
        NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"ltb_center.jpg"] copy];
        if ([UIImageJPEGRepresentation(sq, 0.9) writeToFile:path atomically:YES]) { LTBSetStr(@"centerPhoto", path); LTBSetStr(@"centerStyle", @"photo"); }
    }
    [p dismissViewControllerAnimated:YES completion:nil]; [self.tableView reloadData];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)p { [p dismissViewControllerAnimated:YES completion:nil]; }
@end
