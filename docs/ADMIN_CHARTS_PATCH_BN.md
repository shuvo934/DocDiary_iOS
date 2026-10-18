# Admin dashboard — OVERVIEW charts

আপনার দেওয়া দুইটি file-ই নতুন baseline। Common button elevation2, meeting
content-এর Center, full-top shadow এবং outer scroll padding রাখা হয়েছে।

## সর্বশেষ সংশোধন

- X-axis-এর date-এর পুরো ঘোরানো লেখাটি এখন অক্ষের 4px নিচ থেকে শুরু হয়।
- Summary ও chart payment total-এ আপনার `###,##,##,###` pattern: `628900` →
  `6,28,900`; `10000000` → `1,00,00,000`। Summary-এর decimal অংশ রাখা হয়।
- Native appointment total-এ comma নেই; tap marker-এর আলাদা তিন-digit grouping
  ও point-এর k/m/b/t abbreviation আগের মতো থাকে।
- আগের বড় font-এর legend wrapping fix-ও এই patch-এ আছে।

আগের patch apply করা থাকলেও এবার নতুন ZIP-এর installer চালান। এখন তিনটি
runtime Dart file ও সংশ্লিষ্ট monetary test বদলেছে; শুধু chart painter বদলালে
payment format ঠিক হবে না। পুরনো extracted patch folder-এর জায়গায় নতুনটি রাখুন।

## এই ধাপে

- Admin summary-এর নিচে Payment ও Appointment overview।
- Monthly / Yearly; permission থাকলে All / Offline / Online।
- দুই chart-এর month/year selection আলাদা। একটির date বদলালে অন্যটি থাকে।
- Mode/type বদলালে native-এর মতো দুটির date বর্তমান month/year-এ reset হয়।
- Native series colours, curved lines, circle points, value labels, legend ও marker।
- Graph-এ tap করলে value; দুই আঙুলে axis zoom এবং zoom-এর পরে drag।
- Native whole-number totals; error dialog ও পৃথক chart Retry।
- Summary-এর চারটি date tab বদলালে chart selection থাকে। App resume/full refresh-এ
  native-এর মতো Monthly + All দিয়ে নতুন data আসে; নতুন login POST হয় না।

## Apply

Downloads-এ ZIP extract করে বর্তমান `docdiary_ios` project-এর terminal-এ চালান:

```bash
python3 ~/Downloads/DocDiary_Admin_Charts_Patch/apply_admin_charts_patch.py .
flutter pub get
bash tool/verify.sh --ios-simulator
```

Installer backup-এর নাম দেখাবে। এটি বর্তমান dashboard ও test helper-এ integration
merge করে। নতুন dependency লাগে না। নতুন asset দেখার জন্য app নতুন করে run করুন।

## দ্রুত offline preview

```bash
flutter run -t lib/main_dashboard_preview.dart --dart-define=DASHBOARD_PREVIEW_ROLE=admin
```

নিচে scroll করে OVERVIEW দেখুন। এটি example data, backend ব্যবহার করে না। Live
API পরীক্ষার জন্য `flutter run -t lib/main.dart` চালিয়ে Admin account বেছে নিন।
Doctor account-এ Admin charts থাকবে না।

পরীক্ষা করুন: দুই chart-এর আলাদা date, mode/type reset, picker Cancel/OK,
payment scope, totals, point marker, zoom, network failure/Retry, summary tabs,
background/resume ও logout/switch। Android-এর সঙ্গে একই account/data/date নিয়ে
UI মিলিয়ে দেখুন। `is_pay_appoint_type_active=1` হলেই type selector দেখাবে।

Month picker-এ বর্তমান মাসসহ শেষ ১২ মাস; year picker-এ বর্তমান বছরসহ আগের ১০ বছর।
Chart total native-এর মতো whole number-এ round হয়; summary-এর আগের decimal display থাকে।

## Simulator-এ chart zoom

Chart-এর plot-এর মাঝখানে pointer রেখে Option (⌥) ধরে রাখুন। দুইটি touch circle
দেখাবে। Mouse button ধরে circles দূরে টানলে zoom in, কাছে আনলে zoom out।
ডানে-বামে gesture দিলে X-axis, উপরে-নিচে দিলে Y-axis scale হয়; native-এর মতো
একটি pinch-এ একটি axis scale হয়। প্রয়োজন হলে Option ধরে Shift-ও ধরে pointer
সরিয়ে pinch-এর center বসান, তারপর Shift ছেড়ে pinch করুন। দুই touch-ই একই
chart-এর plot-এর ভিতরে রাখুন। Original scale1-এর নিচে zoom out হয় না;
double-tap zoom native-এর মতো বন্ধ।

Apple instructions: https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwithiOSandwatchOS/InteractingwithiOSandwatchOS.html

প্রয়োজনে installer দেখানো backup-এর নাম দিয়ে ফেরত আনুন:

```bash
python3 ~/Downloads/DocDiary_Admin_Charts_Patch/restore_admin_charts_backup.py docdiary_before_admin_charts_YYYYMMDD_HHMMSS_xxxxxx.zip .
flutter pub get
```

## যাচাই

সর্বশেষ Mac result: analyzer পরিষ্কার; ১১৩টি test পাস এবং ছোট screen/বড় font-এর
একটি test-এ chart legend overflow হয়েছে। এই package-এ legend label-কে Flexible
দিয়ে wrap করার সংশোধন রয়েছে। তার সঙ্গে date anchor ও payment grouping-এর
সংশোধনও আছে। নতুন patch apply করে
`bash tool/verify.sh --ios-simulator` চালান। আগের failure-এর কারণে ওই
command-এ simulator build পর্যন্ত যায়নি। সংশোধিত test/build result এখনও বাকি।

এখানে source/import/assets, independent Dart grammar, native-source mapping ও
installer checks করা হয়েছে। Flutter/Dart SDK এবং Xcode নেই; নতুন Flutter tests,
analyzer ও iOS build এখানে চালানো হয়নি। সংশোধনের পর Mac-এর result এবং native-এর
সঙ্গে UI review বাকি। Pixel-perfect/error-free দাবি এখনও verified নয়।

পরবর্তী module: Doctor Appointment schedule/list ও তার navigation।
