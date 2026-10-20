import 'package:flutter/material.dart';

import '../domain/wallet.dart';

class WalletCopy {
  WalletCopy(this.ar);
  final bool ar;
  factory WalletCopy.of(BuildContext context) =>
      WalletCopy(Localizations.localeOf(context).languageCode == 'ar');
  String call(String key) {
    final text = _copy[key];
    return text == null
        ? key
        : ar
        ? text.$1
        : text.$2;
  }

  String error(Object error) =>
      call(error is WalletFailure ? 'error-${error.code}' : 'error');
}

const _copy = <String, (String, String)>{
  'error-reserved': (
    'توجد أموال محجوزة لأهداف ادخار. حرر التخصيص أولًا قبل تخفيض الرصيد أو أرشفة المحفظة.',
    'Funds are earmarked for savings goals. Release allocations before reducing the balance or archiving this wallet.',
  ),
  'title': ('محافظك، في مكان واحد', 'Your wallets, in one place'),
  'subtitle': (
    'مساحات مستقلة لأموالك، بكل عملاتها.',
    'Separate spaces for your money, in every currency.',
  ),
  'create': ('إنشاء محفظة', 'Create wallet'),
  'edit': ('تعديل المحفظة', 'Edit wallet'),
  'save': ('حفظ المحفظة', 'Save wallet'),
  'saving': ('جارٍ الحفظ…', 'Saving…'),
  'cancel': ('إلغاء', 'Cancel'),
  'close': ('إغلاق', 'Close'),
  'name': ('اسم المحفظة', 'Wallet name'),
  'type': ('نوع المحفظة', 'Wallet type'),
  'currency': ('العملة', 'Currency'),
  'opening': ('الرصيد الافتتاحي', 'Opening balance'),
  'openingHelp': (
    'يُسجل كقيد افتتاحي دائم. يمكن تصحيح الرصيد لاحقًا بتسوية موثقة.',
    'Recorded as a permanent opening entry. Correct later balances with a documented adjustment.',
  ),
  'immutable': (
    'العملة والقيد الافتتاحي ثابتان. استخدم التسوية لتصحيح الرصيد.',
    'Currency and opening entry are fixed. Use an adjustment to correct the balance.',
  ),
  'color': ('لون المحفظة', 'Wallet color'),
  'icon': ('أيقونة المحفظة', 'Wallet icon'),
  'active': ('النشطة', 'Active'),
  'archived': ('المؤرشفة', 'Archived'),
  'empty': ('مساحة لأوّل محفظة', 'A space for your first wallet'),
  'emptyBody': (
    'أضف محفظة نقدية أو حسابًا، وسجل رصيد البداية بدقة.',
    'Add cash or an account, and record its opening balance precisely.',
  ),
  'emptyArchive': ('لا توجد محافظ مؤرشفة', 'No archived wallets'),
  'details': ('تفاصيل المحفظة', 'Wallet details'),
  'back': ('كل المحافظ', 'All wallets'),
  'balance': ('الرصيد الحالي', 'Current balance'),
  'hide': ('إخفاء الرصيد', 'Hide balance'),
  'show': ('إظهار الرصيد', 'Show balance'),
  'hidden': ('الرصيد مخفي', 'Balance hidden'),
  'archive': ('أرشفة المحفظة', 'Archive wallet'),
  'restore': ('استعادة المحفظة', 'Restore wallet'),
  'archiveBody': (
    'تُحفظ المحفظة وسجلها المالي. يمكنك استعادتها في أي وقت.',
    'The wallet and its financial history are kept. You can restore it at any time.',
  ),
  'restoreBody': (
    'ستعود المحفظة إلى قائمة المحافظ النشطة.',
    'The wallet will return to the active list.',
  ),
  'readonly': (
    'هذه المحفظة مؤرشفة؛ سجلها المالي محفوظ. استعدها قبل التعديل أو التسوية.',
    'This wallet is archived; its history is retained. Restore it before editing or adjusting.',
  ),
  'moveUp': ('تحريك للأعلى', 'Move up'),
  'moveDown': ('تحريك للأسفل', 'Move down'),
  'adjust': ('تسوية الرصيد', 'Adjust balance'),
  'target': ('الرصيد الصحيح الآن', 'Correct current balance'),
  'reason': ('سبب التسوية', 'Adjustment reason'),
  'adjustSave': ('تسجيل التسوية', 'Record adjustment'),
  'adjustHelp': (
    'ستُضاف قيمة الفرق كقيد جديد، مع حفظ الرصيد السابق والسبب.',
    'The difference is added as a new entry, retaining the previous balance and reason.',
  ),
  'difference': ('فرق التسوية', 'Adjustment difference'),
  'history': ('السجل المالي', 'Financial history'),
  'adjustment': ('تسوية موثقة', 'Documented adjustment'),
  'before': ('قبل القيد', 'Before entry'),
  'after': ('بعد القيد', 'After entry'),
  'operation': ('معرّف العملية', 'Operation ID'),
  'created': ('أُنشئت في', 'Created on'),
  'totals': ('الأرصدة حسب العملة', 'Balances by currency'),
  'count': ('محافظ نشطة', 'active wallets'),
  'retry': ('إعادة المحاولة', 'Retry'),
  'privacyTotals': (
    'محجوب احترامًا لإخفاء الرصيد',
    'Withheld while a balance is hidden',
  ),
  'notFound': ('لم تُعثر على المحفظة', 'Wallet not found'),
  'custom': ('عملة مخصصة', 'Custom currency'),
  'code': ('رمز العملة (3 أحرف)', 'Currency code (3 letters)'),
  'scale': ('المنازل العشرية', 'Decimal places'),
  'nameInvalid': (
    'أدخل اسمًا من 1 إلى 80 حرفًا.',
    'Enter a name with 1 to 80 characters.',
  ),
  'moneyInvalid': (
    'أدخل مبلغًا صحيحًا بدقة العملة المختارة.',
    'Enter an exact amount within the selected currency precision.',
  ),
  'reasonInvalid': (
    'أدخل سببًا واضحًا من 1 إلى 500 حرف.',
    'Enter a clear reason with 1 to 500 characters.',
  ),
  'codeInvalid': (
    'استخدم ثلاثة أحرف إنجليزية للرمز.',
    'Use three English letters for the code.',
  ),
  'error': (
    'تعذر حفظ البيانات. أعد المحاولة؛ لن تُعرض العملية كمحفوظة قبل نجاحها.',
    'Could not save data. Retry; a write is only shown as saved after it succeeds.',
  ),
  'loadError': (
    'تعذر تحميل المحافظ. تحقق من إتاحة تخزين المتصفح وأعد المحاولة.',
    'Could not load wallets. Check browser storage and retry.',
  ),
  'error-conflict': (
    'تغيرت المحفظة في تبويب آخر. أغلق النموذج وأعد فتحه من البيانات المحدثة.',
    'The wallet changed in another tab. Close this form and reopen it with the latest data.',
  ),
  'error-invalid': ('راجع بيانات المحفظة.', 'Check the wallet details.'),
  'error-currency': (
    'لا يمكن تغيير عملة الرصيد المسجل.',
    'The recorded balance currency cannot change.',
  ),
  'error-reason': (
    'اكتب سببًا واضحًا للتسوية.',
    'Enter a clear adjustment reason.',
  ),
  'error-noChange': (
    'الرصيد الجديد يطابق الرصيد الحالي؛ لا حاجة لتسوية.',
    'The new balance equals the current balance; no adjustment is needed.',
  ),
  'error-archived': (
    'استعد المحفظة المؤرشفة قبل تعديلها.',
    'Restore the archived wallet before editing.',
  ),
  'error-notFound': ('لم تُعثر على المحفظة.', 'Wallet not found.'),
  'cash': ('نقدية', 'Cash'),
  'bank': ('حساب بنكي', 'Bank account'),
  'credit': ('بطاقة ائتمان', 'Credit card'),
  'savings': ('ادخار', 'Savings'),
  'digital': ('رقمية', 'Digital'),
  'other': ('أخرى', 'Other'),
  'wallet': ('محفظة', 'Wallet'),
  'card': ('بطاقة', 'Card'),
  'emerald': ('زمردي', 'Emerald'),
  'navy': ('كحلي', 'Navy'),
  'blue': ('أزرق', 'Blue'),
  'purple': ('بنفسجي', 'Purple'),
  'amber': ('كهرماني', 'Amber'),
  'rose': ('وردي', 'Rose'),
};
Color walletColor(String key) =>
    const <String, Color>{
      'emerald': Color(0xFF087F68),
      'navy': Color(0xFF122C36),
      'blue': Color(0xFF245CAC),
      'purple': Color(0xFF6451B0),
      'amber': Color(0xFFA96D10),
      'rose': Color(0xFFAD4667),
    }[key] ??
    const Color(0xFF087F68);
IconData walletIcon(String key) =>
    const <String, IconData>{
      'wallet': Icons.account_balance_wallet_outlined,
      'bank': Icons.account_balance_outlined,
      'cash': Icons.payments_outlined,
      'card': Icons.credit_card_outlined,
      'savings': Icons.savings_outlined,
      'digital': Icons.devices_outlined,
    }[key] ??
    Icons.account_balance_wallet_outlined;
String entryDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final l = MaterialLocalizations.of(context);
  return '${l.formatMediumDate(local)} · ${l.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
}
