# Dashboard — ধাপ ১

এটি আপনার বর্তমান `docdiary_ios` project-এর জন্য focused patch। নতুন project
তৈরি বা পুরো project replace করতে হবে না।

## কী তৈরি হয়েছে

- Native-এর Dashboard header, logo, switch/logout icons ও উপরে গোল করা সাদা surface।
- Greeting, doctor/admin name, বন্ধনীর মধ্যে center name, গোল profile picture।
- Doctor manager হলে Report Manager + All Appointment; manager না হয়ে department
  head হলে Unit Appointment; সাধারণ doctor-এর জন্য এই অতিরিক্ত buttons নেই।
- Doctor-এর TOTAL SCHEDULE / BLOCKED SCHEDULE এবং TOTAL / COMPLETED / REMAINING cards।
- Admin-এর Appointment TOTAL / CANCELED এবং Payment RECEIVE / RETURN cards।
- TODAY / CURRENT WEEK / CURRENT MONTH / NEXT MONTH tabs, native full-date labels।
- Role ও permission অনুযায়ী native bottom-navigation icons।
- আগের summary API, date-range logic, access checks, refresh, switch ও logout integration।
- Original doctor/admin picture GET endpoints; না পেলে native default picture।
- Next Meeting-এর title, time ও patient information-এর প্রাথমিক panel।

## এই ধাপে যা complete বলা হচ্ছে না

Admin-এর OVERVIEW charts, month/year/type filters; running countdown/progress ও
সময় শেষ হলে automatic refresh; profile-picture capture/crop/upload; bottom menu
ও appointment/report buttons-এর destination screens পরবর্তী ধাপের কাজ।
এই destination-এ চাপলে development build-এ একটি স্পষ্ট availability notice দেখায়।
Charts বা countdown-এর জন্য live app-এ বানানো data দেখানো হয় না।

এই patch সম্পূর্ণ dashboard conversion বা pixel-perfect acceptance নয়। Native
Android এবং iPhone-এর screenshot মিলিয়ে এই ধাপের UI review করতে হবে।

## Apply করার নিয়ম

1. `DocDiary_Dashboard_Patch.zip` Downloads-এ রেখে unzip করুন।
2. Terminal-এ আপনার বর্তমান `docdiary_ios` project folder-এ যান।
3. নিচের command চালান:

```bash
bash ~/Downloads/DocDiary_Dashboard_Patch/apply_dashboard_patch.sh "$PWD"
flutter pub get
bash tool/verify.sh
```

ফোল্ডার Downloads-এর অন্য জায়গায় থাকলে command-এর patch path বদলাবেন।
Installer প্রথমে payload ও project যাচাই করে এবং পরিবর্তিত পুরোনো files-এর
`docdiary_before_dashboard_....zip` backup রাখে। তারপর dashboard files যোগ/replace
করে ও pubspec-এ শুধু Archivo ও Baloo fonts merge করে। Splash/login/selection/auth
files বা iOS settings replace করে না। সব files একই থাকলে পুনরায় apply-তে কোনো
পরিবর্তন করে না। কোনো write ব্যর্থ হলে আগের writes ফেরত দেওয়ার চেষ্টা করে;
backup সব সময় থেকে যায়।

Fonts native source অনুযায়ী bundled; নতুন Flutter plugin নেই। `flutter pub get`
চালাবেন, এরপর app বন্ধ করে নতুন করে run করবেন—শুধু hot reload যথেষ্ট নয়।

## আগে UI preview দেখুন

Doctor/manager-এর offline preview:

```bash
flutter run -t lib/main_dashboard_preview.dart
```

Admin-এর offline preview:

```bash
flutter run -t lib/main_dashboard_preview.dart --dart-define=DASHBOARD_PREVIEW_ROLE=admin
```

Department head, restricted HR অথবা Accounts দেখতে define-এর value যথাক্রমে
`unit`, `hr` অথবা `accounts` দিন। Preview-তে শুধুই synthetic data, memory storage ও
fake transport চলে; backend/Keychain ব্যবহার হয় না। Sample clock ও records স্থির,
তাই preview দিয়ে বাস্তব API count বা countdown acceptance করবেন না।

Live app-এ ফিরে নিজের account দিয়ে পরীক্ষা:

```bash
flutter run -t lib/main.dart
```

নতুন iOS simulator build যাচাই করতে:

```bash
flutter build ios --simulator --debug --no-codesign
```

## যে ফল দরকার

- `bash tool/verify.sh`-এর সম্পূর্ণ result। নতুন tests এই পরিবেশে চালানো হয়নি।
- একই role ও tab-এ native Android ও iPhone dashboard screenshot।
- Manager/head-এর buttons এবং Admin-এর permission-dependent bottom icons ঠিক আছে কি না।
- Today/Current Week/Current Month/Next Month বদলে API value যাচাই।
- Switch, refresh, logout No/Yes এবং API unavailable অবস্থায় Retry পরীক্ষা।

যাচাই শেষে header/identity/summary/menu UI অনুমোদন হলে পরের checkpoint হবে
Next Meeting countdown/progress এবং Admin OVERVIEW charts।
