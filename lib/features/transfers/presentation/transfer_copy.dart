import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class TransferCopy {
  TransferCopy(this.ar);
  final bool ar;
  factory TransferCopy.of(BuildContext context) =>
      TransferCopy(Localizations.localeOf(context).languageCode == 'ar');
  String call(String key) {
    final value = _copy[key];
    return value == null
        ? key
        : ar
        ? value.$1
        : value.$2;
  }

  String error(Object e) =>
      call(e is WalletFailure ? 'error-${e.code}' : 'error');
}

const _copy = <String, (String, String)>{
  'error-reserved': (
    'هذا التحويل أو تعديله يمس أموالًا محجوزة لأهداف ادخار. حرر التخصيص أولًا من أهداف الادخار.',
    'This transfer or change affects funds earmarked for savings goals. Release allocations from Savings goals first.',
  ),
  'title': ('بين محافظك، بكل وضوح', 'Move money with confidence'),
  'subtitle': (
    'تحويلات مترابطة، ورسوم منفصلة، وسعر صرف محفوظ.',
    'Linked transfers, separate fees and a saved exchange rate.',
  ),
  'navigation': ('التحويلات', 'Wallet transfers'),
  'add': ('تحويل جديد', 'New transfer'),
  'edit': ('تعديل التحويل', 'Edit transfer'),
  'source': ('من المحفظة', 'From wallet'),
  'destination': ('إلى المحفظة', 'To wallet'),
  'swap': ('تبديل المحفظتين', 'Swap wallets'),
  'amount': ('مبلغ التحويل', 'Transfer amount'),
  'fee': ('رسوم التحويل', 'Transfer fee'),
  'rate': ('سعر الصرف اليدوي', 'Manual exchange rate'),
  'received': ('المبلغ المستلم', 'Amount received'),
  'total': ('إجمالي الخصم', 'Total debit'),
  'notes': ('ملاحظات', 'Notes'),
  'save': ('حفظ التحويل', 'Save transfer'),
  'saving': ('جارٍ الحفظ…', 'Saving…'),
  'close': ('إغلاق', 'Close'),
  'cancel': ('إلغاء التحويل', 'Cancel transfer'),
  'cancelBody': (
    'سيُعكس الطرفان والرسوم مع الاحتفاظ بالسجل. يجب توفر المبلغ المستلم لعكس التحويل.',
    'Reverse both legs and fees while retaining history. Received funds must be available for reversal.',
  ),
  'cancelled': ('ملغى', 'Cancelled'),
  'active': ('فعّال', 'Active'),
  'all': ('كل التحويلات', 'All transfers'),
  'id': ('معرّف التحويل', 'Transfer ID'),
  'recorded': ('تاريخ التسجيل', 'Recorded'),
  'empty': ('أموالك تتحرك، وسجلها يبقى', 'Move your money. Keep its story.'),
  'emptyBody': (
    'انقل الأموال بين محافظك دون احتسابها دخلًا أو مصروفًا جديدًا.',
    'Transfer between your wallets without counting principal as new income or expense.',
  ),
  'needWallets': (
    'تحتاج إلى محفظتين نشطتين للتحويل.',
    'You need two active wallets to transfer.',
  ),
  'wallets': ('عرض المحافظ', 'Open wallets'),
  'hidden': ('المبلغ مخفي', 'Amount hidden'),
  'search': (
    'ابحث في المحافظ والملاحظات ومعرّف التحويل',
    'Search wallets, notes or transfer ID',
  ),
  'noResults': ('لا توجد تحويلات مطابقة', 'No matching transfers'),
  'retry': ('إعادة المحاولة', 'Retry'),
  'quoteHelp': (
    'سعر الصرف: كل وحدة من عملة المصدر تساوي السعر بعملة الاستلام. التقريب لأقرب وحدة صغيرة؛ النصف إلى الأعلى.',
    'Rate: one source currency unit buys this many destination units. Rounded to the nearest minor unit, half up.',
  ),
  'feeHelp': (
    'الرسوم بعملة المصدر، وتُسجّل وحدها كمصروف مرتبط.',
    'Fees use the source currency and are the only linked expense.',
  ),
  'editHelp': (
    'يحفظ التعديل قيودًا عكسية ثم يسجل التحويل البديل بالكامل.',
    'Editing retains reversal entries and records the entire replacement.',
  ),
  'out': ('تحويل صادر', 'Transfer sent'),
  'in': ('تحويل وارد', 'Transfer received'),
  'reverse': ('عكس تحويل', 'Transfer reversed'),
  'linked': ('مرتبط بتحويل', 'Linked to transfer'),
  'error': (
    'تعذر حفظ أو تحميل التحويل. حاول مجددًا.',
    'Unable to save or load transfer. Try again.',
  ),
  'error-wallets': ('اختر محفظتين مختلفتين.', 'Choose two different wallets.'),
  'error-amount': (
    'أدخل مبلغًا موجبًا ورسومًا غير سالبة ضمن دقة العملة.',
    'Enter a positive exact amount and nonnegative fee within currency precision.',
  ),
  'error-rate': (
    'أدخل سعرًا موجبًا حتى 12 منزلة عشرية؛ السعر 1 للعملة نفسها.',
    'Enter a positive rate with up to 12 decimals; same currency uses rate 1.',
  ),
  'error-rounding': (
    'المبلغ المستلم بعد التقريب يجب أن يكون أكبر من صفر.',
    'Received amount must remain greater than zero after rounding.',
  ),
  'error-insufficient': (
    'الرصيد لا يكفي لإتمام التحويل أو عكسه.',
    'Insufficient balance to complete or reverse the transfer.',
  ),
  'error-notes': (
    'الملاحظات لا تتجاوز 1000 حرف.',
    'Notes must be at most 1000 characters.',
  ),
  'error-conflict': (
    'تغيرت البيانات. أغلق النموذج وافتحه مجددًا.',
    'Data changed. Close and reopen the form.',
  ),
  'error-archived': (
    'استعد المحفظتين المؤرشفتين قبل تغيير التحويل.',
    'Restore archived wallets before changing the transfer.',
  ),
  'error-deleted': (
    'التحويل ملغى بالفعل.',
    'This transfer is already cancelled.',
  ),
  'error-notFound': (
    'المحفظة أو التحويل غير متاح.',
    'Wallet or transfer is unavailable.',
  ),
  'error-currency': (
    'عملة المبلغ لا تطابق المحفظة.',
    'Amount currency does not match the wallet.',
  ),
  'error-integrity': (
    'السجل غير متسق. لم تُحفظ أي تغييرات.',
    'History is inconsistent. No changes were saved.',
  ),
};
