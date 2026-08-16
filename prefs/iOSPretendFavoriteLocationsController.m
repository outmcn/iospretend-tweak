#import "iOSPretendFavoriteLocationsController.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString * const LMPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString * const LMPreferencesChanged = @"com.iospretend.iospretend/ReloadPrefs";

@interface iOSPretendFavoriteLocationsController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *favorites;
@property (nonatomic, assign) double currentLatitude;
@property (nonatomic, assign) double currentLongitude;
@end

@implementation iOSPretendFavoriteLocationsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"收藏选择";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self reloadPreferences];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 58;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)reloadPreferences {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:LMPreferencesPath] ?: @{};
    NSArray *saved = prefs[@"favorites"];
    self.favorites = [saved isKindOfClass:[NSArray class]] ? [saved mutableCopy] : [NSMutableArray array];
    self.currentLatitude = [prefs[@"latitude"] doubleValue];
    self.currentLongitude = [prefs[@"longitude"] doubleValue];
}

- (BOOL)saveFavoritesAndCoordinate:(NSDictionary *)favorite {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:LMPreferencesPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    prefs[@"favorites"] = self.favorites;
    if (favorite) {
        prefs[@"latitude"] = favorite[@"latitude"];
        prefs[@"longitude"] = favorite[@"longitude"];
    }
    BOOL saved = [prefs writeToFile:LMPreferencesPath atomically:YES];
    if (saved) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)LMPreferencesChanged, NULL, NULL, YES);
    }
    return saved;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.favorites.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"FavoriteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *favorite = self.favorites[indexPath.row];
    double lat = [favorite[@"latitude"] doubleValue];
    double lon = [favorite[@"longitude"] doubleValue];
    cell.textLabel.text = favorite[@"name"] ?: @"未命名收藏";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", lat, lon];
    BOOL current = fabs(lat - self.currentLatitude) < 0.0000005 && fabs(lon - self.currentLongitude) < 0.0000005;
    cell.accessoryType = current ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *favorite = self.favorites[indexPath.row];
    if (![self saveFavoritesAndCoordinate:favorite]) {
        [self showSaveError];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSDictionary *favorite = self.favorites[indexPath.row];
    NSString *name = favorite[@"name"] ?: @"该收藏";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除收藏" message:[NSString stringWithFormat:@"确定删除“%@”吗？", name] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSDictionary *removed = weakSelf.favorites[indexPath.row];
        [weakSelf.favorites removeObjectAtIndex:indexPath.row];
        if (![weakSelf saveFavoritesAndCoordinate:nil]) {
            if (removed) [weakSelf.favorites insertObject:removed atIndex:indexPath.row];
            [weakSelf.tableView reloadData];
            [weakSelf showSaveError];
            return;
        }
        [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSaveError {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败" message:@"无法写入收藏设置。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
