# Login screen — 17 October 2026

Splash screen-এর চেহারা আপনি approve করেছেন। এই patch-এর লক্ষ্য শুধু native
`DocLogin` form এবং তার loading, validation, contact ও keyboard states মেলানো।
Centre/user selection dialog এবং dashboard-এর পরবর্তী UI কাজ এখানে করা হয়নি।

## Native source থেকে পরিবর্তন

- `activity_doc_login.xml`: header 35%, form-এর জন্য আলাদা 65% scroll area।
- মূল `docdiary_login_fron_view_new.png`-ই header background; stretch একইভাবে।
- Logo 140sdp box; ওপরের 8sdp এবং নিচের 60sdp margin ধরে আগের চেয়ে ওপরে।
- WELCOME 22sdp Poppins Bold, subtitle 12sdp Patua One; মূল margins।
- Mobile/Password: মূল 20dp outer margin, 50dp rounded background, Ubuntu Medium,
  13/15sdp vertical ও 20sdp horizontal padding।
- Remember Me: Open Sans, native checkbox colour; label tap-ও কাজ করে।
- LOGIN: `custom_button.xml`-এর বাঁয়ে `#50C2C0`, ডানে `#16A085`, 10dp corners।
- Account/contact লেখার মূল Poppins size, weight ও spacing।
- Login request চললে form লুকিয়ে সাদা background-এর মাঝখানে indicator;
  XML-এর প্রথম white layer তখনও থাকে।
- ফাঁকা form-এ validation message; server rejection-এ Warning dialog।
- Contact Here confirmation, মূল email subject/body এবং No/Yes choice।
- Keyboard এলে form-এর scroll area কমে; header তার জায়গায় থাকে। Done keyboard
  বন্ধ করে, LOGIN চাপলে request যায়। iPhone notch/home indicator-এর inset মানে।

Poppins, Patua One, Ubuntu এবং Open Sans-এর আসল font binaries ও upstream
licences দেওয়া হয়েছে। আগের project-এ Open Sans installer-এ ছিল না। Installer
আপনার `pubspec.yaml`-এ শুধু এই font families merge করে; unrelated settings ও
অন্য font families রাখে। এই patch দিতে font download প্রয়োজন নেই।

## আপনার চলমান project-এ প্রয়োগ

নতুন project বানাবেন না। আগের splash patch দেওয়া project-এই কাজ করুন।

1. `DocDiary_Login_Patch.zip` Downloads-এ extract করুন।
2. আপনার বর্তমান `docdiary_ios` project-এর terminal থেকে:

```bash
bash ~/Downloads/DocDiary_Login_Patch/apply_login_patch.sh
bash tool/verify.sh
flutter run -t lib/main_login_preview.dart
```

Patch folder অন্য জায়গায় হলে প্রথম command-এ সেই path দিন। Installer আগে
পরিবর্তিত files এবং পুরোনো `pubspec.yaml`-এর backup ZIP রাখে। এতে approved
splash file, `ios/`, Keychain, API controller/repositories বা dependency versions
replace করা হয় না। পুরো `lib/` বা `assets/` folder manual replace করবেন না।

Preview-তে API ও Keychain access নেই। Login form-এর screenshot/keyboard/toggle
দেখার জন্য এই entry point। এটি real account দিয়ে sign-in করার entry point নয়।
Contact confirmation-এর Yes email app খুলতে পারে, যেমন normal app-এ হয়।

## Live app পরীক্ষা

Preview-তে `q` দিয়ে বের হয়ে:

```bash
flutter run -t lib/main.dart
```

Saved session থাকলে normal app dashboard-এ যাবে; login দেখতে logout করুন।

- Android login এবং iPhone login-এর screenshot পাশাপাশি দেখুন। Logo size,
  header shape, welcome/form position, button ও footer মিলিয়ে নিন।
- Keyboard খুলে Mobile/Password এবং LOGIN button দেখা/scroll করা যায় কি না।
- Password show/hide; Remember Me label ও checkbox; remembered credentials।
- Empty form, wrong credentials, server error; loading চলাকালে duplicate request।
- Contact Here → No; প্রয়োজন হলে Yes দিয়ে email composer যাচাই।
- Live login → dashboard; logout → login; পরের cold launch-এ splash।

## যাচাইয়ের অবস্থা

আগের baseline-এ আপনার Mac-এ analyzer clean, 41 tests passed, simulator build
এবং API কাজ করার ফল পাওয়া গেছে; splash-এর UI-ও আপনি approve করেছেন।
এই নতুন login পরিবর্তনের Flutter tests, analyzer, iOS build এবং visual comparison
এখানে চালানো হয়নি—এই environment-এ Flutter/Dart/Xcode নেই। তিনটি login widget
test যোগ হয়েছে; আগের keyboard test আরও নির্দিষ্ট হয়েছে। মোট authored test 47।
Source/import/asset consistency, font files/licences, pubspec merge এবং patch
installer-এর পৃথক checks চালানো হয়েছে। Mac result ও screenshot দেখে এই
screen-এর visual acceptance শেষ করব।
