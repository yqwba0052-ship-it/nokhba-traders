# نخبة المتداولين

تطبيق أندرويد (Flutter) يعرض متداولين حقيقيين من قسم نسخ التداول في Binance.
كل البيانات تأتي من Binance مباشرة عند فتح الصفحة أو تحديثها؛ لا توجد بيانات مخزّنة أو وهمية في التطبيق.

## مصادر البيانات (فُحصت فعلاً)
| الغرض | الرابط |
|---|---|
| قائمة المتداولين | `POST bapi/futures/v1/friendly/future/copy-trade/home-page/query-list` (أقصى `pageSize` = 30) |
| عدد الصفقات | `GET bapi/futures/v1/public/future/copy-trade/lead-portfolio/performance?portfolioId=<id>&timeRange=<7D..365D>` → `totalOrder`, `winOrders` |
| صفحة المتداول | `https://www.binance.com/en/copy-trading/lead-details/<id>` |
| أرقام المحفظة الرسمية (ROI، PNL، MDD، الفوز، Sharpe، ربح الناسخين) | نفس رابط `performance` لكل فترة (7D/30D/90D/365D) |
| الصفقات المغلقة (معامل الربحية) | `POST .../friendly/.../lead-portfolio/position-history` (200 في الصفحة؛ تُعتمد فقط إذا طابقت totalOrder وwinOrders بين 90% و110%) |
| الصفقات المفتوحة (الخسائر العائمة) | `GET .../friendly/.../lead-data/positions?portfolioId=<id>` (فارغ إذا أخفى المتداول صفقاته: يُستبعد) |
| الرصيد، الحد الأدنى للنسخ، ربح الناسخين منذ البداية | `GET .../friendly/.../lead-portfolio/detail?portfolioId=<id>` |
| منحنى ROI اليومي (أسوأ يوم) | `chartItems` في القائمة، أو `GET .../public/.../lead-portfolio/chart-data` |

غير متاح في Binance للعامة: نتيجة كل ناسخ على حدة (يُعرض المجموع فقط مع تنبيه).
نتائج «سجل اختباراتي» تُحفظ على الهاتف فقط، منفصلة عن أرقام Binance.

الفترات المدعومة: 7D و30D و90D و180D و365D. `winRate` و`mdd` و`roi` نسب مئوية جاهزة (73.33 تعني 73.33%).

## الشروط
كلها في [lib/config.dart](lib/config.dart). عدّل الرقم ثم أعد البناء.

## الأوامر
```
flutter analyze
flutter test
flutter build apk --release
dart run tool/print_top.dart      # يطبع أول 5 متداولين من كل صفحة (بيانات حية)
```
ملف الـ APK: `build\app\outputs\flutter-apk\app-release.apk`

## الأيقونة والصور
1. ضع صورتك في `design\icon.png` (وصور التصميم `design\daily.png` و`design\year.png` للمرجع).
2. `cvpy tool\make_icon.py` (يقصّ الصورة على المربع الزجاجي ويكتب `design\icon_square.png` و`design\icon_foreground.png`).
   إذا لم يكن القصّ مناسباً، فضع بنفسك صورة مربعة مقصوصة باسم `design\icon_square.png`.
3. `dart run flutter_launcher_icons`
4. `flutter build apk --release`

## الملفات
- `binance_samples\`: ردود Binance الخام من الفحص الأول وبرامج الفحص (للمرجع فقط).
- `test\fixtures\`: نسخة من بعض تلك الردود، تستعملها الاختبارات فقط ولا تدخل في التطبيق.
