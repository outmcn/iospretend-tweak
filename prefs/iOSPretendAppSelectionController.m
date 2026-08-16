#import "iOSPretendAppSelectionController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

static NSString * const LMPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString * const LMPreferencesChanged = @"com.iospretend.iospretend/ReloadPrefs";

@interface LMInstalledApp : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@end
@implementation LMInstalledApp @end

@interface iOSPretendAppSelectionController ()
@property (nonatomic, strong) NSArray<LMInstalledApp *> *allApps;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedApps;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation iOSPretendAppSelectionController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"生效应用";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

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

    self.selectedApps = [NSMutableSet set];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:LMPreferencesPath] ?: @{};
    NSArray *saved = prefs[@"selectedApps"];
    if ([saved isKindOfClass:[NSArray class]]) [self.selectedApps addObjectsFromArray:saved];

    self.allApps = [self loadInstalledApps];

    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchResultsUpdater = self;
    search.searchBar.placeholder = @"搜索应用";
    self.searchController = search;
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(saveSelection)];
}

- (NSArray<LMInstalledApp *> *)loadInstalledApps {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, NSSelectorFromString(@"defaultWorkspace"));
    NSArray *proxies = ((id (*)(id, SEL))objc_msgSend)(workspace, NSSelectorFromString(@"allInstalledApplications"));
    NSMutableArray *result = [NSMutableArray array];

    for (id proxy in proxies) {
        NSString *bundleID = ((id (*)(id, SEL))objc_msgSend)(proxy, NSSelectorFromString(@"applicationIdentifier"));
        if (bundleID.length == 0 ||
            [bundleID isEqualToString:@"com.apple.Preferences"] ||
            [bundleID isEqualToString:@"com.apple.springboard"] ||
            [bundleID isEqualToString:@"com.apple.locationd"]) continue;
        NSString *name = nil;
        if ([proxy respondsToSelector:NSSelectorFromString(@"localizedName")]) {
            name = ((id (*)(id, SEL))objc_msgSend)(proxy, NSSelectorFromString(@"localizedName"));
        }
        if (name.length == 0) name = bundleID;

        LMInstalledApp *app = [LMInstalledApp new];
        app.bundleID = bundleID;
        app.name = name;
        result[result.count] = app;
    }

    [result sortUsingComparator:^NSComparisonResult(LMInstalledApp *a, LMInstalledApp *b) {
        return [a.name localizedStandardCompare:b.name];
    }];
    return result;
}

- (NSArray<LMInstalledApp *> *)selectedAppsArray {
    NSArray *sorted = [self.allApps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LMInstalledApp *app, NSDictionary *bindings) {
        return [self.selectedApps containsObject:app.bundleID];
    }]];
    return [sorted sortedArrayUsingComparator:^NSComparisonResult(LMInstalledApp *a, LMInstalledApp *b) {
        return [a.name localizedStandardCompare:b.name];
    }];
}

- (NSArray<LMInstalledApp *> *)filteredAppsForQuery:(NSString *)query {
    if (query.length == 0) {
        return [self.allApps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LMInstalledApp *app, NSDictionary *bindings) {
            return ![self.selectedApps containsObject:app.bundleID];
        }]];
    }
    return [self.allApps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LMInstalledApp *app, NSDictionary *bindings) {
        return ![self.selectedApps containsObject:app.bundleID] &&
               ([app.name.lowercaseString containsString:query] || [app.bundleID.lowercaseString containsString:query]);
    }]];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return [self selectedAppsArray].count;
    return [self filteredAppsForQuery:self.searchController.searchBar.text.lowercaseString].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return [self selectedAppsArray].count > 0 ? @"已选择" : nil;
    return @"全部应用";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    LMInstalledApp *app = indexPath.section == 0 ? [self selectedAppsArray][indexPath.row] : [self filteredAppsForQuery:self.searchController.searchBar.text.lowercaseString][indexPath.row];
    cell.textLabel.text = app.name;
    cell.detailTextLabel.text = app.bundleID;
    cell.accessoryType = [self.selectedApps containsObject:app.bundleID] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    LMInstalledApp *app = indexPath.section == 0 ? [self selectedAppsArray][indexPath.row] : [self filteredAppsForQuery:self.searchController.searchBar.text.lowercaseString][indexPath.row];
    if ([self.selectedApps containsObject:app.bundleID]) {
        [self.selectedApps removeObject:app.bundleID];
    } else {
        [self.selectedApps addObject:app.bundleID];
    }
    [self.tableView reloadData];
}

- (void)saveSelection {
    NSArray *selected = [self.selectedApps.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:LMPreferencesPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    prefs[@"selectedApps"] = selected;
    BOOL saved = [prefs writeToFile:LMPreferencesPath atomically:YES];
    if (!saved) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败"
                                                                       message:@"无法写入应用列表，请重新安装插件后再试。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)LMPreferencesChanged,
                                         NULL, NULL, YES);
    [self.navigationController popViewControllerAnimated:YES];
}

@end
