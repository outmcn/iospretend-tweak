#import "iOSPretendMapPickerController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

static NSString * const LMPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString * const LMPreferencesChanged = @"com.iospretend.iospretend/ReloadPrefs";

@interface iOSPretendMapPickerController ()
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@end

@implementation iOSPretendMapPickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"地图选点";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:LMPreferencesPath] ?: @{};
    NSNumber *latitude = prefs[@"latitude"];
    NSNumber *longitude = prefs[@"longitude"];
    double lat = latitude ? latitude.doubleValue : 39.9042;
    double lon = longitude ? longitude.doubleValue : 116.4074;
    if (!(isfinite(lat) && lat >= -90.0 && lat <= 90.0)) lat = 39.9042;
    if (!(isfinite(lon) && lon >= -180.0 && lon <= 180.0)) lon = 116.4074;
    self.selectedCoordinate = CLLocationCoordinate2DMake(lat, lon);

    self.mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    self.mapView.delegate = self;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    [self.view addSubview:self.mapView];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
    longPress.minimumPressDuration = 0.45;
    [self.mapView addGestureRecognizer:longPress];

    self.coordinateLabel = [UILabel new];
    self.coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.numberOfLines = 2;
    [self.view addSubview:self.coordinateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.coordinateLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [self.coordinateLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [self.coordinateLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [self.coordinateLabel.heightAnchor constraintEqualToConstant:48],
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.coordinateLabel.topAnchor constant:-8]
    ]];

    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.delegate = self;
    search.searchBar.placeholder = @"搜索地点";
    self.searchController = search;
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(saveLocation)];
    UIBarButtonItem *favoriteButton = [[UIBarButtonItem alloc] initWithTitle:@"收藏"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(addFavorite)];
    self.navigationItem.rightBarButtonItems = @[saveButton, favoriteButton];

    [self updatePinAndRegion:YES];
}

- (void)updatePinAndRegion:(BOOL)center {
    if (self.pin) [self.mapView removeAnnotation:self.pin];
    self.pin = [MKPointAnnotation new];
    self.pin.coordinate = self.selectedCoordinate;
    self.pin.title = @"选定位置";
    [self.mapView addAnnotation:self.pin];
    [self.mapView selectAnnotation:self.pin animated:NO];

    self.coordinateLabel.text = [NSString stringWithFormat:@"纬度 %.6f\n经度 %.6f",
                                 self.selectedCoordinate.latitude,
                                 self.selectedCoordinate.longitude];
    if (center) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(self.selectedCoordinate, 1800, 1800);
        [self.mapView setRegion:region animated:NO];
    }
}

- (void)longPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    self.selectedCoordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    [self updatePinAndRegion:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) return;

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    __weak typeof(self) weakSelf = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || response.mapItems.count == 0) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未找到地点"
                                                                               message:error.localizedDescription ?: @"请换个关键词重试"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
                return;
            }
            weakSelf.selectedCoordinate = response.mapItems.firstObject.placemark.coordinate;
            [weakSelf updatePinAndRegion:YES];
            [weakSelf.searchController setActive:NO];
        });
    }];
}

- (void)addFavorite {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加收藏"
                                                                   message:@"给当前位置起一个名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"收藏名称";
        textField.text = [NSString stringWithFormat:@"%.6f, %.6f", self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"收藏" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) name = @"未命名收藏";
        [weakSelf saveFavoriteNamed:name allowingOverwrite:NO];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveFavoriteNamed:(NSString *)name allowingOverwrite:(BOOL)allowOverwrite {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:LMPreferencesPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    NSArray *saved = prefs[@"favorites"];
    NSMutableArray<NSDictionary *> *favorites = [saved isKindOfClass:[NSArray class]] ? [saved mutableCopy] : [NSMutableArray array];
    NSUInteger existingIndex = [favorites indexOfObjectPassingTest:^BOOL(NSDictionary *favorite, NSUInteger idx, BOOL *stop) {
        return [favorite[@"name"] isEqualToString:name];
    }];
    if (existingIndex != NSNotFound && !allowOverwrite) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"覆盖收藏"
                                                                          message:[NSString stringWithFormat:@"“%@”已经存在，是否覆盖？", name]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [confirm addAction:[UIAlertAction actionWithTitle:@"覆盖" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            [weakSelf saveFavoriteNamed:name allowingOverwrite:YES];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
        return;
    }
    NSDictionary *favorite = @{
        @"name": name,
        @"latitude": @(self.selectedCoordinate.latitude),
        @"longitude": @(self.selectedCoordinate.longitude)
    };
    if (existingIndex != NSNotFound) favorites[existingIndex] = favorite;
    else [favorites addObject:favorite];
    prefs[@"favorites"] = favorites;
    if (![prefs writeToFile:LMPreferencesPath atomically:YES]) {
        UIAlertController *error = [UIAlertController alertControllerWithTitle:@"保存失败" message:@"无法写入收藏。" preferredStyle:UIAlertControllerStyleAlert];
        [error addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:error animated:YES completion:nil];
    }
}

- (void)saveLocation {
    if (!(isfinite(self.selectedCoordinate.latitude) && self.selectedCoordinate.latitude >= -90.0 && self.selectedCoordinate.latitude <= 90.0) ||
        !(isfinite(self.selectedCoordinate.longitude) && self.selectedCoordinate.longitude >= -180.0 && self.selectedCoordinate.longitude <= 180.0)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"位置无效"
                                                                       message:@"请重新在地图上长按选择位置。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:LMPreferencesPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    prefs[@"latitude"] = @(self.selectedCoordinate.latitude);
    prefs[@"longitude"] = @(self.selectedCoordinate.longitude);
    BOOL saved = [prefs writeToFile:LMPreferencesPath atomically:YES];
    if (!saved) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败"
                                                                       message:@"无法写入定位设置，请重新安装插件后再试。"
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
