# Kim — المرحلة الأولى

تطبيق Flutter Web محلي لإدارة المساحة المالية الشخصية. هذه النسخة تؤسس المشروع فقط؛ إدارة المحافظ والعمليات والميزانيات والتقارير لم تُنفذ بعد.

## التشغيل

يتطلب Flutter 3.47.2 أو أحدث متوافقًا مع Dart 3.13، وChrome.

```powershell
flutter pub get
flutter run -d chrome --web-port=8080
```

استخدم المنفذ نفسه دائمًا؛ IndexedDB مرتبط بعنوان الموقع والمتصفح والمنفذ.

## بناء نسخة تعمل دون إنترنت

```powershell
.\tool\build_web.ps1
```

أو عبر أي نظام:

```sh
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
dart run tool/generate_offline.dart
```

اخدم مجلد `build/web` عبر localhost أو HTTPS؛ لا تفتح `index.html` عبر `file://`.
مثال إذا كان Python متاحًا:

```sh
python -m http.server 8080 --directory build/web
```

يُثبت عامل الخدمة الكاش بعد تنزيل كل ملفات البناء. بعد اكتمال التثبيت يمكنك
إعادة تحميل التطبيق دون شبكة. النسخة التطويرية `flutter run` ليست نسخة العمل
دون إنترنت. يجب إعادة توليد الكاش بعد كل بناء. عند تحديث الإصدار يُفعّل الكاش
الجديد بعد إغلاق تبويبات الإصدار القديم وإعادة فتح التطبيق، لتجنب خلط ملفات
الإصدارين. عند النشر داخل مجلد فرعي، مرر `-BaseHref /kim/` إلى سكربت البناء.

## ما يعمل الآن

- Riverpod لإدارة الحالة وحقن الاعتماديات، GoRouter لمسارات الصفحات الست.
- إعدادات فعلية: العربية/الإنجليزية وRTL/LTR، وثيم الجهاز/الفاتح/الداكن.
- حفظ إعدادات المتصفح في IndexedDB عبر Sembast Web، مع رسالة خطأ واضحة عند
  تعذر الحفظ أو فتح القاعدة. لا يوجد تراجع صامت إلى تخزين في الذاكرة.
- Design System موحد: ألوان، خطوط Noto محلية مرخصة OFL، أزرار، بطاقات، حقول
  نماذج، نوافذ حوار وتنقل متجاوب. لا توجد خطوط أو موارد renderer من CDN.
- حالات فارغة للمحافظ والعمليات والميزانيات والتقارير؛ لا توجد بيانات مالية وهمية.
- `Money`: وحدات صغرى `BigInt` مع عملة ودقة صريحة، تحليل عشري صارم دون تقريب،
  تخزين نصي آمن لقيم أكبر من حد JavaScript، ورفض جمع العملات أو الدقات المختلفة.
- `OperationId`: UUID v4، و`AppDatabase.applyOnce` ينفذ الكتابة ووصل منع التكرار
  في معاملة ذرية. إعادة نفس الطلب بنفس المعرّف لا تكرر الكتابة؛ تغييره يرفض الطلب.
- قاعدة إصدارها 2، وترحيل محفوظ من الإصدار 1، ورفض قواعد الإصدارات الأحدث.

## البنية

```text
lib/
  app/                     # bootstrap, app, routing, responsive shell
  core/
    domain/                # exact money and operation IDs
    data/                  # database, migrations, atomic receipts
    l10n/                  # all Arabic/English product copy
    platform/              # browser language metadata adapter
  shared/
    design_system/         # tokens, typography, theme, UI components
    widgets/               # page viewport and honest empty states
  features/
    settings/
      domain/              # settings entity and repository contract
      data/                # durable local repository
      presentation/        # controller and settings page
    dashboard/presentation/
    wallets/presentation/
    transactions/presentation/
    budgets/presentation/
    reports/presentation/
```

أضف Domain وData لكل ميزة عندما تُنفذ فعليًا؛ لا تُنشئ منطقًا أو مستودعات وهمية
للمراحل التالية. Presentation لا يصل إلى IndexedDB مباشرة. Domain لا يستورد
Flutter أو مكتبات التخزين. اعتماديات البناء مثبتة في `pubspec.lock`.

## الاختبارات

```powershell
flutter analyze
flutter test
```

اختبارات المال تغطي الكسور والأرقام العربية والقيم الضخمة ورفض المدخلات غير
الصحيحة. اختبارات القاعدة تستخدم قاعدة ملفات حقيقية وتغطي إعادة الفتح والترحيل
والتكرار المتزامن والتراجع الذري. اختبارات الواجهة تغطي التنقل وحفظ الإعدادات
والثيم واللغة وRTL والأبعاد الصغيرة والوصول. اختبارات الإعدادات تغطي فشل الحفظ
والتغييرات السريعة المتتالية.

اختبار متصفح اختياري بعد بناء الويب وتشغيل خادم محلي على المنفذ 8765:

```powershell
npm install --prefix tool
$env:KIM_URL='http://127.0.0.1:8765'
$env:CHROME_EXECUTABLE='C:\Program Files\Google\Chrome\Application\chrome.exe'
npm run test:browser --prefix tool
```

يشغّل اختبار المتصفح نسخة حقيقية، ويغير اللغة والثيم ويعيد تحميلها ثم يقطع
الشبكة ويعيد فتحها، ويفحص عدم وجود طلبات خارجية. يكتب التقرير والصور في `docs`.

لاختبار الحسابات على هدف JavaScript مستقلاً عن مشغّل اختبار Chrome في SDK:

```powershell
dart compile js tool/money_web_check.dart -o tool/money_web_check.js
$env:KIM_MONEY_JS=(Resolve-Path tool/money_web_check.js).Path
npm run test:browser --prefix tool
```

## ترحيل البيانات وسلامة العمليات

زِد `schemaVersion` عند تغير شكل البيانات وأضف خطوة ترحيل واختبارًا من الإصدار
السابق. Sembast ينفذ callback الترحيل في معاملة الافتتاح. لا تستبدل القاعدة أو
تمسحها عند خطأ الترحيل. دالة `applyOnce` تتطلب معرفًا ثابتًا وطلبًا canonical
ثابتًا عبر المحاولات. أنشئ المعرف والوقت خارج callback، واجعل كل تأثير فيه
كتابة باستخدام `Transaction` نفسه؛ قد يعيد Sembast Web تشغيل callback عند
تعارض التبويبات. لا تضع إشعارات أو اتصال شبكة داخل المعاملة.

## حدود هذه المرحلة

الويب هو المنصة المدعومة والمختبرة حاليًا. لا يوجد Backend أو حساب مستخدم أو
مزامنة خارجية. بيانات المتصفح ليست نسخة احتياطية؛ مسح بيانات الموقع يحذفها،
والتصفح الخاص أو قيود المساحة قد تمنع الاحتفاظ بها. أول تحميل يحتاج اتصالًا
أو خادمًا محليًا؛ العمل دون شبكة يحتاج اكتمال الكاش على localhost أو HTTPS.
اختبار المتصفح الحالي على Chrome؛ لم تُختبر Safari أو Firefox بعد.

المحافظ والدخل والمصاريف والميزانيات والتقارير والتحويلات والنسخ الاحتياطي
تبقى للمراحل القادمة بعد موافقة صريحة. لا توجد أزرار تدّعي إنشاءها في هذه النسخة.

## GitHub

المستودع: [KIM](https://github.com/MahmoudSalem322/KIM). أحدث النسخة على main، مع فروع الميزات محفوظة.
راجع [خريطة الفروع](docs/git-workflow.md) و[تقرير المرحلة الأولى](docs/phase-1-report.md).

