#import "LTB.h"
#import <objc/runtime.h>

#pragma mark - helpers
static UIColor *Red(void) { return [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1]; }
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
static NSArray *QuickItems(void) {
    return @[
        @{@"id": @"scan", @"t": @"扫一扫", @"s": @"qrcode.viewfinder", @"u": @"weixin://scanqrcode"},
        @{@"id": @"moments", @"t": @"朋友圈", @"s": @"camera.aperture", @"u": @"weixin://dl/moments"},
        @{@"id": @"oa", @"t": @"公众号", @"s": @"text.bubble", @"u": @"weixin://dl/officialaccounts"},
        @{@"id": @"games", @"t": @"游戏", @"s": @"gamecontroller", @"u": @"weixin://dl/games"},
        @{@"id": @"stickers", @"t": @"表情", @"s": @"face.smiling", @"u": @"weixin://dl/stickers"},
        @{@"id": @"shop", @"t": @"购物", @"s": @"bag", @"u": @"weixin://dl/shopping"},
        @{@"id": @"fav", @"t": @"收藏", @"s": @"archivebox", @"u": @"weixin://dl/favorites"},
        @{@"id": @"wxset", @"t": @"微信设置", @"s": @"gearshape", @"a": @"wxsettings"},
        @{@"id": @"ltbset", @"t": @"底栏设置", @"s": @"slider.horizontal.3", @"a": @"settings"},
        @{@"id": @"music", @"t": @"音乐", @"s": @"music.note.list", @"a": @"music"},
    ];
}

#pragma mark - glass (curved "pillow" shape)
static UIBezierPath *Pillow(CGRect r, CGFloat cr, CGFloat b) {
    CGFloat l = r.origin.x + b, t = r.origin.y + b, rr = CGRectGetMaxX(r) - b, bt = CGRectGetMaxY(r) - b, mx = CGRectGetMidX(r), my = CGRectGetMidY(r);
    cr = MAX(1, MIN(cr, MIN(rr - l, bt - t) / 2));
    BOOL side = (bt - t - 2 * cr) > 1;
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(l + cr, t)];
    [p addQuadCurveToPoint:CGPointMake(rr - cr, t) controlPoint:CGPointMake(mx, t - 2 * b)];
    [p addQuadCurveToPoint:CGPointMake(rr, t + cr) controlPoint:CGPointMake(rr, t)];
    if (side) [p addQuadCurveToPoint:CGPointMake(rr, bt - cr) controlPoint:CGPointMake(rr + 2 * b, my)];
    [p addQuadCurveToPoint:CGPointMake(rr - cr, bt) controlPoint:CGPointMake(rr, bt)];
    [p addQuadCurveToPoint:CGPointMake(l + cr, bt) controlPoint:CGPointMake(mx, bt + 2 * b)];
    [p addQuadCurveToPoint:CGPointMake(l, bt - cr) controlPoint:CGPointMake(l, bt)];
    if (side) [p addQuadCurveToPoint:CGPointMake(l, t + cr) controlPoint:CGPointMake(l - 2 * b, my)];
    [p addQuadCurveToPoint:CGPointMake(l + cr, t) controlPoint:CGPointMake(l, t)];
    [p closePath];
    return p;
}

@interface LTBGlass : UIVisualEffectView
@property(nonatomic) CGFloat radius, bulge;
@end
@implementation LTBGlass {
    CAShapeLayer *_mask, *_rim; CAGradientLayer *_hl;
}
- (instancetype)init {
    self = [super initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    if (self) {
        _radius = 24; _bulge = 0;
        _hl = [CAGradientLayer layer];
        _hl.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.35].CGColor, (id)[UIColor colorWithWhite:1 alpha:0.02].CGColor, (id)[UIColor colorWithWhite:1 alpha:0.14].CGColor];
        _hl.startPoint = CGPointMake(0.1, 0); _hl.endPoint = CGPointMake(0.9, 1);
        [self.contentView.layer insertSublayer:_hl atIndex:0];
        _rim = [CAShapeLayer layer]; _rim.fillColor = nil; _rim.lineWidth = 1.4; _rim.strokeColor = [UIColor colorWithWhite:1 alpha:0.6].CGColor;
        [self.contentView.layer addSublayer:_rim];
        _mask = [CAShapeLayer layer]; self.layer.mask = _mask;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds; if (b.size.width < 2) return;
    UIBezierPath *p = Pillow(b, _radius, _bulge);
    _mask.frame = b; _mask.path = p.CGPath; _rim.frame = b; _rim.path = p.CGPath; _hl.frame = self.contentView.bounds;
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
- (instancetype)initWithFrame:(CGRect)f controller:(UITabBarController *)t;
- (void)syncSelection;
- (void)syncBadges;
@end

@implementation LTBBar {
    LTBGlass *_tab, *_strip, *_left, *_right;
    UIView *_pill, *_p0, *_p1;
    NSMutableArray<UIButton *> *_items;
    NSMutableArray<UILabel *> *_badges;
    UIImageView *_disc, *_art;
    UIScrollView *_sv; UIPageControl *_pc;
    UILabel *_title, *_artist, *_searchLbl;
    UIButton *_prev, *_play, *_next, *_lb, *_rb;
    NSInteger _sel; CGFloat _stripTop;
}
- (CGFloat)stripTop { return _stripTop; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { UIView *v = [super hitTest:p withEvent:e]; return v == self ? nil : v; }

- (instancetype)initWithFrame:(CGRect)f controller:(UITabBarController *)t {
    if (!(self = [super initWithFrame:f])) return nil;
    _tbc = t; _items = [NSMutableArray array]; _badges = [NSMutableArray array];
    _tab = [LTBGlass new]; [self addSubview:_tab];
    _pill = [UIView new]; _pill.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.12]; _pill.layer.cornerCurve = kCACornerCurveContinuous;
    [_tab.contentView addSubview:_pill];
    NSArray *sym = @[@"message", @"person.2", @"safari", @"person"], *symF = @[@"message.fill", @"person.2.fill", @"safari.fill", @"person.fill"];
    NSUInteger n = t.viewControllers.count;
    for (NSUInteger i = 0; i < n; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem]; b.tag = i; b.tintColor = [UIColor labelColor];
        UITabBarItem *it = t.viewControllers[i].tabBarItem;
        if (n == 4) { [b setImage:SF(sym[i], 21, UIImageSymbolWeightRegular) forState:UIControlStateNormal];
                      [b setImage:SF(symF[i], 21, UIImageSymbolWeightRegular) forState:UIControlStateSelected]; }
        else { [b setImage:[it.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal]; }
        [b addTarget:self action:@selector(tapItem:) forControlEvents:UIControlEventTouchUpInside];
        [_tab.contentView addSubview:b]; [_items addObject:b];
        UILabel *bg = [UILabel new]; bg.backgroundColor = Red(); bg.textColor = UIColor.whiteColor; bg.font = [UIFont boldSystemFontOfSize:10];
        bg.textAlignment = NSTextAlignmentCenter; bg.layer.cornerRadius = 8; bg.clipsToBounds = YES; bg.hidden = YES; bg.userInteractionEnabled = NO;
        [_tab.contentView addSubview:bg]; [_badges addObject:bg];
    }
    _disc = [UIImageView new]; _disc.contentMode = UIViewContentModeScaleAspectFill; _disc.clipsToBounds = YES; _disc.userInteractionEnabled = YES;
    [_disc addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDisc)]];
    [_disc addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longDisc:)]];
    [_tab.contentView addSubview:_disc];

    _strip = [LTBGlass new]; [self addSubview:_strip];
    _sv = [UIScrollView new]; _sv.pagingEnabled = YES; _sv.showsHorizontalScrollIndicator = NO; _sv.delegate = self; _sv.bounces = NO;
    [_strip.contentView addSubview:_sv];
    _p0 = [UIView new]; _p1 = [UIView new]; [_sv addSubview:_p0]; [_sv addSubview:_p1];
    _art = [UIImageView new]; _art.contentMode = UIViewContentModeScaleAspectFill; _art.clipsToBounds = YES; _art.userInteractionEnabled = YES;
    [_art addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDisc)]];
    _title = [UILabel new]; _title.font = [UIFont boldSystemFontOfSize:14]; _title.textColor = UIColor.labelColor;
    _artist = [UILabel new]; _artist.font = [UIFont systemFontOfSize:11]; _artist.textColor = UIColor.secondaryLabelColor;
    _prev = Btn(@"backward.end.fill", 14, self, @selector(doPrev)); _play = Btn(@"play.fill", 18, self, @selector(doPlay)); _next = Btn(@"forward.end.fill", 14, self, @selector(doNext));
    for (UIView *v in @[_art, _title, _artist, _prev, _play, _next]) [_p0 addSubview:v];
    UITapGestureRecognizer *tt = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDisc)];
    _title.userInteractionEnabled = YES; [_title addGestureRecognizer:tt];
    _searchLbl = [UILabel new]; _searchLbl.text = @"🔍  搜索音乐、歌手"; _searchLbl.font = [UIFont systemFontOfSize:14]; _searchLbl.textColor = UIColor.secondaryLabelColor; _searchLbl.textAlignment = NSTextAlignmentCenter; _searchLbl.userInteractionEnabled = YES;
    [_searchLbl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapSearch)]];
    [_p1 addSubview:_searchLbl];
    _pc = [UIPageControl new]; _pc.userInteractionEnabled = NO; _pc.transform = CGAffineTransformMakeScale(0.6, 0.6); [_strip.contentView addSubview:_pc];

    _left = [LTBGlass new]; _right = [LTBGlass new]; [self addSubview:_left]; [self addSubview:_right];
    _lb = [UIButton buttonWithType:UIButtonTypeSystem]; _rb = [UIButton buttonWithType:UIButtonTypeSystem]; _lb.tintColor = _rb.tintColor = UIColor.labelColor;
    [_lb addTarget:self action:@selector(tapLeft) forControlEvents:UIControlEventTouchUpInside];
    [_rb addTarget:self action:@selector(tapRight) forControlEvents:UIControlEventTouchUpInside];
    [_left.contentView addSubview:_lb]; [_right.contentView addSubview:_rb];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    for (NSString *n in @[LTBNoteSong, LTBNoteState]) [nc addObserver:self selector:@selector(refresh) name:n object:nil];
    [nc addObserver:self selector:@selector(prefs) name:LTBNotePrefs object:nil];
    [self refresh]; [self prefs]; [self syncSelection];
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

static NSString *ActSym(NSString *a) { return @{@"wxsettings": @"gearshape.fill", @"settings": @"slider.horizontal.3", @"quick": @"square.grid.2x2.fill", @"music": @"music.note.list", @"none": @"circle.dashed"}[a] ?: @"circle"; }
- (void)prefs {
    [_lb setImage:SF(ActSym(LTBStr(@"leftAct", @"wxsettings")), 18, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    [_rb setImage:SF(ActSym(LTBStr(@"rightAct", @"quick")), 18, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, safe = self.safeAreaInsets.bottom;
    CGFloat mB = MAX(safe - 12, 8), tabH = 66, sH = 50, gap = 8, side = 14;
    _tab.frame = CGRectMake(side, H - mB - tabH, W - 2 * side, tabH); _tab.radius = tabH / 2; _tab.bulge = 7;
    _stripTop = H - mB - tabH - gap - sH;
    BOOL sl = LTBBool(@"showLeft", YES), sr = LTBBool(@"showRight", YES);
    CGFloat x = side, w = W - 2 * side;
    _left.hidden = !sl; _right.hidden = !sr;
    if (sl) { _left.frame = CGRectMake(x, _stripTop, sH, sH); x += sH + 8; w -= sH + 8; }
    if (sr) { _right.frame = CGRectMake(W - side - sH, _stripTop, sH, sH); w -= sH + 8; }
    _left.radius = _right.radius = sH / 2; _left.bulge = _right.bulge = 4; _lb.frame = _left.bounds; _rb.frame = _right.bounds;
    _strip.frame = CGRectMake(x, _stripTop, w, sH); _strip.radius = sH / 2; _strip.bulge = 5;

    NSUInteger n = _items.count, slots = n + 1, di = n / 2;
    CGFloat sw = (_tab.bounds.size.width - 16) / slots;
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger slot = i < di ? i : i + 1; CGFloat cx = 8 + sw * (slot + 0.5);
        _items[i].frame = CGRectMake(0, 0, MIN(sw, 56), 50); _items[i].center = CGPointMake(cx, tabH / 2);
        _badges[i].frame = CGRectMake(cx + 6, 6, 16, 16);
    }
    _disc.frame = CGRectMake(0, 0, 46, 46); _disc.center = CGPointMake(8 + sw * (di + 0.5), tabH / 2); _disc.layer.cornerRadius = 23;
    [self placePill:NO];

    NSMutableArray *pages = [NSMutableArray array];
    if (LTBBool(@"showMini", YES)) [pages addObject:_p0];
    if (LTBBool(@"showSearch", YES)) [pages addObject:_p1];
    if (!pages.count) [pages addObject:_p0];
    _p0.hidden = ![pages containsObject:_p0]; _p1.hidden = ![pages containsObject:_p1];
    _sv.frame = _strip.bounds; _sv.contentSize = CGSizeMake(w * pages.count, sH);
    for (NSUInteger i = 0; i < pages.count; i++) ((UIView *)pages[i]).frame = CGRectMake(w * i, 0, w, sH);
    _pc.numberOfPages = pages.count; _pc.hidden = pages.count < 2; _pc.frame = CGRectMake(0, sH - 12, w, 10);
    _art.frame = CGRectMake(8, 6, 38, 38); _art.layer.cornerRadius = 19;
    _title.frame = CGRectMake(54, 7, w - 54 - 118, 18); _artist.frame = CGRectMake(54, 25, w - 54 - 118, 14);
    _prev.frame = CGRectMake(w - 112, 8, 34, 34); _play.frame = CGRectMake(w - 76, 8, 34, 34); _next.frame = CGRectMake(w - 40, 8, 34, 34);
    _searchLbl.frame = CGRectMake(12, 0, w - 24, sH);
}
- (void)placePill:(BOOL)anim {
    if (_sel < 0 || _sel >= (NSInteger)_items.count) return;
    UIButton *b = _items[_sel]; CGFloat sw = (_tab.bounds.size.width - 16) / (_items.count + 1);
    CGRect f = CGRectMake(0, 0, sw - 4, 50); f.origin.x = b.center.x - f.size.width / 2; f.origin.y = 8;
    void (^set)(void) = ^{ self->_pill.frame = f; self->_pill.layer.cornerRadius = 25; };
    if (anim) [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4 options:0 animations:set completion:nil]; else set();
}
- (void)syncSelection {
    NSInteger s = _tbc.selectedIndex; if (s == _sel && _pill.frame.size.width > 0) return;
    _sel = s; for (UIButton *b in _items) b.selected = (b.tag == s);
    [self placePill:YES];
}
- (void)syncBadges {
    for (NSUInteger i = 0; i < _badges.count && i < _tbc.viewControllers.count; i++) {
        NSString *v = _tbc.viewControllers[i].tabBarItem.badgeValue; UILabel *l = _badges[i];
        l.hidden = v.length == 0; if (v.length) { l.text = v; CGFloat w = MAX(16, [v sizeWithAttributes:@{NSFontAttributeName: l.font}].width + 10); CGRect f = l.frame; f.size.width = w; l.frame = f; }
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
    UIImage *ph = SF(@"music.note", 18, UIImageSymbolWeightRegular);
    if (!s.pic) { _art.image = ph; _disc.image = ph; _art.tintColor = _disc.tintColor = UIColor.labelColor; _art.backgroundColor = _disc.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.3]; _art.contentMode = _disc.contentMode = UIViewContentModeCenter; }
    else LTBImage(s.pic, ^(UIImage *i) { if (LTBP.song == s && i) { self->_art.image = i; self->_disc.image = i; self->_art.contentMode = self->_disc.contentMode = UIViewContentModeScaleAspectFill; } });
    [_play setImage:SF(LTBP.playing ? @"pause.fill" : @"play.fill", 18, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    if (LTBP.playing && ![_disc.layer animationForKey:@"spin"]) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"]; a.toValue = @(M_PI * 2); a.duration = 12; a.repeatCount = HUGE_VALF; [_disc.layer addAnimation:a forKey:@"spin"];
    } else if (!LTBP.playing) [_disc.layer removeAnimationForKey:@"spin"];
}
- (void)scrollViewDidScroll:(UIScrollView *)s { if (s.bounds.size.width > 0) _pc.currentPage = (NSInteger)lround(s.contentOffset.x / s.bounds.size.width); }
- (void)doPrev { [LTBP prev]; } - (void)doNext { [LTBP next]; } - (void)doPlay { [LTBP toggle]; }
- (void)tapDisc { [LTBMgr openMusic:NO]; }
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
    self.radius = 38; self.bulge = 12; UIView *c = self.contentView;
    _art = [UIImageView new]; _art.contentMode = UIViewContentModeScaleAspectFill; _art.clipsToBounds = YES; _art.layer.cornerRadius = 28; _art.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.3];
    _title = [UILabel new]; _title.font = [UIFont boldSystemFontOfSize:19]; _artist = [UILabel new]; _artist.font = [UIFont systemFontOfSize:14]; _artist.textColor = UIColor.secondaryLabelColor;
    _lyric = [UILabel new]; _lyric.font = [UIFont systemFontOfSize:12]; _lyric.textColor = UIColor.tertiaryLabelColor;
    _prev = Btn(@"backward.end.fill", 20, self, @selector(doPrev)); _next = Btn(@"forward.end.fill", 20, self, @selector(doNext));
    _play = Btn(@"play.fill", 24, self, @selector(doPlay)); _play.backgroundColor = UIColor.whiteColor; _play.tintColor = UIColor.blackColor; _play.layer.cornerRadius = 28;
    _prog = [UISlider new]; [_prog setThumbImage:[UIImage new] forState:UIControlStateNormal]; _prog.minimumTrackTintColor = UIColor.labelColor; _prog.maximumTrackTintColor = [UIColor colorWithWhite:0.5 alpha:0.3];
    [_prog addTarget:self action:@selector(seek) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    _field = [UITextField new]; _field.placeholder = @"歌曲、艺人"; _field.returnKeyType = UIReturnKeySearch; _field.delegate = self; _field.font = [UIFont systemFontOfSize:15];
    _field.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.18]; _field.layer.cornerRadius = 20; _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIImageView *mg = [[UIImageView alloc] initWithImage:SF(@"magnifyingglass", 14, UIImageSymbolWeightRegular)]; mg.tintColor = UIColor.secondaryLabelColor; mg.contentMode = UIViewContentModeCenter; mg.frame = CGRectMake(0, 0, 36, 40);
    _field.leftView = mg; _field.leftViewMode = UITextFieldViewModeAlways;
    _go = [UIButton buttonWithType:UIButtonTypeSystem]; [_go setTitle:@"搜索" forState:UIControlStateNormal]; _go.tintColor = Red(); _go.titleLabel.font = [UIFont boldSystemFontOfSize:15]; [_go addTarget:self action:@selector(doSearch) forControlEvents:UIControlEventTouchUpInside];
    _seg = [[UISegmentedControl alloc] initWithItems:@[@"播放列表", @"搜索结果", @"歌单"]]; _seg.selectedSegmentIndex = 0; [_seg addTarget:self action:@selector(segChanged) forControlEvents:UIControlEventValueChanged];
    _mode = [UIButton buttonWithType:UIButtonTypeSystem]; _mode.tintColor = UIColor.labelColor; [_mode addTarget:self action:@selector(doMode) forControlEvents:UIControlEventTouchUpInside]; _mode.titleLabel.font = [UIFont systemFontOfSize:14];
    _trash = Btn(@"trash", 16, self, @selector(doClear)); _trash.tintColor = UIColor.secondaryLabelColor;
    _tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; _tv.backgroundColor = UIColor.clearColor; _tv.dataSource = self; _tv.delegate = self; _tv.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
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
    CGFloat W = self.bounds.size.width, p = 28, d = 16, tw = W - p - 68 - 160;
    _art.frame = CGRectMake(p, 14 + d, 56, 56);
    _title.frame = CGRectMake(p + 68, 14 + d, tw, 24); _artist.frame = CGRectMake(p + 68, 38 + d, tw, 18); _lyric.frame = CGRectMake(p + 68, 56 + d, tw, 16);
    _prev.frame = CGRectMake(W - 160, 14 + d, 36, 56); _play.frame = CGRectMake(W - 122, 14 + d, 56, 56); _next.frame = CGRectMake(W - 62, 14 + d, 36, 56);
    _prog.frame = CGRectMake(p, 78 + d, W - 2 * p, 14);
    _field.frame = CGRectMake(p, 100 + d, W - 2 * p, 40); _go.frame = CGRectMake(W - p - 64, 100 + d, 64, 40);
    _seg.frame = CGRectMake(p, 148 + d, W - 2 * p, 32);
    _mode.frame = CGRectMake(p, 186 + d, 130, 30); _mode.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft; _trash.frame = CGRectMake(W - p - 36, 186 + d, 36, 30);
    _tv.frame = CGRectMake(16, 220 + d, W - 32, self.bounds.size.height - 220 - d - 30);
}
- (void)sync {
    LTBSong *s = LTBP.song; _title.text = s.name ?: @"未在播放"; _artist.text = s.artist ?: @"搜索歌曲或选择歌单";
    [_mode setTitle:[@"  " stringByAppendingString:LTBP.modeTitle] forState:UIControlStateNormal];
    [_mode setImage:SF(LTBP.mode == 1 ? @"repeat.1" : (LTBP.mode == 2 ? @"shuffle" : @"repeat"), 14, UIImageSymbolWeightRegular) forState:UIControlStateNormal];
    [_play setImage:SF(LTBP.playing ? @"pause.fill" : @"play.fill", 24, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
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
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = UIColor.clearColor; c.textLabel.font = [UIFont systemFontOfSize:16]; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    NSInteger m = _seg.selectedSegmentIndex;
    if (m == 2) {
        if (ip.row == 0) { c.textLabel.text = @"＋ 添加歌单"; c.textLabel.textColor = Red(); c.detailTextLabel.text = @"输入网易云 / QQ音乐歌单 ID"; return c; }
        NSDictionary *d = [self playlists][ip.row - 1];
        c.textLabel.text = d[@"name"]; c.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", [d[@"source"] isEqual:@"qq"] ? @"QQ音乐" : @"网易云", d[@"id"]];
        c.imageView.image = SF(@"music.note.list", 18, UIImageSymbolWeightRegular); c.imageView.tintColor = UIColor.labelColor; return c;
    }
    LTBSong *s = m == 0 ? LTBP.songs[ip.row] : _results[ip.row];
    c.textLabel.text = s.name; c.detailTextLabel.text = s.artist;
    if (m == 0 && ip.row == LTBP.index) c.textLabel.textColor = Red();
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40)];
    c.imageView.image = [r imageWithActions:^(UIGraphicsImageRendererContext *x) { [[UIColor colorWithWhite:0.5 alpha:0.3] setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 40, 40)] fill]; }];
    LTBImage(s.pic, ^(UIImage *i) { if (i) { UITableViewCell *cc = [t cellForRowAtIndexPath:ip]; cc.imageView.image = Thumb(i, 40); } });
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
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { NSInteger m = _seg.selectedSegmentIndex; return m == 0 || (m == 2 && ip.row > 0); }
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)st forRowAtIndexPath:(NSIndexPath *)ip {
    if (_seg.selectedSegmentIndex == 0) { [LTBP.songs removeObjectAtIndex:ip.row]; }
    else { NSMutableArray *a = [[self playlists] mutableCopy]; [a removeObjectAtIndex:ip.row - 1]; LTBSetObj(@"playlists", a); }
    [t reloadData];
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

@interface LTBQuickPanel : LTBPanel
@end
@implementation LTBQuickPanel {
    UILabel *_h; NSMutableArray<UIButton *> *_btns;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.radius = 38; self.bulge = 12; _btns = [NSMutableArray array];
    _h = [UILabel new]; _h.text = @"快捷面板"; _h.font = [UIFont boldSystemFontOfSize:19]; [self.contentView addSubview:_h];
    return self;
}
- (void)willShow {
    for (UIButton *b in _btns) [b removeFromSuperview]; [_btns removeAllObjects];
    for (NSDictionary *d in QuickItems()) {
        if (!LTBBool([@"qk_" stringByAppendingString:d[@"id"]], YES)) continue;
        UIButtonConfiguration *c = [UIButtonConfiguration plainButtonConfiguration];
        c.image = SF(d[@"s"], 24, UIImageSymbolWeightRegular); c.title = d[@"t"]; c.imagePlacement = NSDirectionalRectEdgeTop; c.imagePadding = 8; c.baseForegroundColor = UIColor.labelColor;
        c.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *in) { NSMutableDictionary *m = [in mutableCopy]; m[NSFontAttributeName] = [UIFont systemFontOfSize:12]; return m; };
        UIButton *b = [UIButton buttonWithConfiguration:c primaryAction:nil]; b.accessibilityIdentifier = d[@"id"];
        [b addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:b]; [_btns addObject:b];
    }
    [self setNeedsLayout];
}
- (CGFloat)neededHeight { return 90 + ceil(_btns.count / 4.0) * 84 + 30; }
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat W = self.bounds.size.width, p = 22, cw = (W - 2 * p) / 4;
    _h.frame = CGRectMake(32, 32, W - 64, 28);
    for (NSUInteger i = 0; i < _btns.count; i++) _btns[i].frame = CGRectMake(p + cw * (i % 4), 80 + 84 * (i / 4), cw, 78);
}
- (void)tap:(UIButton *)b {
    for (NSDictionary *d in QuickItems()) if ([d[@"id"] isEqual:b.accessibilityIdentifier]) {
        if (d[@"a"]) { [LTBMgr runAction:d[@"a"]]; return; }
        [LTBMgr closePanels];
        NSURL *u = [NSURL URLWithString:d[@"u"]]; [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
    }
}
@end

#pragma mark - manager
static BOOL Eligible(UITabBarController *t);
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

// Independent of any hook: poll for the main tab controller so we keep working even if other tweaks change the hook path
- (void)start {
    if (_scan) return;
    _scan = [NSTimer scheduledTimerWithTimeInterval:0.6 repeats:YES block:^(NSTimer *t) { [self discover]; }];
}
- (void)discover {
    if (!LTBBool(@"enabled", YES)) return;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)s).windows) {
            UITabBarController *t = FindTBC(w.rootViewController, 0);
            if (t && (t != _tbc || _host.superview != t.view)) { [self attach:t]; return; }
        }
    }
}
- (void)attach:(UITabBarController *)t {
    if (!Eligible(t)) return;
    if (!LTBBool(@"enabled", YES)) { [self detach]; return; }
    CGFloat safe = t.view.safeAreaInsets.bottom, H = t.view.bounds.size.height, W = t.view.bounds.size.width, bh = 140 + safe;
    if (_tbc == t && _host.superview == t.view) {
        _host.frame = t.view.bounds; _bar.frame = CGRectMake(0, H - bh, W, bh); t.tabBar.alpha = 0;
        if (t.view.subviews.lastObject != _host) [t.view bringSubviewToFront:_host];
        return;
    }
    [self detach]; _tbc = t;
    _host = [[LTBHost alloc] initWithFrame:t.view.bounds]; _host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CATransform3D p = CATransform3DIdentity; p.m34 = -1.0 / 1000; _host.layer.sublayerTransform = p;
    _bar = [[LTBBar alloc] initWithFrame:CGRectMake(0, H - bh, W, bh) controller:t]; _bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_host addSubview:_bar]; [t.view addSubview:_host]; t.tabBar.alpha = 0; _shown = YES;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged) name:LTBNotePrefs object:nil];
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
    _tbc.tabBar.alpha = 0; [_bar syncBadges]; [_bar syncSelection];
    BOOL v = [self shouldShow];
    if (v != _shown) {
        _shown = v; if (!v) [self closePanels];
        [UIView animateWithDuration:0.3 animations:^{ self->_bar.alpha = v ? 1 : 0; self->_bar.transform = v ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 160); }];
    }
}
- (void)runAction:(NSString *)a {
    if ([a isEqual:@"wxsettings"]) [self openWeChatSettings]; else if ([a isEqual:@"settings"]) [self openSettings]; else if ([a isEqual:@"quick"]) [self openQuick]; else if ([a isEqual:@"music"]) [self openMusic:NO];
}
- (void)openSettings {
    [self closePanels];
    UIViewController *top = TopVC(); if (!top) return;
    if ([top isKindOfClass:[UINavigationController class]] && [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:[LTBSettingsVC class]]) return;
    [top presentViewController:[[UINavigationController alloc] initWithRootViewController:[LTBSettingsVC new]] animated:YES completion:nil];
}
- (void)openWeChatSettings {
    [self closePanels];
    UITabBarController *t = _tbc; Class c = NSClassFromString(@"NewSettingViewController");
    if (t && c) {
        @try {
            NSUInteger last = t.viewControllers.count - 1;
            t.selectedIndex = last;
            UINavigationController *n = [t.viewControllers[last] isKindOfClass:[UINavigationController class]] ? (UINavigationController *)t.viewControllers[last] : nil;
            if (n) { [n popToRootViewControllerAnimated:NO]; UIViewController *vc = [[c alloc] init]; [n pushViewController:vc animated:YES]; return; }
        } @catch (NSException *e) {}
    }
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"weixin://dl/settings"] options:@{} completionHandler:nil];
}
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
    CGFloat bottom = CGRectGetMinY(_bar.frame) + _bar.stripTop - 10, top = _host.safeAreaInsets.top + 12;
    h = MIN(h, bottom - top); CGRect f = CGRectMake(14, bottom - h, _host.bounds.size.width - 28, h);
    _panel = p; p.layer.anchorPoint = CGPointMake(p.hingeLeft ? 0 : 1, 0.5); p.frame = f;
    [p willShow]; [_host insertSubview:p belowSubview:_bar];
    CASpringAnimation *sp = [CASpringAnimation animationWithKeyPath:@"transform.rotation.y"];
    sp.fromValue = @((p.hingeLeft ? -1 : 1) * M_PI_2 * 0.96); sp.toValue = @0; sp.mass = 1; sp.stiffness = 150; sp.damping = 15; sp.duration = sp.settlingDuration;
    [p.layer addAnimation:sp forKey:@"hinge"];
    p.alpha = 0; [UIView animateWithDuration:0.25 animations:^{ p.alpha = 1; }];
}
- (void)closePanels { [self closePanelsAnimated:YES]; }
- (void)closePanelsAnimated:(BOOL)anim {
    LTBPanel *p = _panel; UIView *d = _dim; _panel = nil; _dim = nil; [d removeFromSuperview]; if (!p) return;
    [p endEditing:YES];
    if (!anim) { [p removeFromSuperview]; return; }
    CGFloat a = (p.hingeLeft ? -1 : 1) * M_PI_2 * 0.96;
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{ [p removeFromSuperview]; p.layer.transform = CATransform3DIdentity; }];
    CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"]; b.fromValue = @0; b.toValue = @(a); b.duration = 0.28;
    b.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]; b.fillMode = kCAFillModeForwards; b.removedOnCompletion = NO;
    [p.layer addAnimation:b forKey:@"close"]; [CATransaction commit];
    [UIView animateWithDuration:0.28 animations:^{ p.alpha = 0; }];
}
@end

#pragma mark - entry pill (injected into other plugins' settings pages)
@interface LTBEntry : LTBGlass
@end
@implementation LTBEntry { UILabel *_l; }
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.radius = 19; self.bulge = 3; self.tag = 0x4C5442;
    _l = [UILabel new]; _l.text = @"⚙︎ 液态底栏"; _l.font = [UIFont boldSystemFontOfSize:14]; _l.textAlignment = NSTextAlignmentCenter; _l.textColor = UIColor.labelColor;
    [self.contentView addSubview:_l];
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[LTBManager shared] action:@selector(openSettings)]];
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; _l.frame = self.contentView.bounds; }
@end
UIView *LTBEntryPill(void) { return [LTBEntry new]; }

#pragma mark - settings
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
    NSArray *act = @[@[@"wxsettings", @"微信设置"], @[@"settings", @"插件设置"], @[@"quick", @"快捷面板"], @[@"music", @"音乐面板"], @[@"none", @"无操作"]];
    NSMutableArray *qk = [NSMutableArray array];
    for (NSDictionary *d in QuickItems()) [qk addObject:@{@"t": d[@"t"], @"k": [@"qk_" stringByAppendingString:d[@"id"]], @"y": @"sw"}];
    _data = @[
        @{@"h": @"总开关", @"f": @"关闭后恢复微信原生底栏。", @"r": @[@{@"t": @"启用液态底栏", @"k": @"enabled", @"y": @"sw"}]},
        @{@"h": @"底栏上方按钮", @"r": @[
            @{@"t": @"显示左侧按钮", @"k": @"showLeft", @"y": @"sw"}, @{@"t": @"显示右侧按钮", @"k": @"showRight", @"y": @"sw"},
            @{@"t": @"左侧按钮功能", @"k": @"leftAct", @"y": @"ch", @"d": @"wxsettings", @"o": act},
            @{@"t": @"右侧按钮功能", @"k": @"rightAct", @"y": @"ch", @"d": @"quick", @"o": act}]},
        @{@"h": @"中间条（左右滑动切换）", @"r": @[
            @{@"t": @"迷你播放器页", @"k": @"showMini", @"y": @"sw"}, @{@"t": @"搜索页", @"k": @"showSearch", @"y": @"sw"}]},
        @{@"h": @"音乐", @"f": @"QQ 音乐及网易云兜底走 Meting 兼容接口，可换成自己的地址。", @"r": @[
            @{@"t": @"默认搜索来源", @"k": @"searchSrc", @"y": @"ch", @"d": @"netease", @"o": src},
            @{@"t": @"Meting API 地址", @"k": @"meting", @"y": @"tx", @"d": @"https://api.injahow.cn/meting/"},
            @{@"t": @"清空播放列表", @"k": @"clearq", @"y": @"ac"}]},
        @{@"h": @"快捷面板显示项目", @"r": qk},
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
        if ([r[@"k"] isEqual:@"clearq"]) [LTBP clear]; else { LTBResetPrefs(); [t reloadData]; }
    }
}
@end
