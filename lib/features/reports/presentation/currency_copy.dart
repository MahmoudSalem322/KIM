import 'package:flutter/material.dart';

class CurrencyCopy {
  CurrencyCopy(this.ar);
  final bool ar;
  factory CurrencyCopy.of(BuildContext context) =>
      CurrencyCopy(Localizations.localeOf(context).languageCode == 'ar');
  String call(String key) {
    final text = _copy[key];
    return text == null
        ? key
        : ar
        ? text.$1
        : text.$2;
  }
}

const _copy = <String, (String, String)>{
  'title': ('العملات وأسعار الصرف', 'Currencies & exchange rates'),
  'description': (
    'عملة العرض تغيّر التقارير ولوحة التحكم فقط. تبقى مبالغ العمليات وعملاتها الأصلية محفوظة كما هي.',
    'The display currency changes reports and the dashboard only. Original transaction amounts and currencies stay unchanged.',
  ),
  'primary': ('عملة العرض الرئيسية', 'Primary display currency'),
  'rates': ('أسعار الصرف اليدوية', 'Manual exchange rates'),
  'policy': (
    'تستخدم التقارير آخر الأسعار اليدوية الحالية، مباشرة أو بالعكس، دون ربط عبر عملة ثالثة. تاريخ السعر مرجع توثيقي وليس سعرًا تاريخيًا لكل عملية. أي تحويل ناقص يظهر بوضوح.',
    'Reports use the current manual rates, directly or inversely, without conversion through a third currency. The rate date documents the quotation; it is not a historical rate for each transaction. Missing conversions are clearly marked.',
  ),
  'add': ('إضافة سعر صرف', 'Add exchange rate'),
  'edit': ('تعديل سعر الصرف', 'Edit exchange rate'),
  'delete': ('حذف', 'Delete'),
  'deleteTitle': ('حذف سعر الصرف؟', 'Delete exchange rate?'),
  'deleteBody': (
    'ستصبح التحويلات التي تحتاج هذا السعر غير مكتملة. لن تتغير أي عملية أصلية.',
    'Conversions requiring this rate will become incomplete. Original transactions stay unchanged.',
  ),
  'empty': (
    'أضف سعرًا موثّقًا لتوحيد عرض أرصدتك وتقاريرك متعددة العملات.',
    'Add a documented rate to combine your balances and reports across currencies.',
  ),
  'from': ('من العملة', 'From currency'),
  'to': ('إلى العملة', 'To currency'),
  'rate': (
    'السعر: وحدة واحدة من العملة الأولى تساوي',
    'Rate: one unit of the first currency equals',
  ),
  'source': ('مصدر السعر أو مرجعه', 'Rate source or reference'),
  'date': ('تاريخ السعر (YYYY-MM-DD)', 'Rate date (YYYY-MM-DD)'),
  'updated': ('آخر توثيق', 'Last recorded'),
  'save': ('حفظ', 'Save'),
  'cancel': ('إلغاء', 'Cancel'),
  'error': (
    'تعذر الحفظ. قد تكون البيانات تغيّرت؛ أغلق النافذة وحاول مجددًا.',
    'Could not save. Data may have changed; close the dialog and try again.',
  ),
  'invalid': (
    'أدخل سعرًا عشريًا موجبًا ومصدرًا وتاريخًا صحيحًا، واختر عملتين مختلفتين.',
    'Enter a positive decimal rate, a source and a valid date; choose two different currencies.',
  ),
  'loadingError': ('تعذر تحميل العملات', 'Could not load currencies'),
  'same': ('اختر عملتين مختلفتين', 'Choose two different currencies'),
};
