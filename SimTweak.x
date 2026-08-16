#import <Foundation/Foundation.h>

static NSString *const kPrefsPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString *const kPrefsChangedNotification = @"com.iospretend.iospretend/ReloadPrefs";

// Cached resolved device configuration (region + carrier + lang merged).
static NSDictionary *gConfig = nil;

// ---------------------------------------------------------------------------
// Region / carrier / language lookup tables.
// ---------------------------------------------------------------------------

static NSDictionary *regionConfig(NSString *region) {
    static NSDictionary *all = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = @{
            @"JP": @{@"carrier": @"NTT Docomo", @"iso": @"jp", @"mcc": @"440", @"mnc": @"10",
                     @"tz": @"Asia/Tokyo", @"country": @"JP", @"lang": @"ja",
                     @"identifier": @"ja_JP", @"preferred": @[@"ja-JP", @"en"]},
            @"KR": @{@"carrier": @"SK Telecom", @"iso": @"kr", @"mcc": @"450", @"mnc": @"05",
                     @"tz": @"Asia/Seoul", @"country": @"KR", @"lang": @"ko",
                     @"identifier": @"ko_KR", @"preferred": @[@"ko-KR", @"en"]},
            @"SG": @{@"carrier": @"Singtel", @"iso": @"sg", @"mcc": @"525", @"mnc": @"01",
                     @"tz": @"Asia/Singapore", @"country": @"SG", @"lang": @"zh-Hans",
                     @"identifier": @"zh-Hans_SG", @"preferred": @[@"zh-Hans-SG", @"en"]},
            @"TW": @{@"carrier": @"Chunghwa Telecom", @"iso": @"tw", @"mcc": @"466", @"mnc": @"92",
                     @"tz": @"Asia/Taipei", @"country": @"TW", @"lang": @"zh-Hant",
                     @"identifier": @"zh_Hant_TW", @"preferred": @[@"zh-Hant-TW", @"en"]},
            @"MY": @{@"carrier": @"Celcom", @"iso": @"my", @"mcc": @"502", @"mnc": @"19",
                     @"tz": @"Asia/Kuala_Lumpur", @"country": @"MY", @"lang": @"ms",
                     @"identifier": @"ms_MY", @"preferred": @[@"ms-MY", @"en"]},
            @"US": @{@"carrier": @"AT&T", @"iso": @"us", @"mcc": @"310", @"mnc": @"410",
                     @"tz": @"America/New_York", @"country": @"US", @"lang": @"en",
                     @"identifier": @"en_US", @"preferred": @[@"en-US", @"en"]},
            @"GB": @{@"carrier": @"EE", @"iso": @"gb", @"mcc": @"234", @"mnc": @"30",
                     @"tz": @"Europe/London", @"country": @"GB", @"lang": @"en",
                     @"identifier": @"en_GB", @"preferred": @[@"en-GB", @"en"]},
            @"DE": @{@"carrier": @"Deutsche Telekom", @"iso": @"de", @"mcc": @"262", @"mnc": @"01",
                     @"tz": @"Europe/Berlin", @"country": @"DE", @"lang": @"de",
                     @"identifier": @"de_DE", @"preferred": @[@"de-DE", @"en"]},
            @"FR": @{@"carrier": @"Orange", @"iso": @"fr", @"mcc": @"208", @"mnc": @"01",
                     @"tz": @"Europe/Paris", @"country": @"FR", @"lang": @"fr",
                     @"identifier": @"fr_FR", @"preferred": @[@"fr-FR", @"en"]},
            @"CA": @{@"carrier": @"Rogers", @"iso": @"ca", @"mcc": @"302", @"mnc": @"720",
                     @"tz": @"America/Toronto", @"country": @"CA", @"lang": @"en",
                     @"identifier": @"en_CA", @"preferred": @[@"en-CA", @"en"]},
            @"AU": @{@"carrier": @"Telstra", @"iso": @"au", @"mcc": @"505", @"mnc": @"01",
                     @"tz": @"Australia/Sydney", @"country": @"AU", @"lang": @"en",
                     @"identifier": @"en_AU", @"preferred": @[@"en-AU", @"en"]},
            @"TH": @{@"carrier": @"AIS", @"iso": @"th", @"mcc": @"520", @"mnc": @"03",
                     @"tz": @"Asia/Bangkok", @"country": @"TH", @"lang": @"th",
                     @"identifier": @"th_TH", @"preferred": @[@"th-TH", @"en"]},
        };
    });
    return all[region] ?: all[@"MY"];
}

static NSDictionary *carrierConfig(NSString *carrierKey) {
    static NSDictionary *all = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = @{
            @"JP-DOCOMO": @{@"carrier": @"NTT Docomo", @"mcc": @"440", @"mnc": @"10"},
            @"JP-SB":     @{@"carrier": @"SoftBank",   @"mcc": @"440", @"mnc": @"20"},
            @"JP-AU":     @{@"carrier": @"au",         @"mcc": @"440", @"mnc": @"50"},
            @"KR-SKT":    @{@"carrier": @"SK Telecom", @"mcc": @"450", @"mnc": @"05"},
            @"KR-KT":     @{@"carrier": @"KT",         @"mcc": @"450", @"mnc": @"02"},
            @"KR-LGU":    @{@"carrier": @"LG U+",      @"mcc": @"450", @"mnc": @"06"},
            @"SG-ST":     @{@"carrier": @"Singtel",    @"mcc": @"525", @"mnc": @"01"},
            @"SG-SH":     @{@"carrier": @"StarHub",    @"mcc": @"525", @"mnc": @"03"},
            @"SG-M1":     @{@"carrier": @"M1",         @"mcc": @"525", @"mnc": @"07"},
            @"TW-CHT":    @{@"carrier": @"Chunghwa Telecom", @"mcc": @"466", @"mnc": @"92"},
            @"TW-TWM":    @{@"carrier": @"Taiwan Mobile",     @"mcc": @"466", @"mnc": @"97"},
            @"TW-FET":    @{@"carrier": @"Far EasTone",       @"mcc": @"466", @"mnc": @"01"},
            @"MY-CEL":    @{@"carrier": @"Celcom",     @"mcc": @"502", @"mnc": @"19"},
            @"MY-MAXIS":  @{@"carrier": @"Maxis",      @"mcc": @"502", @"mnc": @"12"},
            @"MY-DIGI":   @{@"carrier": @"Digi",       @"mcc": @"502", @"mnc": @"16"},
            @"US-ATT":    @{@"carrier": @"AT&T",       @"mcc": @"310", @"mnc": @"410"},
            @"US-VZW":    @{@"carrier": @"Verizon",    @"mcc": @"310", @"mnc": @"004"},
            @"US-TMO":    @{@"carrier": @"T-Mobile",   @"mcc": @"310", @"mnc": @"260"},
            @"GB-EE":     @{@"carrier": @"EE",         @"mcc": @"234", @"mnc": @"30"},
            @"GB-VF":     @{@"carrier": @"Vodafone",   @"mcc": @"234", @"mnc": @"15"},
            @"GB-O2":     @{@"carrier": @"O2",         @"mcc": @"234", @"mnc": @"10"},
            @"GB-3":      @{@"carrier": @"Three",      @"mcc": @"234", @"mnc": @"20"},
            @"DE-DT":     @{@"carrier": @"Deutsche Telekom", @"mcc": @"262", @"mnc": @"01"},
            @"DE-VF":     @{@"carrier": @"Vodafone",          @"mcc": @"262", @"mnc": @"02"},
            @"DE-O2":     @{@"carrier": @"O2",                @"mcc": @"262", @"mnc": @"03"},
            @"FR-ORG":    @{@"carrier": @"Orange",     @"mcc": @"208", @"mnc": @"01"},
            @"FR-SFR":    @{@"carrier": @"SFR",        @"mcc": @"208", @"mnc": @"10"},
            @"FR-BYG":    @{@"carrier": @"Bouygues",   @"mcc": @"208", @"mnc": @"20"},
            @"CA-RGS":    @{@"carrier": @"Rogers",     @"mcc": @"302", @"mnc": @"720"},
            @"CA-BELL":   @{@"carrier": @"Bell",       @"mcc": @"302", @"mnc": @"610"},
            @"CA-TLS":    @{@"carrier": @"Telus",      @"mcc": @"302", @"mnc": @"220"},
            @"AU-TLS":    @{@"carrier": @"Telstra",    @"mcc": @"505", @"mnc": @"01"},
            @"AU-OPT":    @{@"carrier": @"Optus",      @"mcc": @"505", @"mnc": @"02"},
            @"AU-VF":     @{@"carrier": @"Vodafone",   @"mcc": @"505", @"mnc": @"03"},
            @"TH-AIS":    @{@"carrier": @"AIS",        @"mcc": @"520", @"mnc": @"03"},
            @"TH-TRUE":   @{@"carrier": @"TrueMove",   @"mcc": @"520", @"mnc": @"04"},
            @"TH-DTAC":   @{@"carrier": @"dtac",       @"mcc": @"520", @"mnc": @"18"},
        };
    });
    return all[carrierKey];
}

static NSDictionary *langConfig(NSString *langKey) {
    static NSDictionary *all = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = @{
            @"ja":       @{@"lang": @"ja", @"identifier": @"ja_JP", @"preferred": @[@"ja-JP", @"en"]},
            @"ko":       @{@"lang": @"ko", @"identifier": @"ko_KR", @"preferred": @[@"ko-KR", @"en"]},
            @"zh-Hans":  @{@"lang": @"zh-Hans", @"identifier": @"zh-Hans_CN", @"preferred": @[@"zh-Hans-CN", @"en"]},
            @"zh-Hant":  @{@"lang": @"zh-Hant", @"identifier": @"zh_Hant_TW", @"preferred": @[@"zh-Hant-TW", @"en"]},
            @"en":       @{@"lang": @"en", @"identifier": @"en_US", @"preferred": @[@"en-US", @"en"]},
            @"ms":       @{@"lang": @"ms", @"identifier": @"ms_MY", @"preferred": @[@"ms-MY", @"en"]},
            @"de":       @{@"lang": @"de", @"identifier": @"de_DE", @"preferred": @[@"de-DE", @"en"]},
            @"fr":       @{@"lang": @"fr", @"identifier": @"fr_FR", @"preferred": @[@"fr-FR", @"en"]},
            @"th":       @{@"lang": @"th", @"identifier": @"th_TH", @"preferred": @[@"th-TH", @"en"]},
        };
    });
    return all[langKey];
}

// ---------------------------------------------------------------------------
// Preference access and cached resolved configuration.
// ---------------------------------------------------------------------------

static BOOL CFONumberForKey(NSDictionary *prefs, NSString *key) {
    id value = prefs[key];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return NO;
}

static void CFOReloadConfig(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
    NSDictionary *base = nil;
    NSString *region = prefs[@"region"];
    if ([region isKindOfClass:[NSString class]] && region.length) {
        base = regionConfig(region);
    }
    if (!base) base = regionConfig(@"SG");

    NSMutableDictionary *cfg = [base mutableCopy];
    NSString *carrierKey = @"auto";
    NSString *langKey = @"auto";
    id ck = prefs[@"carrier"];
    if ([ck isKindOfClass:[NSString class]] && [ck length]) carrierKey = ck;
    id lk = prefs[@"lang"];
    if ([lk isKindOfClass:[NSString class]] && [lk length]) langKey = lk;

    NSDictionary *carrier = carrierConfig(carrierKey);
    if (carrier) {
        cfg[@"carrier"] = carrier[@"carrier"];
        cfg[@"mcc"] = carrier[@"mcc"];
        cfg[@"mnc"] = carrier[@"mnc"];
    }

    if (![langKey isEqualToString:@"auto"]) {
        NSDictionary *lc = langConfig(langKey);
        if (lc) {
            cfg[@"lang"] = lc[@"lang"];
            cfg[@"identifier"] = lc[@"identifier"];
            cfg[@"preferred"] = lc[@"preferred"];
        }
    }
    gConfig = [cfg copy];
}

static NSDictionary *currentConfig(void) {
    if (!gConfig) CFOReloadConfig();
    return gConfig;
}

// Called by every hook getter: NO means "return the real value".
static BOOL CFOShouldSpoofCurrentProcess(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
    if (!CFONumberForKey(prefs, @"simEnabled")) return NO;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    NSArray *apps = prefs[@"selectedApps"];
    return bundleID.length > 0 && [apps isKindOfClass:[NSArray class]] && [apps containsObject:bundleID];
}

// ---------------------------------------------------------------------------
// Region calendar (only used by NSCalendar class-method hooks).
// ---------------------------------------------------------------------------

static NSCalendar *regionCalendar(void) {
    NSDictionary *cfg = currentConfig();
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    cal.locale = [NSLocale localeWithLocaleIdentifier:cfg[@"identifier"]];
    cal.timeZone = [NSTimeZone timeZoneWithName:cfg[@"tz"]];
    return cal;
}

// ---------------------------------------------------------------------------
// Hooks. Every getter re-checks the enabled flag and app whitelist at call
// time so toggling the switch or editing the app list takes effect on the
// next read (no respring required).
// ---------------------------------------------------------------------------

%hook CTCarrier

- (NSString *)carrierName {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"carrier"];
}

- (NSString *)isoCountryCode {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"iso"];
}

- (NSString *)mobileCountryCode {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"mcc"];
}

- (NSString *)mobileNetworkCode {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"mnc"];
}

- (BOOL)allowsVOIP {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return YES;
}

%end

%hook CTTelephonyNetworkInfo

// Suppress real network updates only while spoofing is active.
- (BOOL)updateNetworkInfoAndShouldNotifyClient:(BOOL *)client forContext:(id)context {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return NO;
}

- (BOOL)getCarrierName:(id *)name forContext:(id)context withError:(id *)error {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    if (name) *name = currentConfig()[@"carrier"];
    return YES;
}

- (BOOL)getMobileCountryCode:(id *)mcc andIsoCountryCode:(id *)iso forContext:(id)context withError:(id *)error {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    if (mcc) *mcc = currentConfig()[@"mcc"];
    if (iso) *iso = currentConfig()[@"iso"];
    return YES;
}

- (BOOL)getMobileNetworkCode:(id *)mnc forContext:(id)context withError:(id *)error {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    if (mnc) *mnc = currentConfig()[@"mnc"];
    return YES;
}

%end

%hook NSTimeZone

+ (NSTimeZone *)systemTimeZone {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:currentConfig()[@"tz"]];
    return tz ?: %orig;
}

+ (NSTimeZone *)localTimeZone {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:currentConfig()[@"tz"]];
    return tz ?: %orig;
}

+ (NSTimeZone *)defaultTimeZone {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:currentConfig()[@"tz"]];
    return tz ?: %orig;
}

%end

%hook NSLocale

// Only the shared "current" locale object is spoofed. Explicitly created
// locales (e.g. [NSLocale localeWithLocaleIdentifier:@"en_US"]) keep their
// real values so app-controlled formatting and protocol logic stay intact.
+ (NSLocale *)currentLocale {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return [NSLocale localeWithLocaleIdentifier:currentConfig()[@"identifier"]];
}

+ (NSLocale *)autoupdatingCurrentLocale {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return [NSLocale localeWithLocaleIdentifier:currentConfig()[@"identifier"]];
}

- (NSString *)countryCode {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"country"];
}

- (NSString *)languageCode {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"lang"];
}

- (NSString *)localeIdentifier {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"identifier"];
}

- (id)objectForKey:(id)key {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    if ([key isEqualToString:NSLocaleCountryCode]) return currentConfig()[@"country"];
    if ([key isEqualToString:NSLocaleLanguageCode]) return currentConfig()[@"lang"];
    if ([key isEqualToString:NSLocaleIdentifier]) return currentConfig()[@"identifier"];
    return %orig;
}

+ (NSArray<NSString *> *)preferredLanguages {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return currentConfig()[@"preferred"];
}

%end

%hook NSCalendar

+ (NSCalendar *)currentCalendar {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return regionCalendar() ?: %orig;
}

+ (NSCalendar *)autoupdatingCurrentCalendar {
    if (!CFOShouldSpoofCurrentProcess()) return %orig;
    return regionCalendar() ?: %orig;
}

%end

static void CFOPreferencesChangedCallback(CFNotificationCenterRef center,
                                          void *observer,
                                          CFStringRef name,
                                          const void *object,
                                          CFDictionaryRef userInfo) {
    CFOReloadConfig();
}

%ctor {
    @autoreleasepool {
        CFOReloadConfig();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        CFOPreferencesChangedCallback,
                                        (__bridge CFStringRef)kPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        %init;
    }
}
