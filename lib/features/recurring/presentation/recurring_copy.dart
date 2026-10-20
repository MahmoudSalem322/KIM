import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class RecurringCopy {
  RecurringCopy(this.ar);
  final bool ar;
  factory RecurringCopy.of(BuildContext context) =>
      RecurringCopy(Localizations.localeOf(context).languageCode == 'ar');
  String call(String key) {
    final v = _copy[key];
    return v == null
        ? key
        : ar
        ? v.$1
        : v.$2;
  }

  String error(Object e) =>
      call(e is WalletFailure ? 'error-${e.code}' : 'error');
}

const _copy = <String, (String, String)>{
  'reminderOnly': (
    'تذكير فقط؛ التسجيل النقدي يدوي',
    'Reminders only; cash recording is manual',
  ),
  'navigation': ('الاشتراكات والمدفوعات', 'Recurring payments'),
  'title': ('التزاماتك، بخطوة مسبقة', 'Stay a step ahead of your payments'),
  'subtitle': (
    'اشتراكات ومواعيد واضحة، وسجل مالي لا يكرر الدفعة.',
    'Clear subscriptions and due dates, with each occurrence recorded once.',
  ),
  'add': ('إضافة اشتراك', 'Add subscription'),
  'edit': ('تعديل الاشتراك', 'Edit subscription'),
  'save': ('حفظ الاشتراك', 'Save subscription'),
  'name': ('الاسم', 'Name'),
  'amount': ('المبلغ', 'Amount'),
  'wallet': ('المحفظة', 'Wallet'),
  'category': ('تصنيف المصروف', 'Expense category'),
  'cycle': ('دورة التكرار', 'Repeat cycle'),
  'next': ('الدفع القادم (YYYY-MM-DD)', 'Next payment (YYYY-MM-DD)'),
  'daily': ('يومي', 'Daily'),
  'weekly': ('أسبوعي', 'Weekly'),
  'monthly': ('شهري', 'Monthly'),
  'yearly': ('سنوي', 'Yearly'),
  'active': ('نشط', 'Active'),
  'paused': ('متوقف مؤقتًا', 'Paused'),
  'cancelled': ('ملغى', 'Cancelled'),
  'finished': ('انتهت المواعيد', 'Finished'),
  'all': ('الكل', 'All'),
  'status': ('الحالة', 'Status'),
  'pause': ('إيقاف مؤقت', 'Pause'),
  'resume': ('استئناف', 'Resume'),
  'cancelPlan': ('إلغاء الاشتراك', 'Cancel subscription'),
  'cancelHint': (
    'إلغاء نهائي للمواعيد المستقبلية؛ تبقى المصروفات السابقة محفوظة ولا تُعكس تلقائيًا.',
    'Permanently cancel future occurrences. Previous expenses are kept and are not reversed automatically.',
  ),
  'resumeHint': (
    'يبقى الموعد السابق محفوظًا. إذا فعلت التسجيل التلقائي، ستُعالج كل المواعيد المتأخرة عند المعالجة التالية.',
    'The old due date is retained. If automatic recording is enabled, missed dates will be caught up on the next processing run.',
  ),
  'automatic': (
    'تسجيل المصروفات المستحقة تلقائيًا',
    'Automatically record due expenses',
  ),
  'autoHint': (
    'عند التفعيل، يُخصم كل استحقاق كمصروف فعلي عند فتح التطبيق أو العودة إليه، وأثناء بقائه مفتوحًا. إيقاف الخيار يجعل الاشتراك للتذكير فقط؛ يمكنك تسجيل الاستحقاق يدويًا.',
    'When enabled, each due occurrence becomes a real expense when you open or resume the app, and while it remains open. Turn it off for reminders only; you can record a due occurrence manually.',
  ),
  'webHint': (
    'لا يُضمن تنفيذ مهام خلفية عند إغلاق المتصفح. عند الفتح تُعالج المواعيد الفائتة بالترتيب. التنبيه المحلي تذكير فقط ولا يحرك الأموال أثناء إغلاق التطبيق.',
    'Background tasks are not guaranteed when the browser is closed. Missed dates are processed in order on opening. Local notifications only remind you; they never move money while the app is closed.',
  ),
  'editHint': (
    'التعديل يطبق على المستقبل فقط. تغيير الموعد يتجاوز المواعيد غير المسجلة قبله. تعديل أو إلغاء مصروف سابق لا يعيد تسجيل نفس الاستحقاق.',
    'Edits affect future occurrences only. Changing the next date skips earlier unrecorded dates. Editing or deleting a recorded expense never replays its occurrence.',
  ),
  'process': ('معالجة المستحقات', 'Process due payments'),
  'processing': ('جارٍ المعالجة…', 'Processing…'),
  'processed': ('دفعات مسجلة', 'payments recorded'),
  'blockedCount': ('اشتراكات متوقفة بسبب خطأ', 'blocked subscriptions'),
  'more': (
    'بقيت دفعات قديمة؛ تابع المعالجة',
    'Older dates remain; continue processing',
  ),
  'pay': ('تسجيل الاستحقاق الآن', 'Record due payment'),
  'payHint': (
    'سيُسجل الموعد القادم فقط كمصروف فعلي من المحفظة. راجع المبلغ والموعد قبل المتابعة.',
    'Record only the next due date as a real expense from this wallet. Review the amount and date before continuing.',
  ),
  'calendar': ('تقويم المدفوعات', 'Payment calendar'),
  'calendarHint': (
    'المواعيد المتوقعة للاشتراكات النشطة؛ ليست عمليات مالية مسجلة. اختر يومًا لعرض اشتراكاته.',
    'Forecast dates for active subscriptions; these are not recorded transactions. Select a day to see its subscriptions.',
  ),
  'previous': ('الشهر السابق', 'Previous month'),
  'nextMonth': ('الشهر التالي', 'Next month'),
  'clearDate': ('كل الاشتراكات', 'All subscriptions'),
  'empty': ('مساحة لأول اشتراك', 'A space for your first subscription'),
  'emptyBody': (
    'سجل التزاماتك الدورية، وقرر إن كنت تريد التذكير أم تسجيل المصروف تلقائيًا.',
    'Add regular commitments and choose reminders or automatic expense recording.',
  ),
  'hidden': (
    'تفاصيل الدفع مخفية لخصوصية المحفظة',
    'Payment details hidden for wallet privacy',
  ),
  'noWallet': (
    'أضف أو أظهر محفظة نشطة أولًا.',
    'Add or show an active wallet first.',
  ),
  'history': ('الاستحقاقات المسجلة', 'Recorded occurrences'),
  'historyEmpty': (
    'لا توجد استحقاقات مسجلة بعد',
    'No recorded occurrences yet',
  ),
  'viewExpense': ('عرض العمليات', 'View transactions'),
  'lastPaid': ('آخر استحقاق مسجل', 'Last recorded date'),
  'cancel': ('إلغاء', 'Cancel'),
  'retry': ('إعادة المحاولة', 'Retry'),
  'error': (
    'تعذر تحميل أو حفظ البيانات. أعد المحاولة.',
    'Could not load or save data. Please retry.',
  ),
  'error-invalidRecurring': (
    'راجع الاسم والمبلغ الموجب والمحفظة والتصنيف والموعد.',
    'Check the name, positive amount, wallet, category and date.',
  ),
  'error-conflict': (
    'تغيرت البيانات. أغلق النموذج وأعد فتحه.',
    'Data changed. Close this form and reopen it.',
  ),
  'error-insufficient': (
    'الرصيد غير كافٍ؛ الموعد لم يتجاوز ولم تُسجل دفعة.',
    'Insufficient balance; the date was not skipped and no payment was recorded.',
  ),
  'error-reserved': (
    'أموال المحفظة محجوزة للادخار؛ حرر التخصيص أولًا.',
    'Wallet funds are earmarked for savings. Release allocations first.',
  ),
  'error-archived': (
    'المحفظة مؤرشفة؛ استعدها أو عدل الاشتراك.',
    'Wallet is archived. Restore it or edit the subscription.',
  ),
  'error-category': (
    'التصنيف غير متاح؛ اختر تصنيف مصروف نشطًا.',
    'Category is unavailable. Choose an active expense category.',
  ),
  'error-currency': (
    'عملة المبلغ ودقته لا تطابقان المحفظة.',
    'Amount currency and precision must match the wallet.',
  ),
  'error-cancelled': (
    'لا يمكن تغيير اشتراك ملغى أو منتهٍ.',
    'A cancelled or finished subscription cannot be changed.',
  ),
  'error-alreadyProcessed': (
    'الموعد سُجل مسبقًا. اختر موعدًا بعد آخر استحقاق مسجل.',
    'This date was already processed. Choose a date after the last recorded occurrence.',
  ),
  'error-notDue': (
    'الاشتراك متوقف أو الموعد لم يستحق بعد.',
    'Subscription is paused or the payment is not due yet.',
  ),
  'error-notFound': ('لم يُعثر على السجل.', 'Record not found.'),
  'notifications': ('مركز الإشعارات', 'Notification center'),
  'notificationsSub': (
    'تنبيهات حية من الاشتراكات والميزانيات والديون، محفوظة محليًا.',
    'Current subscription, budget and debt alerts with local read state.',
  ),
  'enableLocal': ('تفعيل الإشعارات المحلية', 'Enable local notifications'),
  'disableLocal': ('إيقاف الإشعارات المحلية', 'Disable local notifications'),
  'localHint': (
    'تحتاج إذن المنصة. إشعارات الجهاز عامة دون أسماء أو مبالغ. أندرويد يجدول تذكيرات قادمة، بما فيها الموعد التالي البعيد، ويجددها عند الفتح؛ الويب ينبه أثناء فتحه فقط. قد تؤخر المنصة الإشعارات أو تمنعها.',
    'Platform permission is required. Device notifications contain no names or amounts. Android schedules upcoming reminders, including the next distant date, and refreshes them on opening; web notifications run only while open. The platform may delay or suppress notifications.',
  ),
  'unavailable': (
    'الإشعارات المحلية غير متاحة هنا؛ المركز الداخلي يعمل.',
    'Local notifications are unavailable here; the internal center still works.',
  ),
  'permissionDenied': (
    'لم يُمنح إذن الإشعارات. يمكن تغييره من إعدادات المتصفح أو الجهاز.',
    'Notification permission was not granted. You can change it in browser or device settings.',
  ),
  'localFailure': (
    'تعذر تفعيل الإشعارات المحلية؛ المركز الداخلي يظل متاحًا.',
    'Could not enable local notifications; the internal center remains available.',
  ),
  'read': ('تعليم كمقروء', 'Mark read'),
  'unread': ('تعليم كغير مقروء', 'Mark unread'),
  'dismiss': ('إخفاء التنبيه', 'Dismiss alert'),
  'showDismissed': ('عرض المخفية', 'Show dismissed'),
  'restore': ('استعادة التنبيه', 'Restore alert'),
  'unreadOnly': ('غير المقروء فقط', 'Unread only'),
  'emptyNotices': ('كل شيء تحت المتابعة', 'You’re all caught up'),
  'open': ('فتح التفاصيل', 'Open details'),
  'subscription': (
    'اشتراك يستحق قريبًا أو متأخر',
    'Subscription due soon or overdue',
  ),
  'blocked': ('تعذرت معالجة اشتراك', 'Subscription processing blocked'),
  'recorded': ('تم تسجيل مصروف الاشتراك', 'Subscription expense recorded'),
  'reversed': (
    'مصروف الاستحقاق ملغى؛ لن يعاد تسجيله',
    'Occurrence expense deleted; it will not replay',
  ),
  'budget': ('تنبيه ميزانية', 'Budget threshold reached'),
  'debt': ('استحقاق دين قريب أو متأخر', 'Debt due soon or overdue'),
};
