import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class TransactionCopy {
  TransactionCopy(this.ar);
  final bool ar;
  factory TransactionCopy.of(BuildContext context) =>
      TransactionCopy(Localizations.localeOf(context).languageCode == 'ar');
  String call(String key) {
    final value = _copy[key];
    return value == null
        ? key
        : ar
        ? value.$1
        : value.$2;
  }

  String error(Object error) =>
      call(error is WalletFailure ? 'error-${error.code}' : 'error');
}

const _copy = <String, (String, String)>{
  'error-reserved': (
    'هذه العملية ستصرف أموالًا محجوزة لأهداف ادخار. حرر التخصيص أولًا من أهداف الادخار.',
    'This would spend funds earmarked for savings goals. Release allocations from Savings goals first.',
  ),
  'title': ('سجل أموالك، بوضوح', 'A clear view of your money'),
  'subtitle': (
    'دخل ومصاريف فعلية، وأرصدة تتحدث مع كل عملية.',
    'Real income and expenses, reflected in your wallet balances.',
  ),
  'add': ('إضافة عملية', 'Add transaction'),
  'edit': ('تعديل العملية', 'Edit transaction'),
  'income': ('دخل', 'Income'),
  'expense': ('مصروف', 'Expense'),
  'wallet': ('المحفظة', 'Wallet'),
  'category': ('التصنيف', 'Category'),
  'amount': ('المبلغ', 'Amount'),
  'date': ('التاريخ', 'Date'),
  'notes': ('ملاحظات', 'Notes'),
  'save': ('حفظ العملية', 'Save transaction'),
  'saving': ('جارٍ الحفظ…', 'Saving…'),
  'cancel': ('إلغاء', 'Cancel'),
  'delete': ('حذف العملية', 'Delete transaction'),
  'deleteBody': (
    'سيُلغى أثر العملية على الرصيد مع الاحتفاظ بقيد عكسي موثّق.',
    'Reverse this transaction’s balance effect and retain its audit history.',
  ),
  'deleted': ('ملغاة', 'Cancelled'),
  'active': ('الفعلية', 'Active transactions'),
  'allStatus': ('كل الحالات', 'All statuses'),
  'search': (
    'ابحث في الملاحظات والتصنيف والمحفظة',
    'Search notes, category or wallet',
  ),
  'allTypes': ('كل الأنواع', 'All types'),
  'allWallets': ('كل المحافظ', 'All wallets'),
  'allCategories': ('كل التصنيفات', 'All categories'),
  'from': ('من تاريخ', 'From date'),
  'to': ('إلى تاريخ', 'To date'),
  'reset': ('مسح التصفية', 'Clear filters'),
  'empty': ('أول عملية، بداية الوضوح', 'Your first entry starts the picture'),
  'emptyBody': (
    'سجل دخلًا أو مصروفًا ليظهر هنا ويتحدث رصيد المحفظة.',
    'Record income or an expense to update your wallet and start its history.',
  ),
  'noResults': (
    'لا توجد عمليات تطابق التصفية',
    'No transactions match these filters',
  ),
  'needWallet': (
    'أنشئ محفظة نشطة أولًا لتسجيل العمليات.',
    'Create an active wallet before recording transactions.',
  ),
  'openWallets': ('عرض المحافظ', 'Open wallets'),
  'retry': ('إعادة المحاولة', 'Retry'),
  'hidden': ('المبلغ مخفي', 'Amount hidden'),
  'dateHelp': (
    'YYYY-MM-DD · يُحدّث الرصيد فورًا حتى للعمليات القديمة.',
    'YYYY-MM-DD · Balance updates immediately, including backdated entries.',
  ),
  'pickDate': ('اختيار التاريخ', 'Choose date'),
  'currencyHelp': (
    'أدخل مبلغًا موجبًا بعملة المحفظة. عند تغيير العملة أدخل المبلغ مجددًا.',
    'Enter a positive amount in the wallet currency. Re-enter it if the currency changes.',
  ),
  'editHelp': (
    'يحفظ التعديل الأثر السابق بقيد عكسي ثم يسجل القيمة الجديدة.',
    'Editing retains the prior effect as a reversal and records the replacement.',
  ),
  'history': ('آخر العمليات', 'Recent transactions'),
  'viewAll': ('كل العمليات', 'All transactions'),
  'transactionId': ('معرّف العملية المالية', 'Transaction ID'),
  'recorded': ('سُجّلت في', 'Recorded'),
  'incomeLedger': ('قيد دخل', 'Income entry'),
  'expenseLedger': ('قيد مصروف', 'Expense entry'),
  'reversalLedger': ('قيد عكسي', 'Reversal entry'),
  'editReversal': (
    'عكس أثر عملية قبل تعديلها',
    'Reversed before transaction edit',
  ),
  'cancelReversal': ('إلغاء أثر عملية مالية', 'Cancelled transaction effect'),
  'salary': ('راتب', 'Salary'),
  'freelance': ('عمل حر', 'Freelance'),
  'gift': ('هدية', 'Gift'),
  'otherIncome': ('دخل آخر', 'Other income'),
  'food': ('طعام', 'Food'),
  'transport': ('مواصلات', 'Transport'),
  'housing': ('سكن', 'Housing'),
  'bills': ('فواتير', 'Bills'),
  'health': ('صحة', 'Health'),
  'shopping': ('تسوق', 'Shopping'),
  'otherExpense': ('مصروف آخر', 'Other expense'),
  'transferFee': ('رسوم تحويل', 'Transfer fee'),
  'error-linkedTransfer': (
    'عدّل الرسوم من التحويل المرتبط.',
    'Edit fees through the linked transfer.',
  ),
  'error': (
    'تعذر الحفظ أو تحميل البيانات. حاول مجددًا.',
    'Unable to save or load data. Try again.',
  ),
  'error-amount': (
    'أدخل مبلغًا موجبًا ضمن دقة عملة المحفظة.',
    'Enter a positive exact amount within the wallet currency precision.',
  ),
  'error-category': (
    'اختر تصنيفًا مناسبًا لنوع العملية.',
    'Choose a category for this transaction type.',
  ),
  'error-date': (
    'أدخل تاريخًا صحيحًا بين 1900 و2100 بصيغة YYYY-MM-DD.',
    'Enter a valid date from 1900 to 2100 as YYYY-MM-DD.',
  ),
  'error-range': (
    'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
    'From date must be on or before to date.',
  ),
  'error-notes': (
    'الملاحظات لا تتجاوز 1000 حرف.',
    'Notes must be at most 1000 characters.',
  ),
  'error-conflict': (
    'تغيرت البيانات في تبويب آخر. أغلق النموذج وافتحه مجددًا.',
    'Data changed in another tab. Close and reopen the form.',
  ),
  'error-archived': (
    'استعد المحفظة المؤرشفة أولًا لتعديل العمليات.',
    'Restore the archived wallet before changing transactions.',
  ),
  'error-deleted': (
    'هذه العملية ملغاة بالفعل.',
    'This transaction is already cancelled.',
  ),
  'error-notFound': (
    'لم تعد المحفظة أو العملية متاحة.',
    'The wallet or transaction is no longer available.',
  ),
  'error-currency': (
    'عملة المبلغ لا تطابق المحفظة.',
    'Amount currency does not match the wallet.',
  ),
  'error-integrity': (
    'سجل المحفظة غير متسق. لم تُحفظ أي تغييرات.',
    'Wallet history is inconsistent. No changes were saved.',
  ),
};
