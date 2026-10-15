import 'package:flutter/material.dart';

import '../../wallets/domain/wallet.dart';

class SavingsCopy {
  SavingsCopy(this.ar);
  final bool ar;
  factory SavingsCopy.of(BuildContext context) =>
      SavingsCopy(Localizations.localeOf(context).languageCode == 'ar');
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
  'title': ('أهداف صغيرة، مستقبل أكبر', 'Small goals. A bigger future.'),
  'navigation': ('أهداف الادخار', 'Savings goals'),
  'subtitle': (
    'أعطِ كل مبلغ هدفًا، وتابع خطواتك نحوه.',
    'Give your money a purpose and follow every step.',
  ),
  'add': ('إنشاء هدف', 'Create goal'),
  'edit': ('تعديل الهدف', 'Edit goal'),
  'name': ('اسم الهدف', 'Goal name'),
  'target': ('المبلغ المستهدف', 'Target amount'),
  'date': ('التاريخ المستهدف (YYYY-MM-DD)', 'Target date (YYYY-MM-DD)'),
  'pickDate': ('اختيار التاريخ', 'Choose date'),
  'currency': ('العملة', 'Currency'),
  'scale': ('منازل عشرية', 'decimal places'),
  'color': ('اللون', 'Color'),
  'icon': ('الأيقونة', 'Icon'),
  'save': ('حفظ الهدف', 'Save goal'),
  'cancel': ('إلغاء', 'Cancel'),
  'done': ('إغلاق', 'Done'),
  'allocate': ('تخصيص الأموال', 'Allocate funds'),
  'allocationSave': ('حفظ التخصيص', 'Save allocation'),
  'wallet': ('المحفظة', 'Wallet'),
  'allocation': (
    'إجمالي تخصيص هذا الهدف من المحفظة',
    'Total earmarked for this goal from this wallet',
  ),
  'allocationHint': (
    'أدخل الإجمالي الجديد، وليس الزيادة. الصفر يحرر تخصيص هذا الهدف من المحفظة.',
    'Enter the new total, not an increase. Zero releases this goal’s allocation from the wallet.',
  ),
  'note': ('ملاحظة (اختياري)', 'Note (optional)'),
  'reservationHint': (
    'التخصيص يحجز أموالًا موجودة داخل محافظك. يبقى الرصيد كما هو، ويقل المتاح للصرف. لا تُسجل عملية دخل أو مصروف.',
    'Allocations earmark existing wallet funds. Balances stay unchanged and spendable funds decrease. No income or expense is created.',
  ),
  'transfer': ('نقل أموال فعليًا', 'Move money between wallets'),
  'transferHint': (
    'للنقل الفعلي إلى محفظة ادخار، استخدم التحويلات أولًا، ثم خصص من المحفظة المستلمة. حرر أي مبلغ محجوز قبل نقله. لا يوجد تحويل تلقائي عند التخصيص.',
    'To move funds into a savings wallet, make a transfer first, then allocate from the receiving wallet. Release earmarked funds before moving them. Allocating never transfers money automatically.',
  ),
  'currencyHint': (
    'عملة الهدف ثابتة؛ التخصيص من محافظ بنفس العملة ودقتها فقط. استخدم التحويل بسعر صرف إذا اختلفت العملات.',
    'Goal currency is fixed. Allocate only from wallets with matching currency and precision. Use a transfer with an exchange rate for other currencies.',
  ),
  'active': ('أهداف نشطة', 'Active goals'),
  'achieved': ('أهداف مكتملة التمويل', 'Fully funded goals'),
  'closed': ('أهداف مغلقة', 'Closed goals'),
  'showClosed': ('عرض المغلقة', 'Show closed'),
  'funded': ('جاهز لتحقيقه', 'Ready to make it happen'),
  'saved': ('مخصص حاليًا', 'Currently earmarked'),
  'remaining': ('المتبقي للهدف', 'Left to reach target'),
  'days': ('يوم متبقٍ', 'days remaining'),
  'overdue': ('يوم بعد الموعد', 'days overdue'),
  'today': ('موعد الهدف اليوم', 'Target date is today'),
  'closeGoal': ('إغلاق الهدف', 'Close goal'),
  'closeHint': (
    'سيُحفظ السجل ويُحرر كل المبلغ المحجوز للصرف. لا تُنقل الأموال ولا يُسجل مصروف. الإغلاق نهائي؛ يمكنك إنشاء هدف جديد لاحقًا.',
    'History is kept and all earmarked funds become spendable. No money moves and no expense is recorded. Closing is final; you can create a new goal later.',
  ),
  'closedSnapshot': ('عند الإغلاق (تم تحريره)', 'At closing (released)'),
  'history': ('سجل المساهمات', 'Contribution history'),
  'historyEmpty': (
    'أول مساهمة تبدأ الخطوة الأولى',
    'Your first contribution starts the journey',
  ),
  'allocatedEvent': ('تخصيص', 'Earmarked'),
  'releasedEvent': ('تحرير', 'Released'),
  'closingEvent': ('تحرير عند إغلاق الهدف', 'Released on closing'),
  'availability': ('المتاح في محافظك', 'Your wallet availability'),
  'balance': ('الرصيد الفعلي', 'Actual balance'),
  'reserved': ('محجوز لكل الأهداف', 'Earmarked across goals'),
  'available': ('متاح للصرف والتخصيص', 'Available to spend or allocate'),
  'current': ('تخصيص هذا الهدف', 'This goal’s allocation'),
  'totalsHint': (
    'تُعرض العملات منفصلة. الأهداف جزء من الأرصدة الفعلية، وليست أرصدة إضافية.',
    'Currencies are shown separately. Goal funds are part of actual balances, never additional balances.',
  ),
  'empty': ('ما الذي تدخر لأجله؟', 'What are you saving for?'),
  'emptyBody': (
    'رحلة، بيت، أو مساحة أمان. اختر هدفك وابدأ بمبلغ صغير.',
    'A trip, a home, or peace of mind. Choose your goal and start small.',
  ),
  'emptyClosed': ('لا توجد أهداف مغلقة', 'No closed goals yet'),
  'noWallet': (
    'أظهر أو أضف محفظة نشطة بنفس عملة الهدف ودقتها لتخصيص الأموال.',
    'Show or add an active wallet with matching currency and precision to allocate funds.',
  ),
  'hidden': (
    'الأرقام مخفية لإخفاء رصيد محفظة مرتبطة',
    'Amounts hidden because a linked wallet balance is hidden',
  ),
  'retry': ('إعادة المحاولة', 'Retry'),
  'error': (
    'تعذر تحميل أو حفظ الأهداف. أعد المحاولة.',
    'Could not load or save goals. Please retry.',
  ),
  'error-invalidGoal': (
    'راجع الاسم والمبلغ الموجب والتاريخ واللون والأيقونة.',
    'Check the name, positive target, date, color and icon.',
  ),
  'error-invalidAllocation': (
    'أدخل مبلغًا غير سالب بدقة العملة، وملاحظة حتى 500 حرف.',
    'Enter a nonnegative exact amount and a note up to 500 characters.',
  ),
  'error-conflict': (
    'تغيرت البيانات. أغلق النافذة وأعد فتحها من البيانات المحدثة.',
    'Data changed. Close this dialog and reopen it with the latest data.',
  ),
  'error-reserved': (
    'المبلغ يتجاوز المتاح؛ توجد أموال محجوزة لأهداف ادخار. حرر التخصيص أولًا.',
    'This exceeds available funds; money is earmarked for savings goals. Release allocations first.',
  ),
  'error-aboveTarget': (
    'التخصيص يتجاوز هدف الادخار. ارفع المبلغ المستهدف أولًا.',
    'Allocation exceeds the target. Increase the target first.',
  ),
  'error-belowAllocated': (
    'حرر التخصيص الزائد قبل تخفيض المبلغ المستهدف.',
    'Release excess allocations before reducing the target.',
  ),
  'error-currency': (
    'يجب تطابق عملة المحفظة والهدف ودقتهما. عملة الهدف ثابتة.',
    'Wallet and goal currency and precision must match. Goal currency is fixed.',
  ),
  'error-noChange': (
    'لم تتغير قيمة التخصيص.',
    'The allocation has not changed.',
  ),
  'error-closedGoal': (
    'الهدف مغلق وسجله محفوظ.',
    'The goal is closed and its history is retained.',
  ),
  'error-archived': (
    'استعد المحفظة قبل التخصيص.',
    'Restore the wallet before allocating funds.',
  ),
  'error-notFound': (
    'لم تعد البيانات متاحة.',
    'This item is no longer available.',
  ),
  'savings': ('ادخار', 'Savings'),
  'home': ('بيت', 'Home'),
  'travel': ('سفر', 'Travel'),
  'education': ('تعليم', 'Education'),
  'car': ('سيارة', 'Car'),
  'heart': ('صحة', 'Health'),
  'gift': ('هدية', 'Gift'),
  'shield': ('أمان', 'Safety'),
};
IconData goalIcon(String key) =>
    const <String, IconData>{
      'savings': Icons.savings_outlined,
      'home': Icons.home_outlined,
      'travel': Icons.flight_takeoff_rounded,
      'education': Icons.school_outlined,
      'car': Icons.directions_car_outlined,
      'heart': Icons.favorite_border,
      'gift': Icons.card_giftcard,
      'shield': Icons.shield_outlined,
    }[key] ??
    Icons.savings_outlined;
