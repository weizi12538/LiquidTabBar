#import "LTB.h"
#import <MediaPlayer/MediaPlayer.h>

NSString *const LTBNoteSong = @"LTBNoteSong", *const LTBNoteState = @"LTBNoteState",
         *const LTBNoteProgress = @"LTBNoteProgress", *const LTBNotePrefs = @"LTBNotePrefs";

#pragma mark - prefs
static NSString *K(NSString *k) { return [@"ltb_" stringByAppendingString:k]; }
static void Poke(void) { [[NSNotificationCenter defaultCenter] postNotificationName:LTBNotePrefs object:nil]; }
BOOL LTBBool(NSString *k, BOOL d) { id v = [[NSUserDefaults standardUserDefaults] objectForKey:K(k)]; return v ? [v boolValue] : d; }
void LTBSetBool(NSString *k, BOOL v) { [[NSUserDefaults standardUserDefaults] setBool:v forKey:K(k)]; Poke(); }
NSString *LTBStr(NSString *k, NSString *d) { NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:K(k)]; return v.length ? v : d; }
void LTBSetStr(NSString *k, NSString *v) { [[NSUserDefaults standardUserDefaults] setObject:v forKey:K(k)]; Poke(); }
id LTBObj(NSString *k) { return [[NSUserDefaults standardUserDefaults] objectForKey:K(k)]; }
void LTBSetObj(NSString *k, id v) { [[NSUserDefaults standardUserDefaults] setObject:v forKey:K(k)]; }
void LTBResetPrefs(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (NSString *k in [[d dictionaryRepresentation] allKeys]) if ([k hasPrefix:@"ltb_"]) [d removeObjectForKey:k];
    Poke();
}

#pragma mark - net helpers
void LTBImage(NSString *url, void (^cb)(UIImage *)) {
    static NSCache *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [NSCache new]; });
    if (!url.length) { cb(nil); return; }
    url = [url stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
    UIImage *i = [c objectForKey:url]; if (i) { cb(i); return; }
    NSURL *u = [NSURL URLWithString:url]; if (!u) { cb(nil); return; }
    [[[NSURLSession sharedSession] dataTaskWithURL:u completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        UIImage *im = d ? [UIImage imageWithData:d] : nil;
        if (im) [c setObject:im forKey:url];
        dispatch_async(dispatch_get_main_queue(), ^{ cb(im); });
    }] resume];
}

static void Fetch(NSString *url, void (^cb)(NSData *)) {
    NSURL *u = [NSURL URLWithString:url];
    if (!u) { cb(nil); return; }
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15];
    [r setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15" forHTTPHeaderField:@"User-Agent"];
    if ([url containsString:@"163.com"]) [r setValue:@"https://music.163.com" forHTTPHeaderField:@"Referer"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *x, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{ cb(d); });
    }] resume];
}
static void FetchJSON(NSString *url, void (^cb)(id)) {
    Fetch(url, ^(NSData *d) { cb(d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil); });
}
static NSString *Enc(NSString *s) {
    static NSCharacterSet *cs;
    if (!cs) cs = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:cs] ?: @"";
}
static NSDictionary *DD(id o) { return [o isKindOfClass:[NSDictionary class]] ? o : nil; }
static NSArray *AA(id o) { return [o isKindOfClass:[NSArray class]] ? o : nil; }
static NSString *Str(id o) { return o && o != [NSNull null] ? [NSString stringWithFormat:@"%@", o] : nil; }

#pragma mark - songs / TM
@implementation LTBSong
- (NSDictionary *)dict { return @{@"name": _name ?: @"", @"artist": _artist ?: @"", @"url": _url ?: @"", @"pic": _pic ?: @"", @"lrc": _lrc ?: @""}; }
@end

static NSString *MetingURL(NSString *src, NSString *type, NSString *ident) {
    NSString *base = LTBStr(@"meting", @"https://api.injahow.cn/meting/");
    NSString *srv = [src isEqualToString:@"qq"] ? @"tencent" : @"netease";
    return [NSString stringWithFormat:@"%@?server=%@&type=%@&id=%@", base, srv, type, Enc(ident)];
}
static NSArray *ParseMeting(id j, NSString *src) {
    NSMutableArray *a = [NSMutableArray array];
    if (![j isKindOfClass:[NSArray class]]) return a;
    for (NSDictionary *d in j) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        LTBSong *s = [LTBSong new]; s.source = src;
        s.name = Str(d[@"name"] ?: d[@"title"]); s.artist = Str(d[@"artist"] ?: d[@"author"]);
        s.url = Str(d[@"url"]); s.pic = Str(d[@"pic"]); s.lrc = Str(d[@"lrc"]);
        if (s.name.length) [a addObject:s];
    }
    return a;
}
static LTBSong *NSong(NSDictionary *t) {
    LTBSong *s = [LTBSong new]; s.source = @"netease"; s.sid = Str(t[@"id"]); s.name = Str(t[@"name"]);
    NSMutableArray *n = [NSMutableArray array];
    for (id x in AA(t[@"artists"] ?: t[@"ar"])) if (DD(x)[@"name"]) [n addObject:Str(DD(x)[@"name"])];
    s.artist = [n componentsJoinedByString:@"/"];
    NSDictionary *al = DD(t[@"album"] ?: t[@"al"]); s.pic = Str(al[@"picUrl"]);
    s.url = [TM getSongUrl:s.sid source:@"netease"];
    return s;
}

@implementation TM
+ (NSString *)getSongUrl:(NSString *)sid source:(NSString *)src {
    if ([src isEqualToString:@"qq"]) return MetingURL(@"qq", @"url", sid);
    return [NSString stringWithFormat:@"https://music.163.com/song/media/outer/url?id=%@.mp3", sid];
}
+ (void)loadPlaylist:(NSString *)pid source:(NSString *)src completion:(void (^)(NSArray<LTBSong *> *))cb {
    void (^viaMeting)(void) = ^{
        FetchJSON(MetingURL(src, @"playlist", pid), ^(id j) { cb(ParseMeting(j, src)); });
    };
    if ([src isEqualToString:@"qq"]) { viaMeting(); return; }
    FetchJSON([NSString stringWithFormat:@"https://music.163.com/api/playlist/detail?id=%@", pid], ^(id j) {
        NSArray *tr = AA(DD(DD(j)[@"result"])[@"tracks"]);
        NSMutableArray *a = [NSMutableArray array];
        for (id t in tr) if (DD(t)) [a addObject:NSong(t)];
        if (a.count) cb(a); else viaMeting();
    });
}
+ (void)loadSong:(NSString *)sid source:(NSString *)src completion:(void (^)(LTBSong *))cb {
    if ([src isEqualToString:@"qq"]) {
        FetchJSON(MetingURL(@"qq", @"song", sid), ^(id j) { cb(ParseMeting(j, @"qq").firstObject); });
        return;
    }
    FetchJSON([NSString stringWithFormat:@"https://music.163.com/api/song/detail?ids=[%@]", sid], ^(id j) {
        NSDictionary *t = DD(AA(DD(j)[@"songs"]).firstObject);
        cb(t ? NSong(t) : nil);
    });
}
+ (void)getLyric:(NSString *)sid source:(NSString *)src completion:(void (^)(NSString *))cb {
    if ([src isEqualToString:@"qq"]) {
        Fetch(MetingURL(@"qq", @"lrc", sid), ^(NSData *d) { cb(d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil); });
        return;
    }
    FetchJSON([NSString stringWithFormat:@"https://music.163.com/api/song/lyric?id=%@&lv=1", sid], ^(id j) {
        cb(Str(DD(DD(j)[@"lrc"])[@"lyric"]));
    });
}
+ (void)search:(NSString *)kw source:(NSString *)src completion:(void (^)(NSArray<LTBSong *> *))cb {
    if ([src isEqualToString:@"qq"]) {
        FetchJSON(MetingURL(@"qq", @"search", kw), ^(id j) { cb(ParseMeting(j, @"qq")); });
        return;
    }
    FetchJSON([NSString stringWithFormat:@"https://music.163.com/api/search/get/web?csrf_token=&s=%@&type=1&offset=0&limit=30", Enc(kw)], ^(id j) {
        NSArray *ss = AA(DD(DD(j)[@"result"])[@"songs"]);
        NSMutableArray *a = [NSMutableArray array], *ids = [NSMutableArray array];
        for (id t in ss) { if (!DD(t)) continue; LTBSong *s = NSong(t); if (!s.sid) continue; [a addObject:s]; [ids addObject:s.sid]; }
        if (!a.count) { cb(a); return; }
        // fetch covers
        NSString *u = [NSString stringWithFormat:@"https://music.163.com/api/song/detail?ids=[%@]", [ids componentsJoinedByString:@","]];
        FetchJSON(u, ^(id d) {
            NSMutableDictionary *pics = [NSMutableDictionary dictionary];
            for (id t in AA(DD(d)[@"songs"])) {
                if (!DD(t)) continue;
                NSString *p = Str(DD(DD(t)[@"album"])[@"picUrl"]); if (p) pics[Str(DD(t)[@"id"])] = p;
            }
            for (LTBSong *s in a) s.pic = pics[s.sid];
            cb(a);
        });
    });
}
@end

#pragma mark - player
@interface LTBPlayer () { AVPlayer *_p; AVPlayerItem *_item; id _obs; NSArray *_lines; NSInteger _fails; UIImage *_art; }
@end

@implementation LTBPlayer
+ (instancetype)shared { static LTBPlayer *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [LTBPlayer new]; [s setup]; }); return s; }

- (void)setup {
    _songs = [NSMutableArray array]; _index = -1;
    if (!LTBObj(@"playlists")) LTBSetObj(@"playlists", @[
        @{@"id": @"2619366284", @"source": @"netease", @"name": @"示例歌单（网易云）"},
        @{@"id": @"8691034059", @"source": @"qq", @"name": @"示例歌单（QQ音乐）"}]);
    _mode = [[NSUserDefaults standardUserDefaults] integerForKey:K(@"mode")];
    _p = [AVPlayer new];
    [_p addObserver:self forKeyPath:@"timeControlStatus" options:0 context:NULL];
    _obs = [_p addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 600) queue:dispatch_get_main_queue() usingBlock:^(CMTime t) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LTBNoteProgress object:nil];
    }];
    MPRemoteCommandCenter *rc = [MPRemoteCommandCenter sharedCommandCenter];
    __weak typeof(self) w = self;
    [rc.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) { dispatch_async(dispatch_get_main_queue(), ^{ if (!w.playing) [w toggle]; }); return MPRemoteCommandHandlerStatusSuccess; }];
    [rc.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) { dispatch_async(dispatch_get_main_queue(), ^{ if (w.playing) [w toggle]; }); return MPRemoteCommandHandlerStatusSuccess; }];
    [rc.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) { dispatch_async(dispatch_get_main_queue(), ^{ [w toggle]; }); return MPRemoteCommandHandlerStatusSuccess; }];
    [rc.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) { dispatch_async(dispatch_get_main_queue(), ^{ [w next]; }); return MPRemoteCommandHandlerStatusSuccess; }];
    [rc.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) { dispatch_async(dispatch_get_main_queue(), ^{ [w prev]; }); return MPRemoteCommandHandlerStatusSuccess; }];
    [rc.changePlaybackPositionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        double pos = ((MPChangePlaybackPositionCommandEvent *)e).positionTime;
        dispatch_async(dispatch_get_main_queue(), ^{ if (w.duration > 0) [w seek:pos / w.duration]; });
        return MPRemoteCommandHandlerStatusSuccess; }];
}

- (LTBSong *)song { return (_index >= 0 && _index < (NSInteger)_songs.count) ? _songs[_index] : nil; }
- (BOOL)playing { return _p.timeControlStatus != AVPlayerTimeControlStatusPaused; }
- (NSTimeInterval)current { double t = CMTimeGetSeconds(_p.currentTime); return isnan(t) ? 0 : t; }
- (NSTimeInterval)duration { double t = _item ? CMTimeGetSeconds(_item.duration) : 0; return (isnan(t) || isinf(t)) ? 0 : t; }

- (void)setSongs:(NSArray<LTBSong *> *)s play:(NSInteger)i {
    [_songs removeAllObjects]; [_songs addObjectsFromArray:s]; _index = -1;
    if (i >= 0) [self playIndex:i]; else [[NSNotificationCenter defaultCenter] postNotificationName:LTBNoteSong object:nil];
}
- (void)playIndex:(NSInteger)i {
    if (i < 0 || i >= (NSInteger)_songs.count) return;
    _index = i; LTBSong *s = _songs[i];
    NSURL *u = [NSURL URLWithString:s.url ?: @""]; if (!u) { [self next]; return; }
    @try { AVAudioSession *as = [AVAudioSession sharedInstance];
    [as setCategory:AVAudioSessionCategoryPlayback error:nil]; [as setActive:YES error:nil]; } @catch (NSException *e) {}
    if (_item) {
        @try { [_item removeObserver:self forKeyPath:@"status"]; } @catch (NSException *e) {}
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
    }
    _item = [AVPlayerItem playerItemWithURL:u];
    [_item addObserver:self forKeyPath:@"status" options:0 context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ended:) name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
    [_p replaceCurrentItemWithPlayerItem:_item]; [_p play];
    _lines = nil; _art = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:LTBNoteSong object:nil];
    [self updateNowPlaying];
    __weak typeof(self) w = self;
    LTBImage(s.pic, ^(UIImage *im) { LTBPlayer *ss = w; if (ss && ss.song == s) { ss->_art = im; [ss updateNowPlaying]; } });
    void (^got)(NSString *) = ^(NSString *t) { if (w.song == s && t.length) [w parseLRC:t]; };
    if ([s.source isEqualToString:@"netease"] && s.sid) [TM getLyric:s.sid source:@"netease" completion:got];
    else if (s.lrc.length) Fetch(s.lrc, ^(NSData *d) { got(d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil); });
}
- (void)ended:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_mode == 1) { [self->_p seekToTime:kCMTimeZero]; [self->_p play]; } else [self next];
    });
}
- (void)toggle {
    if (!_item) { if (_songs.count) [self playIndex:MAX(_index, 0)]; return; }
    if (self.playing) [_p pause]; else [_p play];
}
- (void)next {
    if (!_songs.count) return;
    NSInteger n = _mode == 2 ? (NSInteger)arc4random_uniform((uint32_t)_songs.count) : (_index + 1) % (NSInteger)_songs.count;
    [self playIndex:n];
}
- (void)prev {
    if (!_songs.count) return;
    if (self.current > 3) { [_p seekToTime:kCMTimeZero]; return; }
    [self playIndex:(_index - 1 + (NSInteger)_songs.count) % (NSInteger)_songs.count];
}
- (void)seek:(double)f { if (self.duration > 0) [_p seekToTime:CMTimeMakeWithSeconds(f * self.duration, 600)]; }
- (void)clear {
    [_p pause]; [_p replaceCurrentItemWithPlayerItem:nil];
    if (_item) { @try { [_item removeObserver:self forKeyPath:@"status"]; } @catch (NSException *e) {} _item = nil; }
    [_songs removeAllObjects]; _index = -1; _lines = nil;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:LTBNoteSong object:nil];
}
- (void)cycleMode { _mode = (_mode + 1) % 3; [[NSUserDefaults standardUserDefaults] setInteger:_mode forKey:K(@"mode")]; }
- (NSString *)modeTitle { return @[@"列表循环", @"单曲循环", @"随机播放"][_mode]; }

- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)x {
    // AVFoundation may call this on a background thread; UI must only be touched on main
    dispatch_async(dispatch_get_main_queue(), ^{ [self handleKVO:o]; });
}
- (void)handleKVO:(id)o {
    if (o == _p) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LTBNoteState object:nil];
        [self updateNowPlaying];
    } else if (o == _item) {
        if (_item.status == AVPlayerItemStatusFailed) { if (++_fails < 6 && _songs.count > 1) [self playIndex:(_index + 1) % (NSInteger)_songs.count]; }
        else if (_item.status == AVPlayerItemStatusReadyToPlay) { _fails = 0; [self updateNowPlaying]; }
    }
}
- (void)updateNowPlaying {
    LTBSong *s = self.song;
    if (!s) return;
    NSMutableDictionary *d = [@{MPMediaItemPropertyTitle: s.name ?: @"", MPMediaItemPropertyArtist: s.artist ?: @"",
        MPNowPlayingInfoPropertyElapsedPlaybackTime: @(self.current), MPMediaItemPropertyPlaybackDuration: @(self.duration),
        MPNowPlayingInfoPropertyPlaybackRate: @(self.playing ? 1 : 0)} mutableCopy];
    if (_art) { UIImage *a = _art; d[MPMediaItemPropertyArtwork] = [[MPMediaItemArtwork alloc] initWithBoundsSize:a.size requestHandler:^UIImage *(CGSize sz) { return a; }]; }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = d;
}
- (void)parseLRC:(NSString *)t {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d+):(\\d+)(?:[.:](\\d+))?\\](.*)" options:0 error:nil];
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *ln in [t componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSTextCheckingResult *m = [re firstMatchInString:ln options:0 range:NSMakeRange(0, ln.length)];
        if (!m) continue;
        double mm = [[ln substringWithRange:[m rangeAtIndex:1]] doubleValue], ss = [[ln substringWithRange:[m rangeAtIndex:2]] doubleValue], fr = 0;
        if ([m rangeAtIndex:3].location != NSNotFound) { NSString *f = [ln substringWithRange:[m rangeAtIndex:3]]; fr = [f doubleValue] / pow(10, f.length); }
        NSString *text = [[ln substringWithRange:[m rangeAtIndex:4]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (text.length) [a addObject:@[@(mm * 60 + ss + fr), text]];
    }
    _lines = [a sortedArrayUsingComparator:^NSComparisonResult(NSArray *x, NSArray *y) { return [x[0] compare:y[0]]; }];
}
- (NSString *)lyricLine {
    NSString *r = @""; double t = self.current;
    for (NSArray *l in _lines) { if ([l[0] doubleValue] <= t) r = l[1]; else break; }
    return r;
}
- (void)loadDefaultIfNeeded {
    if (_songs.count) return;
    NSArray *pl = LTBObj(@"playlists");
    NSString *last = LTBStr(@"lastpl", nil);
    NSString *src = nil, *pid = nil;
    if (last) { NSArray *p = [last componentsSeparatedByString:@":"]; if (p.count == 2) { src = p[0]; pid = p[1]; } }
    else if ([pl.firstObject isKindOfClass:[NSDictionary class]]) { src = pl.firstObject[@"source"]; pid = pl.firstObject[@"id"]; }
    if (!pid) return;
    [TM loadPlaylist:pid source:src completion:^(NSArray<LTBSong *> *a) { if (a.count && !self->_songs.count) [self setSongs:a play:-1]; }];
}
@end
