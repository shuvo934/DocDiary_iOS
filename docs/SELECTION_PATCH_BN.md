# Multi-center এবং multi-user selection — 17 October 2026

আপনি splash এবং login screen-এর UI approve করেছেন। এই পরিবর্তন শুধু login-এর
পরের center/user selection dialog নিয়ে। আগের AuthController, API endpoints,
account ordering, role selection, Keychain এবং login/session logic ব্যবহার করে।

## যে native source মেলানো হয়েছে

- `SelectCenterDialogue.java`, `SelectUserIdDialogue.java`
- `center_selectable_view.xml`, `user_id_selectable_view.xml`
- `CenterAdapter.java`, `MultipleUserAdapter.java`
- `center_list_details_view.xml`, `user_list_details_view.xml`
- `border_design.xml`, `border_design_selected.xml`, মূল `hospital_icon.png`

| অংশ | Native অনুযায়ী Flutter |
| --- | --- |
| Header | `#50C2C0`, 16dp padding, original white hospital icon 24dp, Poppins Bold 18sp, white × 24dp |
| Title | Center list-এ SELECT CENTER; user list-এ নির্বাচিত center-এর নাম |
| Instruction | মূল পুরো message, Poppins Medium; চার পাশে 10dp |
| Center row | শুধু center-এর নাম; Open Sans Bold 13sdp, green sea |
| Doctor row | নাম 13sdp; department 10sdp; doctor code 11sdp |
| Admin row | First + last name; পরের লাইনে `(username)`; doctor code নেই |
| Row style | List margin 10dp + card margin 10dp; elevation 4dp, card radius 10dp |
| Border | Gray 2dp, radius 8sdp; drawable padding 7dp |
| Row padding | Center name margin 15dp; user details padding 10sdp |
| Selection | Card tap করলেই পরের ধাপ; login choices-এ আগাম tick নেই |
| Close | শুধু header-এর ×; বাইরের tap বা system back দিয়ে বন্ধ হয় না |

আগের Flutter selection-এর বাড়তি arrow, role icon, Cancel ও Back to centres
buttons সরানো হয়েছে। User order backend-এর order-এই থাকে। Doctor/admin
পরিচয় না বদলে সেই account-এর জন্য আগের role-specific login request যায়।

Login-এর সময় native loading screen-এর ওপর dialog আসে। Dashboard থেকে account
switch করলে একই row design-এ current center/account-এর tick এবং gray fill থাকে;
instruction তখন লুকানো হয়। Dashboard-এর backdrop-এর পূর্ণ parity dashboard
screen-এর কাজের সঙ্গে যাচাই করা হবে।

Dialog width-এর জন্য AppCompat-এর portrait/landscape fractions ও 1.7.1-এর API21+
16dp background insets ধরা হয়েছে। আসল hospital PNG byte-identical। Bundled
Open Sans variable font-এর 700 weight ব্যবহার করে native Open Sans Bold করা হয়েছে;
ফন্ট বা pubspec আবার বদলানোর প্রয়োজন নেই।

## বর্তমান project-এ প্রয়োগ

`DocDiary_Selection_Patch.zip` Downloads-এ extract করুন। আপনার কাজ করা
`docdiary_ios` project-এর terminal থেকে:

```bash
bash ~/Downloads/DocDiary_Selection_Patch/apply_selection_patch.sh
bash tool/verify.sh
flutter run -t lib/main_selection_preview.dart
```

Installer আগে backup ZIP রাখবে। Approved LoginScreen-এর code অক্ষত রেখে শুধু
পুরোনো selection class-কে নতুন dialog component-এর export দিয়ে সংযুক্ত করবে।
`native_login_layout.dart`, splash, fonts, pubspec, iOS settings এবং auth/API files
replace হবে না। Project-এ আগে login patch দেওয়া থাকতে হবে।

## Preview এবং real login

Preview-তে synthetic sample centers/accounts থাকে; কোনো network বা Keychain
access নেই। প্রথম center-এ tap করলে doctor/admin user cards দেখবেন। এখানে কোনো
account দিয়ে real sign-in হবে না; account tap করলে preview-only notice আসবে।
দুটি dialog-এর screenshot native Android-এর একই dialog-এর সঙ্গে মিলিয়ে নিন।

Live API দিয়ে পরীক্ষা করতে preview বন্ধ করে:

```bash
flutter run -t lib/main.dart
```

যাচাই করুন:

- Multi-center → center tap → সেই center-এর multi-user list → সঠিক account login।
- Single center + multi-user → সরাসরি user list।
- Direct single-account center → user dialog ছাড়াই login।
- দুই dialog-এর × → আগের mobile/password-সহ login; কোনো login POST হয় না।
- Long center names/list, doctor code/department, admin username এবং scrolling।

## যাচাইয়ের অবস্থা

ছয়টি widget test যোগ করা হয়েছে; মোট authored tests 53। Tests center→user→admin
login, direct account branch, outside/back/×, cancelled login data, long list এবং
current-account markers cover করে। এই environment-এ Flutter/Dart/Xcode নেই এবং
SDK download-ও পাওয়া যায়নি, তাই নতুন analyzer/tests/build বা rendered screenshot
comparison এখানে চালানো হয়নি। Mac-এর নতুন ফল ও screenshot ছাড়া pixel-perfect
বা সব test passed দাবি করা হচ্ছে না।
