# Dashboard access ও error flow — 18 October 2026

আপনার uploaded `native_admin_overview.dart` নতুন baseline। Total label ও value-এর
FontWeight.w600 এবং পুরো chart card rendering রাখা হয়েছে। এই ধাপে native
DocDashboard-এর access, expiry ও error-dialog logic মিলিয়ে সংশোধন করা হয়েছে।

## Apply

নতুন `DocDiary_Dashboard_Access_Patch.zip` extract করুন। আপনার বর্তমান
`docdiary_ios` project-এর terminal থেকে:

```bash
python3 ~/Downloads/DocDiary_Dashboard_Access_Patch/apply_access_patch.py .
flutter pub get
bash tool/verify.sh --ios-simulator
```

এই patch-এর installer ব্যবহার করুন। আলাদা করে পুরো `lib` বা `pubspec.yaml`
replace করার প্রয়োজন নেই। Installer overview-এর UI functions রাখে, app/layout-এ
প্রয়োজনীয় integration merge করে এবং Lato font/license যোগ করে। আগে পূর্ণ backup
তৈরি করে; নাম terminal-এ দেখাবে। Existing iOS runner, signing এবং dependency
versions বদলায় না। নতুন font-এর জন্য app stop করে আবার run করুন।

## যুক্ত/সংশোধিত আচরণ

| পরিস্থিতি | Dialog / action |
| --- | --- |
| Doctor বা Admin forced flag1 | Forced Log Out! → non-dismissible OK → session clear → Login |
| access_flag / usr_mob_app_access1 না হলে | Access Denied! → OK → session clear → Login |
| Inactive/unavailable doctor | Native status ও effected date; না থাকলে No User Data Found |
| Admin information নেই | No Information Found! এবং native message |
| Expiry গতকাল বা তার আগে | Access Expired! → OK → session clear → Login |
| Expiry আজ থেকে ৩ দিন পর্যন্ত | Access Expired Warning!, date ও day(s) left; প্রথম পূর্ণ dashboard success-এ একবার |
| Expiry আজ | Valid; 0 day(s) left warning |
| Profile/full dashboard/initial Admin chart/picture request ব্যর্থ | Native WARNING! layout; LOG OUT / EXIT / RETRY |
| Summary tab বা chart filter/date request ব্যর্থ | Error! / OK; সংশ্লিষ্ট refresh, অন্য অংশ/selected period থাকে |
| Logout-এর Keychain clear ব্যর্থ | Dashboard blocked থাকে; Retry আগে session clear করে |

Retry নতুন login-এর forced flag reset করে না। Existing dashboard refresh/resume
কোনো loginLog বা expiry-update POST করে না। Background/logout/switch-এর পুরনো
response নতুন account-এ data/dialog বসাতে বা পরের request queue করতে পারবে না।

## iOS-এর Exit পার্থক্য

Android `finish()`/`System.exit()` দিয়ে app বন্ধ করার সমতুল্য supported iOS API
নেই। EXIT button রাখায় Home gesture/Home button দিয়ে বের হওয়ার নির্দেশ দেখায়;
কোনো saved sign-in মুছে না। OK করলে error handler-এ ফিরে Retry/Log Out করা যায়।
Access denied/expired-এর OK session clear করে Login-এ ফেরে, Android-এর মতো
process/activity বন্ধ করে না। App force-crash করা হয়নি।

## Offline dialog preview

Live backend বা production flags না বদলে উদাহরণ দেখুন:

```bash
flutter run -t lib/main_dashboard_preview.dart --dart-define=DASHBOARD_PREVIEW_ROLE=doctor --dart-define=DASHBOARD_PREVIEW_ACCESS=warn3
```

Admin-এর জন্য ROLE=admin দিন। ACCESS options:

| ACCESS | ফলাফল |
| --- | --- |
| warn3 / warn0 | 3 / 0 দিন বাকি warning |
| expired | Access Expired! |
| denied | Mobile app Access Denied! |
| forced | Forced Log Out! |
| inactive | Doctor status/effected-date denial; ROLE=doctor |
| no_admin | No Information Found!; ROLE=admin |
| retry | Profile request একবার ব্যর্থ; RETRY করলে dashboard আসে |
| ok | স্বাভাবিক preview |

Preview-এর clock/data synthetic। আসল API-এর জন্য `flutter run -t lib/main.dart`।

## Mac-এ যাচাই

1. Doctor/Admin দুটির forced, denied, expired ও 0–3 দিনের warning দেখুন।
2. Blocking dialog outside tap/back-এ বন্ধ হয় না; OK-এর আগে session clear হয় না।
3. Full request error-এ তিন button; tab/chart error-এ OK ও refresh পরীক্ষা করুন।
4. Retry-তে প্রয়োজনীয় data আসে; আগের account-এর dialog বা response ফিরে আসে না।
5. Background/resume, switch/cancel, logout এবং saved-login restore পরীক্ষা করুন।
6. আপনার totals-এর lighter boldness, পূর্বের padding/shadow/Center, date axis এবং
   payment grouping মিলিয়ে দেখুন।

২০টি নতুন contract case ও ১৬টি widget case লেখা হয়েছে; আগের test-গুলোর denial/
error expectations নতুন native flow অনুযায়ী বদলেছে। **এখানে Flutter/Dart/Xcode
নেই; নতুন analyzer, Flutter tests বা iOS build চালানো হয়নি।** Source grammar ও
installer checks তাদের বিকল্প নয়। Mac verification ও visual acceptance বাকি।

প্রয়োজনে দেখানো backup দিয়ে restore:

```bash
python3 ~/Downloads/DocDiary_Dashboard_Access_Patch/restore_access_backup.py docdiary_before_dashboard_access_YYYYMMDD_HHMMSS_xxxxxx.zip .
flutter pub get
```

পুরো audit ও অবশিষ্ট scope: `docs/DASHBOARD_ACCESS_PARITY.md`। Profile/camera
upload, destination screens এবং iOS StoreKit review এখনও আলাদা কাজ; এই patch-কে
সম্পূর্ণ app conversion বা সব DocDashboard feature-এর completion বলা হচ্ছে না।
