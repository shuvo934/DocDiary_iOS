# Splash screen — 17 October 2026

এই পরিবর্তনটি শুধু `MainActivity`-এর Flutter splash এবং startup display নিয়ে।
এটি সম্পূর্ণ app conversion বা বাকি screen-এর UI approval নয়।

## কী মিলিয়েছি

- `activity_main.xml`-এর মূল PNG layer: `_2`, তারপর `_1`, তারপর মাঝখানে shadow logo।
- `design.xml`-এর নিচে `#16A085`, ওপরে `#50C2C0` gradient এবং 7dp content padding।
- Background-এ Android ImageView-এর default FIT_CENTER-এর সমতুল্য `BoxFit.contain`।
- Logo-এর দুই পাশে `_50sdp` margin-এর অনুপাতে sizing; full viewport-এ centering।
- Fullscreen splash, spinner বা বাড়তি caption নেই।
- প্রথম frame-এর পর অন্তত 1000ms splash; session restore শেষ হলে যথাযথ screen।

আগের API, Keychain ও account/session logic অপরিবর্তিত। Native-এর Google Play
update dialog iOS-এ ব্যবহার করা হয়নি। iOS-এর Flutter engine চালু হওয়ার আগের
LaunchScreen storyboard এই patch-এর অংশ নয়।

## আপনার বর্তমান Mac project-এ প্রয়োগ

নতুন Flutter project বানাবেন না। `bootstrap_ios.sh` আবার চালানোও প্রয়োজন নেই।

1. `DocDiary_Splash_Patch.zip` extract করুন।
2. আপনার কাজ করা `docdiary_ios` project-এর terminal খুলুন।
3. নিচের command-এ extracted patch folder-এর path দিন; Downloads-এ থাকলে:

```bash
bash ~/Downloads/DocDiary_Splash_Patch/apply_splash_patch.sh
bash tool/verify.sh
```

Installer নির্দিষ্ট files কপি করার আগে আগের files-এর backup ZIP রাখে।
`ios/`, `pubspec.yaml`, fonts, credentials ও আপনার generated project settings
বদলায় না। Manual copy চাইলে patch-এর `files/` থেকে একই relative path-এ শুধু
ওই files কপি করুন; পুরো `lib/` বা `assets/` folder replace করবেন না।

## Splash খোলা রেখে screenshot

```bash
flutter run -t lib/main_splash_preview.dart
```

এটি splash screen-এ থাকবে। API বা login শুরু করবে না। একই iPhone simulator
ব্যবহার করে screenshot তুলুন। পাশাপাশি native Android splash-এর screenshot
দিয়ে logo size, placement ও background মেলাতে হবে। ভিন্ন screen ratio-তে
ফাঁকা জায়গার অনুপাত কিছুটা আলাদা হতে পারে।

Preview বন্ধ করে স্বাভাবিক app:

```bash
flutter run -t lib/main.dart
```

Fresh launch-এ প্রায় ১ সেকেন্ডের splash-এর পরে login, অথবা saved session থাকলে
dashboard আসবে। Session restore ধীর হলে splash আরও বেশি সময় থাকবে। Hot reload
দিয়ে cold-start timing যাচাই করবেন না; app বন্ধ করে আবার চালান।

## যাচাইয়ের অবস্থা

আপনার আগের version-এ analyzer clean, 41 tests passed, simulator build এবং API
চলার ফল পাওয়া গেছে। নতুন splash-এর জন্য আরও 3টি routing/timing widget test
যোগ করা হয়েছে। এই environment-এ Flutter/Dart/Xcode নেই, তাই এই পরিবর্তনের
`flutter analyze`, Flutter tests, iOS build বা pixel comparison এখানে চালানো হয়নি।
Local source/import/asset consistency এবং patch installer আলাদাভাবে যাচাই করা হয়েছে।
Mac-এর নতুন ফল ও Android/iOS screenshot comparison-এর পরে এই screen approve করব।
