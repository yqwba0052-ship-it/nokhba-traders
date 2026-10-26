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

/// الأرباح مقابل الخسائر: مجموع ارتفاعات الأيام الرابحة ÷ مجموع هبوط الأيام
/// الخاسرة، من منحنى ROI اليومي في Binance خلال الفترة. 2 = الأرباح ضعف الخسائر.
const double MIN_GAIN_LOSS_RATIO = 2;

/// أكبر خسارة مسموحة في يوم واحد (% من الرصيد) خلال الفترة.
const double MAX_WORST_DAY_LOSS = 10;

/// استبعاد من تضع عليه Binance علامة "رافعة عالية" (HIGH_LEVERAGE).
const bool EXCLUDE_HIGH_LEVERAGE = true;

/// يجب أن يكون ناسخو المتداول رابحين خلال الفترة وأيضاً منذ بدايته (copierPnl > 0).
const bool REQUIRE_COPIERS_PROFIT = true;

/// كل متداول عمره أقل من هذا يُستبعد من كل الصفحات.
const int MIN_AGE_DAYS = 7;

/// الترتيب: score = roi / (mdd + SCORE_MDD_OFFSET).
const double SCORE_MDD_OFFSET = 5;

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
