#import "iOSPretendRootListController.h"
#import "iOSPretendMapPickerController.h"
#import "iOSPretendAppSelectionController.h"
#import "iOSPretendFavoriteLocationsController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>
#import <notify.h>
#import <math.h>

extern char **environ;

static NSString * const LMPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString * const LMPreferencesChanged = @"com.iospretend.iospretend/ReloadPrefs";

@implementation iOSPretendRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *gpsGroup = [PSSpecifier preferenceSpecifierNamed:@"定位"
                                                             target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
    [specifiers addObject:gpsGroup];

    PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"定位信息"
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSSwitchCell
                                                             edit:nil];
    [enabled setProperty:@"gpsEnabled" forKey:@"key"];
    [enabled setProperty:@NO forKey:@"default"];
    [specifiers addObject:enabled];

    PSSpecifier *map = [PSSpecifier preferenceSpecifierNamed:@"地图选点"
                                                       target:self
                                                          set:NULL
                                                          get:NULL
                                                       detail:[iOSPretendMapPickerController class]
                                                         cell:PSLinkCell
                                                         edit:nil];
    [map setProperty:@44.0 forKey:@"height"];
    [specifiers addObject:map];

    PSSpecifier *favorites = [PSSpecifier preferenceSpecifierNamed:@"收藏选择"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:[iOSPretendFavoriteLocationsController class]
                                                               cell:PSLinkCell
                                                               edit:nil];
    [favorites setProperty:@44.0 forKey:@"height"];
    [specifiers addObject:favorites];

    PSSpecifier *simGroup = [PSSpecifier preferenceSpecifierNamed:@"SIM / 地区"
                                                             target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
    [specifiers addObject:simGroup];

    PSSpecifier *simEnabled = [PSSpecifier preferenceSpecifierNamed:@"设备信息"
                                                               target:self set:@selector(setPreferenceValue:specifier:)
                                                                  get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [simEnabled setProperty:@"simEnabled" forKey:@"key"];
    [simEnabled setProperty:@NO forKey:@"default"];
    [specifiers addObject:simEnabled];

    NSArray *simRows = @[
        @[@"国家/地区", @"region", NSStringFromSelector(@selector(selectRegion))],
        @[@"语言", @"lang", NSStringFromSelector(@selector(selectLanguage))],
        @[@"运营商", @"carrier", NSStringFromSelector(@selector(selectCarrier))],
        @[@"网络类型", @"networkType", NSStringFromSelector(@selector(selectNetworkType))]
    ];
    for (NSArray *row in simRows) {
        PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:row[0] target:self set:NULL get:NULL detail:nil cell:PSLinkCell edit:nil];
        [item setProperty:row[1] forKey:@"simKey"];
        item->action = NSSelectorFromString(row[2]);
        [specifiers addObject:item];
    }

    PSSpecifier *scopeGroup = [PSSpecifier preferenceSpecifierNamed:@"生效范围"
                                                               target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
    [specifiers addObject:scopeGroup];

    PSSpecifier *apps = [PSSpecifier preferenceSpecifierNamed:@"生效应用"
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:[iOSPretendAppSelectionController class]
                                                          cell:PSLinkCell
                                                          edit:nil];
    [specifiers addObject:apps];

    PSSpecifier *coordGroup = [PSSpecifier preferenceSpecifierNamed:@"当前位置"
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:nil
                                                                 cell:PSGroupCell
                                                                 edit:nil];
    [specifiers addObject:coordGroup];

    NSArray *fields = @[
        @[@"纬度", @"latitude", @39.9042],
        @[@"经度", @"longitude", @116.4074]
    ];
    for (NSArray *field in fields) {
        PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:field[0]
                                                                target:self
                                                                   set:@selector(setPreferenceValue:specifier:)
                                                                   get:@selector(readPreferenceValue:)
                                                                detail:nil
                                                                  cell:PSEditTextCell
                                                                  edit:nil];
        [specifier setProperty:field[1] forKey:@"key"];
        [specifier setProperty:field[2] forKey:@"default"];
        [specifier setProperty:@YES forKey:@"isDecimalPad"];
        [specifiers addObject:specifier];
    }

    PSSpecifier *actionsGroup = [PSSpecifier preferenceSpecifierNamed:@"操作"
                                                                 target:self
                                                                    set:NULL
                                                                    get:NULL
                                                                 detail:nil
                                                                   cell:PSGroupCell
                                                                   edit:nil];
    [specifiers addObject:actionsGroup];

    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:@"注销并应用"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:nil
                                                               cell:PSButtonCell
                                                               edit:nil];
    respring->action = @selector(respring);
    [specifiers addObject:respring];

    _specifiers = [specifiers copy];
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (NSDictionary *)preferences {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:LMPreferencesPath];
    return [prefs isKindOfClass:[NSDictionary class]] ? prefs : @{};
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    id value = [self preferences][[specifier propertyForKey:@"key"]];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"latitude"] || [key isEqualToString:@"longitude"]) {
        double number = [value doubleValue];
        BOOL valid = isfinite(number) && (([key isEqualToString:@"latitude"] && number >= -90.0 && number <= 90.0) ||
                                          ([key isEqualToString:@"longitude"] && number >= -180.0 && number <= 180.0));
        if (!valid) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数值无效"
                                                                           message:[key isEqualToString:@"latitude"] ? @"纬度应在 -90 到 90 之间。" : @"经度应在 -180 到 180 之间。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            [self reloadSpecifiers];
            return;
        }
    }
    if (key) {
        NSMutableDictionary *prefs = [[self preferences] mutableCopy] ?: [NSMutableDictionary dictionary];
        if (value) prefs[key] = value; else [prefs removeObjectForKey:key];
        BOOL saved = [prefs writeToFile:LMPreferencesPath atomically:YES];
        if (!saved) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败"
                                                                           message:@"无法写入定位设置，请重新安装插件后再试。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)LMPreferencesChanged,
                                         NULL, NULL, YES);
}

- (NSString *)displayValueForSIMKey:(NSString *)key {
    NSDictionary *prefs = [self preferences];
    NSString *value = prefs[key];
    if ([key isEqualToString:@"region"]) {
        NSDictionary *titles = @{@"SG":@"新加坡",@"MY":@"马来西亚",@"TW":@"台湾",@"JP":@"日本",@"KR":@"韩国",@"TH":@"泰国",@"US":@"美国",@"GB":@"英国",@"DE":@"德国",@"FR":@"法国",@"CA":@"加拿大",@"AU":@"澳大利亚"};
        return titles[value ?: @"SG"] ?: @"新加坡";
    }
    if ([key isEqualToString:@"lang"]) {
        NSDictionary *titles = @{@"auto":@"跟随国家",@"ja":@"日语",@"ko":@"韩语",@"zh-Hans":@"简体中文",@"zh-Hant":@"繁体中文",@"en":@"英语",@"ms":@"马来语",@"de":@"德语",@"fr":@"法语",@"th":@"泰语"};
        return titles[value ?: @"auto"] ?: @"跟随国家";
    }
    if ([key isEqualToString:@"networkType"]) {
        NSDictionary *titles = @{@"auto": @"自动", @"wifi": @"WiFi", @"cellular": @"蜂窝数据"};
        return titles[value ?: @"auto"] ?: @"自动";
    }

    if ([key isEqualToString:@"carrier"]) {
        NSDictionary *titles = @{
            @"auto":@"自动", @"SG-ST":@"Singtel", @"SG-SH":@"StarHub", @"SG-M1":@"M1",
            @"MY-CEL":@"Celcom", @"MY-MAXIS":@"Maxis", @"MY-DIGI":@"Digi",
            @"TW-CHT":@"中华电信", @"TW-TWM":@"台湾大哥大", @"TW-FET":@"远传电信",
            @"JP-DOCOMO":@"NTT Docomo", @"JP-SB":@"SoftBank", @"JP-AU":@"au",
            @"KR-SKT":@"SK Telecom", @"KR-KT":@"KT", @"KR-LGU":@"LG U+",
            @"TH-AIS":@"AIS", @"TH-TRUE":@"TrueMove", @"TH-DTAC":@"dtac",
            @"US-ATT":@"AT&T", @"US-VZW":@"Verizon", @"US-TMO":@"T-Mobile",
            @"GB-EE":@"EE", @"GB-VF":@"Vodafone", @"GB-O2":@"O2", @"GB-3":@"Three",
            @"DE-DT":@"Deutsche Telekom", @"DE-VF":@"Vodafone", @"DE-O2":@"O2",
            @"FR-ORG":@"Orange", @"FR-SFR":@"SFR", @"FR-BYG":@"Bouygues",
            @"CA-RGS":@"Rogers", @"CA-BELL":@"Bell", @"CA-TLS":@"Telus",
            @"AU-TLS":@"Telstra", @"AU-OPT":@"Optus", @"AU-VF":@"Vodafone"
        };
        return titles[value ?: @"auto"] ?: value ?: @"自动";
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *simKey = [specifier propertyForKey:@"simKey"];
    if (simKey.length) {
        static NSString *identifier = @"CFOSIMValueCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.textLabel.text = specifier.name;
        cell.detailTextLabel.text = [self displayValueForSIMKey:simKey];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)selectRegion { [self showChoiceWithTitle:@"国家/地区" key:@"region" values:@[@"SG",@"MY",@"TW",@"JP",@"KR",@"TH",@"US",@"GB",@"DE",@"FR",@"CA",@"AU"] titles:@[@"新加坡",@"马来西亚",@"台湾",@"日本",@"韩国",@"泰国",@"美国",@"英国",@"德国",@"法国",@"加拿大",@"澳大利亚"]]; }
- (void)selectLanguage { [self showChoiceWithTitle:@"语言" key:@"lang" values:@[@"auto",@"ja",@"ko",@"zh-Hans",@"zh-Hant",@"en",@"ms",@"de",@"fr",@"th"] titles:@[@"跟随国家",@"日语",@"韩语",@"简体中文",@"繁体中文",@"英语",@"马来语",@"德语",@"法语",@"泰语"]]; }
- (void)selectNetworkType { [self showChoiceWithTitle:@"网络类型" key:@"networkType" values:@[@"auto",@"wifi",@"cellular"] titles:@[@"自动",@"WiFi",@"蜂窝数据"]]; }

- (void)selectCarrier {
    NSString *region = [self preferences][@"region"] ?: @"SG";
    NSDictionary *map = @{
        @"SG": @[@[@"auto",@"SG-ST",@"SG-SH",@"SG-M1"], @[@"自动",@"Singtel",@"StarHub",@"M1"]],
        @"MY": @[@[@"auto",@"MY-CEL",@"MY-MAXIS",@"MY-DIGI"], @[@"自动",@"Celcom",@"Maxis",@"Digi"]],
        @"TW": @[@[@"auto",@"TW-CHT",@"TW-TWM",@"TW-FET"], @[@"自动",@"中华电信",@"台湾大哥大",@"远传电信"]],
        @"JP": @[@[@"auto",@"JP-DOCOMO",@"JP-SB",@"JP-AU"], @[@"自动",@"NTT Docomo",@"SoftBank",@"au"]],
        @"KR": @[@[@"auto",@"KR-SKT",@"KR-KT",@"KR-LGU"], @[@"自动",@"SK Telecom",@"KT",@"LG U+"]],
        @"TH": @[@[@"auto",@"TH-AIS",@"TH-TRUE",@"TH-DTAC"], @[@"自动",@"AIS",@"TrueMove",@"dtac"]],
        @"US": @[@[@"auto",@"US-ATT",@"US-VZW",@"US-TMO"], @[@"自动",@"AT&T",@"Verizon",@"T-Mobile"]],
        @"GB": @[@[@"auto",@"GB-EE",@"GB-VF",@"GB-O2",@"GB-3"], @[@"自动",@"EE",@"Vodafone",@"O2",@"Three"]],
        @"DE": @[@[@"auto",@"DE-DT",@"DE-VF",@"DE-O2"], @[@"自动",@"Deutsche Telekom",@"Vodafone",@"O2"]],
        @"FR": @[@[@"auto",@"FR-ORG",@"FR-SFR",@"FR-BYG"], @[@"自动",@"Orange",@"SFR",@"Bouygues"]],
        @"CA": @[@[@"auto",@"CA-RGS",@"CA-BELL",@"CA-TLS"], @[@"自动",@"Rogers",@"Bell",@"Telus"]],
        @"AU": @[@[@"auto",@"AU-TLS",@"AU-OPT",@"AU-VF"], @[@"自动",@"Telstra",@"Optus",@"Vodafone"]]
    };
    NSArray *pair = map[region] ?: map[@"SG"];
    [self showChoiceWithTitle:@"运营商" key:@"carrier" values:pair[0] titles:pair[1]];
}

- (void)showChoiceWithTitle:(NSString *)title key:(NSString *)key values:(NSArray *)values titles:(NSArray *)titles {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSUInteger i = 0; i < values.count; i++) {
        [sheet addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableDictionary *prefs = [[self preferences] mutableCopy] ?: [NSMutableDictionary dictionary];
            prefs[key] = values[i];
            if ([key isEqualToString:@"region"]) prefs[@"carrier"] = @"auto";
            BOOL saved = [prefs writeToFile:LMPreferencesPath atomically:YES];
            if (!saved) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存失败"
                                                                               message:@"无法写入设备信息设置，请重新安装插件后再试。"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)LMPreferencesChanged, NULL, NULL, YES);
            [self reloadSpecifiers];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = self.view.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)respring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"注销并应用"
                                                                   message:@"将立即注销桌面，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"注销" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        pid_t pid = 0;
        NSString *killallPath = @"/var/jb/usr/bin/killall";
        if (![[NSFileManager defaultManager] fileExistsAtPath:killallPath]) {
            killallPath = @"/usr/bin/killall";
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:killallPath]) {
            notify_post("com.apple.springboard.respring");
            return;
        }
        char path[512];
        [killallPath getCString:path maxLength:sizeof(path) encoding:NSUTF8StringEncoding];
        char *const argv[] = {path, (char *)"-9", (char *)"SpringBoard", NULL};
        int ret = posix_spawn(&pid, path, NULL, NULL, argv, environ);
        if (ret != 0) {
            notify_post("com.apple.springboard.respring");
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
