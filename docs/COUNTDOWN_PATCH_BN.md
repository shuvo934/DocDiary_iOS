# Doctor dashboard — Next Meeting countdown

আপনার সর্বশেষ পুরো top edge-এর shadow, 6px content padding, 75sdp appointment
card এবং `_Identity`-এর পরিবর্তন রাখা হয়েছে। Installer আপনার বর্তমান layout-এ
শুধু meeting integration merge করে; নতুন project তৈরি করতে হবে না।

## এই ধাপের কাজ

- Native `last_sc` / `next_sc` অনুযায়ী countdown এবং ডান দিক থেকে কমতে থাকা progress।
- Native timer icon, দুই অঙ্কের h/m/s, প্রয়োজনমতো hour/minute লুকানো।
- Patient name ও meeting time-এর native formatting branches।
- সময় শেষ হলে dashboard/menu লুকিয়ে loading; ৩ সেকেন্ড পরে Today-এর data refresh।
- Background-এ timer/expiry request বন্ধ; ফিরে এলে বর্তমান সময় দিয়ে data যাচাই।
- চলমান API request থাকলে refresh queue হয়; একসঙ্গে duplicate request চলে না।
- Logout/switch/dispose হলে পুরোনো account-এর callback বন্ধ।
- Network error-এ Retry; বানানো “No Upcoming Meeting” বা automatic error retry নয়।

## Apply করুন

ZIP-টি Downloads-এ extract করলে `DocDiary_Countdown_Patch` folder পাবেন।
আপনার বর্তমান `docdiary_ios` project-এর terminal-এ চালান:

```bash
python3 ~/Downloads/DocDiary_Countdown_Patch/apply_countdown_patch.py .
flutter pub get
bash tool/verify.sh --ios-simulator
```

প্রথম command পরিবর্তিত file-গুলোর backup ZIP project-এর মধ্যে তৈরি করবে এবং
তার নাম দেখাবে। Font/SDK/dependency/version/iOS settings-এর অন্য পরিবর্তন রাখবে।
পুরো source project download বা replace করবেন না।

## Backend ছাড়াই দ্রুত countdown দেখুন

```bash
flutter run -t lib/main_dashboard_preview.dart --dart-define=DASHBOARD_PREVIEW_TIMER_SECONDS=20
```

এটি সম্পূর্ণ offline example data। প্রথম meeting-এর সময় ফুরোলে প্রায় ৩ সেকেন্ড
loading-এর পরে দ্বিতীয় example patient/meeting আসবে; সেটিও শেষ হলে “No Upcoming
Meeting Available” দেখাবে। App background করে ১০–১৫ সেকেন্ড পরে ফিরে দেখুন।
Profile/center switch এই preview-তে real backend ব্যবহার করে না।

Live app চালাতে:

```bash
flutter run -t lib/main.dart
```

যাচাই করুন: native-এর সঙ্গে একই doctor/data/সময় নিয়ে patient/time ও progress;
tab change; expiry-তে Today ফিরে আসা; background/resume; connection failure/Retry;
logout/switch। Native API timestamp device-local ধরা হয়েছে, আগের Android-এর মতো।

## প্রয়োজনে backup ফেরত

Installer যে backup নাম দেখিয়েছে, সেটি দিয়ে project-এর terminal-এ চালান:

```bash
python3 ~/Downloads/DocDiary_Countdown_Patch/restore_countdown_backup.py docdiary_before_countdown_YYYYMMDD_HHMMSS_xxxxxx.zip .
flutter pub get
```

এটি backup-এর আগের file ফেরায় এবং patch যোগ করা নতুন file সরায়।

## যাচাইয়ের অবস্থা

এখানে source/import/assets, independent Dart grammar, font এবং installer fixture
checks করা হয়েছে। Flutter/Dart SDK ও Xcode নেই, তাই নতুন Flutter test/analyzer/iOS
build চালানো হয়নি। এই ধাপে ২১টি focused test case লেখা হয়েছে; Mac-এ pass হওয়ার
log এবং native-এর সঙ্গে UI review এখনও প্রয়োজন। “Error-free” বা pixel-perfect
হওয়া এখনও verified বলা হচ্ছে না।

Native-এর day-of-month-only date comparison এখানে আগের মতোই পুরো calendar date
দিয়ে যাচাই হয়। Invalid timestamp/zero interval-এ crash আটকানো হয়েছে; বড় text বা
অনেক ঘণ্টার timer cell-এর ভেতর fit হয়। বিস্তারিত `DASHBOARD_NATIVE_REFERENCE.md`।

এটি Doctor countdown checkpoint। পরবর্তী কাজ Admin OVERVIEW charts ও filters;
profile camera/upload এবং menu destination screens পৃথক ধাপ।
