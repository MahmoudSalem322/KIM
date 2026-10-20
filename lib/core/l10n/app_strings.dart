import 'package:flutter/widgets.dart';

/// All product copy is kept here; features never branch on locale directly.
final class AppStrings {
  const AppStrings(this.languageCode);
  final String languageCode;
  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context).languageCode);
  String call(String key) {
    final value = _copy[key] ?? (key, key);
    return languageCode == 'ar' ? value.$1 : value.$2;
  }
}

const _copy = <String, (String, String)>{
  'dashboard': ('نظرة عامة', 'Overview'),
  'wallets': ('المحافظ', 'Wallets'),
  'transactions': ('العمليات', 'Transactions'),
  'budgets': ('الميزانيات', 'Budgets'),
  'reports': ('التقارير', 'Reports'),
  'settings': ('الإعدادات', 'Settings'),
  'workspace': ('مساحتك المالية', 'PERSONAL WORKSPACE'),
  'tagline': ('وضوح أكثر. راحة أكبر.', 'More clarity. More calm.'),
  'local': ('محفوظ على هذا الجهاز', 'Stored on this device'),
  'offline': ('جاهز للعمل دون إنترنت', 'Offline ready'),
  'private': ('مساحتك، وبياناتك', 'Your space. Your data.'),
  'welcome': ('بداية جديدة لأموالك', 'A fresh start for your money'),
  'welcomeSub': (
    'كل ما تحتاجه لفهم أموالك، في مساحة واحدة هادئة.',
    'Everything you need to understand your finances, in one calm space.',
  ),
  'heroTitle': (
    'مساحة صغيرة.\nخطط كبيرة.',
    'A little space.\nFor bigger plans.',
  ),
  'heroBody': (
    'هنا تبدأ رحلتك نحو صورة أوضح لأموالك. محافظك وعملياتك وأهدافك، مرتبة في مكان واحد.',
    'Make room for a clearer financial life. Your wallets, activity and goals — thoughtfully organized in one place.',
  ),
  'explore': ('استكشف المحافظ', 'Explore wallets'),
  'emptyWallet': ('بانتظار أول محفظة', 'Waiting for your first wallet'),
  'noBalances': ('لا توجد أرصدة لعرضها بعد', 'No balances to display yet'),
  'activity': ('النشاط الأخير', 'Recent activity'),
  'noActivity': ('صفحة جديدة، وبداية هادئة', 'A clean slate, a calmer start'),
  'noActivitySub': (
    'ستظهر حركات أموالك هنا عند توفر العمليات.',
    'Your money movements will appear here when transactions are available.',
  ),
  'essentials': ('مصمم لراحة بالك', 'Built for peace of mind'),
  'precision': ('دقة من البداية', 'Precision from day one'),
  'precisionSub': (
    'أساس مالي يحافظ على كل وحدة من أموالك.',
    'An exact foundation that respects every minor unit.',
  ),
  'deviceSub': (
    'تُحفظ بياناتك محليًا في متصفحك دون حساب أو خادم.',
    'Your data stays in your browser. No account or server required.',
  ),
  'walletsTitle': ('محافظك، في مكان واحد', 'Your wallets, in one place'),
  'walletsBody': (
    'لا توجد محافظ بعد. ستتوفر إدارة المحافظ في مرحلة قادمة.',
    'No wallets yet. Wallet management will be available in a future phase.',
  ),
  'transactionsTitle': (
    'صورة واضحة لحركة أموالك',
    'A clear view of your money',
  ),
  'transactionsBody': (
    'لا توجد عمليات بعد. ستتوفر إدارة الدخل والمصاريف في مرحلة قادمة.',
    'No transactions yet. Income and expense management will be available in a future phase.',
  ),
  'budgetsTitle': ('لكل هدف، خطة', 'Give every goal a plan'),
  'budgetsBody': (
    'لا توجد ميزانيات بعد. ستتوفر أدوات التخطيط في مرحلة قادمة.',
    'No budgets yet. Planning tools will be available in a future phase.',
  ),
  'reportsTitle': ('شاهد الصورة الأكبر', 'See the bigger picture'),
  'reportsBody': (
    'لا توجد بيانات للتقارير بعد. ستتوفر التقارير بعد تنفيذ العمليات المالية.',
    'No report data yet. Insights will become available after financial transactions are implemented.',
  ),
  'foundation': (
    'المرحلة الأولى · تأسيس المساحة',
    'PHASE 01 · WORKSPACE FOUNDATION',
  ),
  'settingsSub': (
    'مساحة تناسبك، باللغة والمظهر الذي تفضله.',
    'Make this space yours, in the language and style you prefer.',
  ),
  'appearance': ('المظهر', 'Appearance'),
  'appearanceSub': (
    'اختر الإضاءة المناسبة لمساحتك.',
    'Choose the right light for your workspace.',
  ),
  'system': ('حسب الجهاز', 'System'),
  'light': ('فاتح', 'Light'),
  'dark': ('داكن', 'Dark'),
  'language': ('اللغة', 'Language'),
  'languageSub': (
    'يتغير اتجاه الواجهة تلقائيًا مع اللغة.',
    'The layout direction follows your language automatically.',
  ),
  'storage': ('البيانات والخصوصية', 'Data & privacy'),
  'storageBody': (
    'تُحفظ الإعدادات تلقائيًا في هذا المتصفح. لا تحتاج إلى تسجيل دخول.',
    'Preferences are saved automatically in this browser. No sign-in needed.',
  ),
  'learnMore': ('تفاصيل التخزين', 'About local storage'),
  'storageDetails': (
    'البيانات مرتبطة بعنوان الموقع والمتصفح. مسح بيانات الموقع يحذفها، والتصفح الخاص قد لا يحتفظ بها. العمل دون إنترنت يتاح بعد تحميل نسخة الويب كاملة على localhost أو HTTPS.',
    'Data belongs to this site origin and browser. Clearing site data removes it; private browsing may not retain it. Offline use is available after the complete web build has been cached on localhost or HTTPS.',
  ),
  'close': ('إغلاق', 'Close'),
  'saving': ('جارٍ الحفظ…', 'Saving…'),
  'saved': ('تُحفظ التفضيلات تلقائيًا', 'Preferences save automatically'),
  'saveError': (
    'تعذر حفظ التغيير. تحقق من مساحة المتصفح وأعد المحاولة.',
    'Could not save this change. Check browser storage and try again.',
  ),
  'startupError': ('تعذر فتح التخزين المحلي', 'Could not open local storage'),
  'startupBody': (
    'اسمح للموقع باستخدام تخزين المتصفح ثم أعد المحاولة. لن نستخدم تخزينًا مؤقتًا بدلًا من بياناتك.',
    'Allow this site to use browser storage, then try again. Your data will not be replaced with temporary storage.',
  ),
  'retry': ('إعادة المحاولة', 'Try again'),
  'notFound': ('هذه الصفحة غير موجودة', 'This page does not exist'),
  'goHome': ('العودة إلى الرئيسية', 'Back to overview'),
  'menu': ('التنقل', 'Navigation'),
  'version': ('Kim · الإصدار 1.0.0', 'Kim · version 1.0.0'),
};
