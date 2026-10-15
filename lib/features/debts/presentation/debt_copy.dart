import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class DebtCopy {
  DebtCopy(this.ar);
  final bool ar;
  factory DebtCopy.of(BuildContext c) =>
      DebtCopy(Localizations.localeOf(c).languageCode == 'ar');
  String call(String k) {
    final v = _copy[k];
    return v == null
        ? k
        : ar
        ? v.$1
        : v.$2;
  }

  String error(Object e) =>
      call(e is WalletFailure ? 'error-${e.code}' : 'error');
}

const _copy = <String, (String, String)>{
  'navigation': ('الديون والقروض', 'Debts & loans'),
  'title': ('حقوقك والتزاماتك، بوضوح', 'A clear view of what is owed'),
  'subtitle': (
    'تابع ما لك وما عليك، وكل دفعة في مكانها الصحيح.',
    'Track what others owe you, what you owe, and every payment.',
  ),
  'add': ('إضافة سجل دين', 'Add debt record'),
  'edit': ('تعديل الدين', 'Edit debt'),
  'save': ('حفظ السجل الإداري', 'Save administrative record'),
  'adminHint': (
    'إنشاء هذا السجل أو تعديله لا ينقل مالًا ولا يغير رصيد أي محفظة. لتسجيل تسليم أو استلام أصل الدين استخدم الحركة النقدية المنفصلة بعد الحفظ.',
    'Creating or editing this record never moves money or changes a wallet balance. Record the original lending or borrowing separately after saving.',
  ),
  'person': ('الشخص', 'Person'),
  'direction': ('نوع الدين', 'Debt direction'),
  'lent': ('أقرضتُ الآخرين — لي', 'I lent — owed to me'),
  'borrowed': ('اقترضتُ من الآخرين — عليّ', 'I borrowed — I owe'),
  'principal': ('المبلغ الأصلي', 'Original amount'),
  'due': ('الاستحقاق (YYYY-MM-DD)', 'Due date (YYYY-MM-DD)'),
  'notes': ('ملاحظات', 'Notes'),
  'currency': ('العملة', 'Currency'),
  'active': ('نشط', 'Active'),
  'overdue': ('متأخر', 'Overdue'),
  'settled': ('مسدد', 'Settled'),
  'all': ('الكل', 'All'),
  'paid': ('تم سداده', 'Repaid'),
  'remaining': ('المتبقي', 'Outstanding'),
  'status': ('الحالة', 'Status'),
  'payment': ('تسجيل دفعة', 'Record payment'),
  'principalCash': ('تسجيل أصل الدين نقديًا', 'Record original cash movement'),
  'principalRecorded': (
    'الحركة الأصلية مسجلة',
    'Original cash movement recorded',
  ),
  'cashHint': (
    'هذه حركة نقدية فعلية، وتؤثر على المحفظة المختارة. أصل الدين والدفعات ليست دخلًا أو مصروفًا ولا تدخل الميزانيات. لا تسجل حركة سبق تسجيلها في مكان آخر.',
    'This is a real cash movement and changes the selected wallet. Loan principal and repayments are not income or expenses and do not enter budgets. Do not record cash already entered elsewhere.',
  ),
  'originalHint': (
    'سجّل هذه الحركة فقط إذا أردت تسجيل صرف أو استلام المبلغ الأصلي الآن. السجل الإداري وحده لا يغيّر النقد، والدفعات تبقى مستقلة عنه.',
    'Record this only to enter the original disbursement or receipt now. The administrative record alone never changes cash; repayments remain separate.',
  ),
  'amount': ('مبلغ الحركة', 'Cash amount'),
  'wallet': ('المحفظة', 'Wallet'),
  'date': ('تاريخ الحركة (YYYY-MM-DD)', 'Cash date (YYYY-MM-DD)'),
  'cashSave': ('تسجيل الحركة النقدية', 'Record cash movement'),
  'editCash': ('تعديل الحركة', 'Edit cash movement'),
  'cancelCash': ('إلغاء الحركة', 'Cancel cash movement'),
  'cancelHint': (
    'سيُعكس أثر الحركة في المحفظة مع حفظ سجلها. إلغاء دفعة يعيد المبلغ إلى المتبقي. يلزم توفر الأموال لعكس حركة مستلمة.',
    'Reverse this movement in the wallet and keep its history. Cancelling a repayment increases the outstanding amount. Reversing received funds requires sufficient available funds.',
  ),
  'cancelled': ('ملغاة', 'Cancelled'),
  'history': ('الحركات والدفعات', 'Cash movements & payments'),
  'historyEmpty': (
    'لا حركات نقدية؛ هذا سجل إداري فقط.',
    'No cash movements; this is an administrative record only.',
  ),
  'paymentEvent': ('دفعة سداد', 'Repayment'),
  'principalEvent': ('أصل الدين', 'Original loan cash'),
  'in': ('يضاف للمحفظة', 'Added to wallet'),
  'out': ('يخصم من المحفظة', 'Deducted from wallet'),
  'editHint': (
    'بعد تسجيل أول حركة، يبقى المبلغ الأصلي والعملة والنوع ثابتة لحفظ سلامة السجل. يمكن تعديل الشخص والموعد والملاحظات.',
    'After the first cash movement, original amount, currency and direction are fixed to preserve history. You can edit the person, due date and notes.',
  ),
  'noWallet': (
    'أضف أو أظهر محفظة نشطة بنفس العملة والدقة.',
    'Add or show an active wallet with matching currency and precision.',
  ),
  'empty': ('كل اتفاق، بسجل واضح', 'Every agreement deserves a clear record'),
  'emptyBody': (
    'أضف ما أقرضته أو اقترضته، ثم سجل الدفعات عند حدوثها.',
    'Add money lent or borrowed, then record repayments when they happen.',
  ),
  'privacy': (
    'المبالغ والحالة مخفية لإخفاء رصيد محفظة مرتبطة',
    'Amounts and status hidden because a linked wallet balance is hidden',
  ),
  'totalsHint': (
    'المبالغ حسب عملتها ودقتها؛ لا تُجمع عملات مختلفة. حالة التأخر تُحسب حسب تاريخ اليوم.',
    'Amounts keep their currency and precision; different currencies are never added. Overdue status uses today’s date.',
  ),
  'cancel': ('إلغاء', 'Cancel'),
  'retry': ('إعادة المحاولة', 'Retry'),
  'error': (
    'تعذر تحميل أو حفظ البيانات. أعد المحاولة.',
    'Could not load or save data. Please retry.',
  ),
  'error-invalidDebt': (
    'راجع الشخص والمبلغ الموجب والموعد والملاحظات.',
    'Check the person, positive amount, due date and notes.',
  ),
  'error-invalidPayment': (
    'أدخل مبلغًا موجبًا بدقة العملة وتاريخًا صحيحًا.',
    'Enter a positive exact amount and valid date.',
  ),
  'error-overpayment': (
    'المبلغ يتجاوز المتبقي من الدين.',
    'The payment exceeds the outstanding debt.',
  ),
  'error-principalRecorded': (
    'أصل الدين مسجل نقديًا بالفعل، أو المبلغ لا يطابق الأصل.',
    'Original cash is already recorded or the amount does not match the principal.',
  ),
  'error-immutableDebt': (
    'نوع الدين وعملته ومبلغه الأصلي ثابتة بعد وجود حركات.',
    'Debt direction, currency and principal are fixed after cash history exists.',
  ),
  'error-insufficient': (
    'الرصيد غير كافٍ لهذه الحركة أو لعكس المبلغ المستلم.',
    'Insufficient funds for this movement or to reverse received cash.',
  ),
  'error-reserved': (
    'الأموال محجوزة لأهداف ادخار. حرر التخصيص أولًا.',
    'Funds are earmarked for savings goals. Release allocations first.',
  ),
  'error-currency': (
    'يجب تطابق عملة المحفظة والدين ودقتهما. حوّل بين العملات بشكل منفصل.',
    'Wallet and debt currency and precision must match. Exchange currencies separately.',
  ),
  'error-conflict': (
    'تغيرت البيانات. أغلق النموذج وأعد فتحه.',
    'Data changed. Close this form and reopen it.',
  ),
  'error-archived': (
    'استعد المحفظة قبل تعديل حركتها النقدية.',
    'Restore the wallet before changing its cash movement.',
  ),
  'error-notFound': ('لم يُعثر على السجل.', 'Record not found.'),
  'debtIn': ('استلام نقدي لدين', 'Debt cash received'),
  'debtOut': ('دفع نقدي لدين', 'Debt cash paid'),
  'debtReversal': ('عكس حركة دين', 'Debt cash reversal'),
};
