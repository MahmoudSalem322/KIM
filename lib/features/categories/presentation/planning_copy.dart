import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class PlanningCopy {
  PlanningCopy.of(BuildContext context)
    : ar = Localizations.localeOf(context).languageCode == 'ar';
  final bool ar;
  String call(String key) {
    final v = _copy[key];
    return v == null
        ? key
        : ar
        ? v.$1
        : v.$2;
  }

  String error(Object error) => call(
    error is WalletFailure
        ? error.code == 'category'
              ? 'categoryUnavailable'
              : error.code
        : 'error',
  );
}

const _copy = <String, (String, String)>{
  'categories': ('تصنيفات تعبّر عن حياتك', 'Categories that fit your life'),
  'categoriesSub': (
    'خصص تصنيفات الدخل والمصاريف مع الحفاظ على سجلك المالي.',
    'Personalize income and expense categories while keeping your financial history.',
  ),
  'manageCategories': ('إدارة التصنيفات', 'Manage categories'),
  'addCategory': ('إضافة تصنيف', 'Add category'),
  'editCategory': ('تعديل التصنيف', 'Edit category'),
  'name': ('الاسم', 'Name'),
  'color': ('اللون', 'Color'),
  'icon': ('الأيقونة', 'Icon'),
  'income': ('دخل', 'Income'),
  'expense': ('مصروف', 'Expense'),
  'save': ('حفظ', 'Save'),
  'cancel': ('إلغاء', 'Cancel'),
  'archive': ('أرشفة', 'Archive'),
  'restore': ('استعادة', 'Restore'),
  'delete': ('حذف', 'Delete'),
  'edit': ('تعديل', 'Edit'),
  'archived': ('مؤرشف', 'Archived'),
  'builtin': ('افتراضي', 'Built-in'),
  'custom': ('مخصص', 'Custom'),
  'historyNote': (
    'الأرشفة تمنع استخدام التصنيف في عمليات جديدة وتحافظ على سجله. حذف تصنيف مستخدم غير مسموح.',
    'Archiving stops new assignments and preserves history. Referenced categories cannot be deleted.',
  ),
  'deleteConfirm': (
    'حذف هذا العنصر نهائيًا؟ لا تتغير العمليات المالية.',
    'Delete this item permanently? Financial transactions stay unchanged.',
  ),
  'budgets': ('لكل هدف، خطة', 'Give every goal a plan'),
  'budgetsSub': (
    'ميزانيات حقيقية تتحدث مع كل حركة مالية.',
    'Real budgets that update with every transaction.',
  ),
  'addBudget': ('إنشاء ميزانية', 'Create budget'),
  'editBudget': ('تعديل الميزانية', 'Edit budget'),
  'empty': ('مساحة لخطتك القادمة', 'Make room for your next plan'),
  'emptyBody': (
    'حدد مبلغًا أسبوعيًا أو شهريًا، وسنتابع إنفاقك من العمليات المسجلة.',
    'Set a weekly or monthly limit and track spending from your recorded transactions.',
  ),
  'weekly': ('أسبوعية', 'Weekly'),
  'monthly': ('شهرية', 'Monthly'),
  'general': ('كل المصاريف', 'All expenses'),
  'category': ('التصنيف', 'Category'),
  'limit': ('المبلغ المخطط', 'Planned amount'),
  'spent': ('المصروف', 'Spent'),
  'remaining': ('المتبقي', 'Remaining'),
  'currency': ('العملة', 'Currency'),
  'scale': ('الدقة العشرية', 'Decimal places'),
  'cycle': ('الدورة', 'Cycle'),
  'firstPeriod': (
    'تاريخ ضمن أول فترة (YYYY-MM-DD)',
    'Date in first period (YYYY-MM-DD)',
  ),
  'periodHint': (
    'الأسابيع من الإثنين إلى الأحد. الأشهر تقويمية. يعود المبلغ المخطط لكل فترة دون ترحيل.',
    'Weeks run Monday–Sunday. Months follow the calendar. Limits renew each period without rollover.',
  ),
  'scopeNote': (
    'كل ميزانية بعملتها ودقتها. تُحسب المصاريف والرسوم فقط، بما فيها سجل المحافظ المؤرشفة. العامة وتصنيفاتها تتداخل؛ لا تُجمع أرقامها.',
    'Each budget uses its own currency and precision. Only expenses and fees count, including archived wallet history. General and category budgets overlap; their figures are not added together.',
  ),
  'alerts': ('حدود التنبيه', 'Alert thresholds'),
  'alert': ('تنبيه الميزانية', 'Budget alert'),
  'hidden': (
    'المبالغ والتنبيهات مخفية لخصوصية المحافظ',
    'Amounts and alerts hidden for wallet privacy',
  ),
  'notStarted': (
    'لم تبدأ هذه الميزانية بعد',
    'This budget has not started yet',
  ),
  'reference': ('تاريخ العرض', 'Viewing date'),
  'previous': ('الفترة السابقة', 'Previous period'),
  'next': ('الفترة التالية', 'Next period'),
  'chooseDate': ('اختيار التاريخ', 'Choose date'),
  'showArchived': ('إظهار المؤرشف', 'Show archived'),
  'editNote': (
    'تعديل التعريف يطبق على كل فتراته، وتُحسب المصروفات مجددًا من السجل الحالي.',
    'Definition changes apply to all its periods; spending is recalculated from current records.',
  ),
  'retry': ('إعادة المحاولة', 'Try again'),
  'error': (
    'تعذر تحميل البيانات أو حفظها. حاول مجددًا.',
    'Could not load or save data. Try again.',
  ),
  'invalidCategory': (
    'أدخل اسمًا صحيحًا واختر لونًا وأيقونة.',
    'Enter a valid name, color and icon.',
  ),
  'invalidBudget': (
    'تحقق من الاسم والمبلغ الموجب والتاريخ.',
    'Check the name, positive amount and date.',
  ),
  'duplicateCategory': (
    'يوجد تصنيف بهذا الاسم والنوع.',
    'A category already has this name and type.',
  ),
  'duplicateBudget': (
    'توجد ميزانية نشطة للدورة والعملة والتصنيف نفسها.',
    'An active budget already covers this cycle, currency and category.',
  ),
  'reservedCategory': (
    'هذا تصنيف افتراضي محفوظ للنظام.',
    'This built-in category is reserved.',
  ),
  'categoryInUse': (
    'التصنيف مرتبط بسجلات سابقة. يمكنك أرشفته بدلًا من حذفه.',
    'This category has referenced records. Archive it to preserve history.',
  ),

  'conflict': (
    'تغيرت البيانات. أغلق النموذج وافتحه مجددًا.',
    'Data changed. Close and reopen the form.',
  ),
  'icon-category': ('عام', 'General'),
  'icon-food': ('طعام', 'Food'),
  'icon-transport': ('مواصلات', 'Transport'),
  'icon-home': ('منزل', 'Home'),
  'icon-health': ('صحة', 'Health'),
  'icon-shopping': ('تسوق', 'Shopping'),
  'icon-salary': ('راتب', 'Salary'),
  'icon-gift': ('هدية', 'Gift'),
  'icon-work': ('عمل', 'Work'),
  'icon-bill': ('فواتير', 'Bills'),
  'icon-education': ('تعليم', 'Education'),
  'icon-travel': ('سفر', 'Travel'),
  'icon-coffee': ('قهوة', 'Coffee'),
  'icon-pet': ('حيوانات أليفة', 'Pets'),
  'icon-transfer': ('تحويل', 'Transfer'),
  'notFound': ('لم يعد العنصر موجودًا.', 'This item no longer exists.'),
  'categoryUnavailable': (
    'التصنيف غير متاح. أعد فتح النموذج واختر تصنيفًا نشطًا من النوع المناسب.',
    'Category unavailable. Reopen the form and choose an active category of the correct type.',
  ),
};
