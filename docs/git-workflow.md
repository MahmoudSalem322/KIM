# فروع Kim وكوميتات الميزات

الريبو: https://github.com/MahmoudSalem322/KIM

تم تقسيم المشروع الأولي إلى فروع متتابعة بحسب الاعتماديات، وكل فرع يضيف
الميزة المذكورة فقط فوق الفرع السابق. لا تعني صفحات المالية الفارغة أن ميزات
إدارة المحافظ أو العمليات قد نُفذت.

| الفرع | الأساس | ما يضيفه |
|---|---|---|
| feature/project-foundation | main الأولي | حزم Flutter Web وخطوط محلية وإعداد المشروع |
| feature/precise-money | feature/project-foundation | BigInt والعملات ومعرفات العمليات واختباراتها |
| feature/local-database | feature/precise-money | قاعدة IndexedDB وترحيلات ومعاملات ومنع تكرار واختبارات |
| feature/design-system | feature/local-database | الثيم والمكونات والترجمة العربية والإنجليزية |
| feature/persistent-settings | feature/design-system | إعدادات محفوظة وتسلسل الكتابة واختبارات الفشل |
| feature/app-navigation | feature/persistent-settings | الصفحات الفارغة والتنقل المتجاوب والتهيئة واختبارات الواجهة |
| feature/offline-web | feature/app-navigation | موارد محلية وكاش العمل دون شبكة وفحص المتصفح |
| feature/local-font-fallback | feature/offline-web | خط عربي احتياطي محلي للواجهة الإنجليزية |
| phase-1 | feature/local-font-fallback | توثيق المرحلة وتقرير التحقق والصور |

بعد اكتمال التحقق يُدمج phase-1 في main بأمر fast-forward دون إعادة كتابة
التاريخ أو حذف فروع الميزات. main يحتوي المرحلة الأولى المكتملة عند `dbb68a4`.

المرحلة الثانية مستقلة على `feature/wallet-management` من هذا main. تشمل
كوميتات للنطاق والتخزين، والواجهة، وإصلاح الخصوصية، وفحص الويب والتوثيق.
راجع [تقرير المرحلة الثانية](phase-2-report.md). لم تُدمج هذه الميزة في main؛
دمجها يحتاج طلب دمج جديدًا من المستخدم.

في الميزات القادمة: أنشئ فرع feature/<name> من أحدث main، واجعل التنفيذ
والاختبارات في كوميتات واضحة تخص الميزة. لا تبدأ مرحلة مالية جديدة دون موافقة
المستخدم الصريحة.
