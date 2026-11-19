#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern NSString *const LTBNoteSong, *const LTBNoteState, *const LTBNoteProgress, *const LTBNotePrefs;

BOOL LTBBool(NSString *k, BOOL d);
void LTBSetBool(NSString *k, BOOL v);
NSString *LTBStr(NSString *k, NSString *d);
void LTBSetStr(NSString *k, NSString *v);
id LTBObj(NSString *k);
void LTBSetObj(NSString *k, id v);
void LTBResetPrefs(void);
void LTBImage(NSString *url, void (^cb)(UIImage *));

@interface LTBSong : NSObject
@property(nonatomic, copy) NSString *sid, *source, *name, *artist, *url, *pic, *lrc;
- (NSDictionary *)dict; // { name, artist, url, pic, lrc }
@end

// Native equivalent of the JS "TM" API
@interface TM : NSObject
+ (void)loadPlaylist:(NSString *)pid source:(NSString *)src completion:(void (^)(NSArray<LTBSong *> *))cb;
+ (void)loadSong:(NSString *)sid source:(NSString *)src completion:(void (^)(LTBSong *))cb;
+ (NSString *)getSongUrl:(NSString *)sid source:(NSString *)src;
+ (void)getLyric:(NSString *)sid source:(NSString *)src completion:(void (^)(NSString *lrc))cb;
+ (void)search:(NSString *)kw source:(NSString *)src completion:(void (^)(NSArray<LTBSong *> *))cb;
@end

@interface LTBPlayer : NSObject
+ (instancetype)shared;
@property(nonatomic, readonly) NSMutableArray<LTBSong *> *songs;
@property(nonatomic, readonly) NSInteger index;
@property(nonatomic) NSInteger mode; // 0 list loop, 1 single, 2 shuffle
@property(nonatomic, readonly) BOOL playing;
@property(nonatomic, readonly) NSTimeInterval current, duration;
@property(nonatomic, readonly) LTBSong *song;
- (void)setSongs:(NSArray<LTBSong *> *)s play:(NSInteger)i;
- (void)playIndex:(NSInteger)i;
- (void)toggle;
- (void)next;
- (void)prev;
- (void)seek:(double)frac;
- (void)clear;
- (void)cycleMode;
- (NSString *)modeTitle;
- (NSString *)lyricLine;
- (void)loadDefaultIfNeeded;
@end

@interface LTBSettingsVC : UITableViewController
@end

@interface LTBManager : NSObject
+ (instancetype)shared;
- (void)attach:(UITabBarController *)tbc;
- (void)sync;
- (void)openMusic:(BOOL)focusSearch;
- (void)openQuick;
- (void)openSettings;
- (void)closePanels;
- (void)runAction:(NSString *)a;
- (void)start;
@end

#ifdef __cplusplus
extern "C" {
#endif
UIView *LTBEntryPill(void);
#ifdef __cplusplus
}
#endif

#define LTBP [LTBPlayer shared]
#define LTBMgr [LTBManager shared]
