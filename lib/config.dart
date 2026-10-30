// الشروط والثوابت كلها هنا. عدّل الرقم ثم أعد بناء التطبيق.
// ignore_for_file: constant_identifier_names

/// أقصى تراجع مسموح (%).
const double MAX_MDD = 20;

/// أقل نسبة فوز (%). Binance ترسلها نسبة مئوية جاهزة (مثل 73.33).
const double MIN_WIN_RATE = 50;

/// أقل متوسط صفقات يومية (صفحة "متداولين اليوم").
const double MIN_TRADES_PER_DAY = 3;

/// أقل أموال مُدارة (USDT).
const double MIN_AUM = 10000;

/// أقل عدد صفقات خلال الفترة.
const int MIN_TOTAL_TRADES = 10;

/// معامل الربحية: مجموع أرباح الصفقات المغلقة ÷ (مجموع خسائرها + الخسائر
/// العائمة للصفقات المفتوحة)، من صفقات المتداول الفعلية خلال الفترة.
const double MIN_PROFIT_FACTOR = 2.5;

/// سجل الصفقات العام يُعتمد فقط إذا طابق عدد صفقاته وعدد الرابحة منها أرقام
/// Binance الرسمية (totalOrder / winOrders) بين 90% و110%.
const double MIN_HISTORY_COVERAGE = 0.9;
const double MAX_HISTORY_COVERAGE = 1.1;

/// أكبر خسارة عائمة مسموحة الآن (% من رصيد المتداول).
const double MAX_FLOATING_LOSS_PCT = 10;

/// أكبر نسبة من الأرباح تأتي من أفضل 3 صفقات (%): أكثر من هذا = أرباح استثنائية.
const double MAX_TOP3_PROFIT_SHARE = 50;

/// يجب أن يكون المتداول رابحاً في آخر 30 يوماً وفي آخر 90 يوماً معاً.
const bool REQUIRE_PROFIT_30D_AND_90D = true;

/// أكبر خسارة مسموحة في يوم واحد (% من الرصيد) خلال الفترة.
const double MAX_WORST_DAY_LOSS = 10;

/// استبعاد من تضع عليه Binance علامة "رافعة عالية" وحدها: معطّل، فالمخاطرة
/// تُقاس بالتراجع والخسائر العائمة ومعامل الربحية، لا بالرافعة وحدها.
const bool EXCLUDE_HIGH_LEVERAGE = false;

/// أكبر عدد متداولين في كل قسم.
const int MAX_TRADERS_PER_SECTION = 30;

/// مبلغ النسخ الافتراضي (USDT)؛ يمكن تغييره من صفحة التفاصيل.
const double DEFAULT_COPY_AMOUNT = 100;

/// أصغر قيمة أمر تقبلها Binance في أغلب عقود USDT-M (USDT). تُستعمل لتقدير
/// نسبة الصفقات التي يمكن نسخها بمبلغك؛ بعض العقود حدّها أعلى.
const double BINANCE_MIN_ORDER_NOTIONAL = 5;

/// يجب أن يكون ناسخو المتداول رابحين خلال الفترة وأيضاً منذ بدايته (copierPnl > 0).
const bool REQUIRE_COPIERS_PROFIT = true;

/// كل متداول عمره أقل من هذا يُستبعد من كل الصفحات.
const int MIN_AGE_DAYS = 7;

/// الترتيب حسب كفاءة الأرباح مقابل الخسائر والمخاطر:
/// score = min(معامل الربحية, SCORE_MAX_PROFIT_FACTOR)
///         × (0.5 + 0.5 × نسبة أيام التداول)
///         ÷ (1 + (أقصى تراجع % + الخسارة العائمة %) ÷ 10)
const double SCORE_MAX_PROFIT_FACTOR = 10;

/// فترات صفحة "المحترفون" (الأزرار) والفترة الافتراضية.
const List<String> PROS_TIME_RANGES = ['7D', '30D', '90D'];
const String PROS_DEFAULT_TIME_RANGE = '30D';

/// صفحة "متداولين اليوم": متوسط الصفقات خلال آخر 30 يوماً.
const String TODAY_TIME_RANGE = '30D';

/// صفحة "متداولين السنة": أطول فترة تدعمها Binance (365D مدعومة، فُحصت فعلاً).
const String YEAR_TIME_RANGE = '365D';

/// كم صفحة تُجمع من كل ترتيب (ROI ثم PNL). كل صفحة = طلب واحد.
const int LIST_PAGES_PER_SORT = 10;

/// أكبر حجم صفحة تقبله Binance (فُحص: 30).
const int LIST_PAGE_SIZE = 30;

/// عدد المتداولين الذين تُجلب بياناتهم الإضافية في كل دفعة.
const int PERFORMANCE_BATCH_SIZE = 5;

/// استراحة بين الطلبات حتى لا يحجبنا الخادم.
const Duration REQUEST_PAUSE = Duration(milliseconds: 500);

/// سجل الصفقات المغلقة: حجم الصفحة (أقصى ما تقبله Binance فعلياً 200)، وأكبر
/// عدد صفحات، وكم يوماً قبل بداية الفترة نرجع لنلتقط صفقات فُتحت قبلها وأُغلقت فيها.
const int HISTORY_PAGE_SIZE = 200;
const int HISTORY_MAX_PAGES = 15;
const Duration HISTORY_LOOKBACK = Duration(days: 30);

/// مدة صلاحية الأرقام الرسمية المحفوظة؛ بعدها يجلبها التحديث من جديد.
const Duration CACHE_TTL = Duration(minutes: 5);

/// مهلة كل طلب.
const Duration REQUEST_TIMEOUT = Duration(seconds: 20);

/// عدد الصفوف في كل صفحة من صفحتي الزجاج.
const int ROWS_PER_GLASS_PAGE = 9;

/// تصنيف المخاطرة حسب أقصى تراجع (%): حتى LOW منخفضة، حتى MEDIUM متوسطة، وأكثر مرتفعة.
const double RISK_LOW_MAX_MDD = 10;
const double RISK_MEDIUM_MAX_MDD = 20;

/// رابط صفحة المتداول الحقيقية.
const String BINANCE_TRADER_URL =
    'https://www.binance.com/en/copy-trading/lead-details/';

const String BINANCE_API =
    'https://www.binance.com/bapi/futures/v1/friendly/future/copy-trade';
const String BINANCE_PUBLIC_API =
    'https://www.binance.com/bapi/futures/v1/public/future/copy-trade';
