# تقرير تفاعل مكونات VitaMate

تاريخ التقرير: 2026-04-14

نطاق التقرير: المستودع الحالي داخل `Implementation` بما يشمل `vitamate_backend` و`vitamate_frontend` والمكونات المساندة ذات الصلة.

هدف التقرير: شرح المكونات الأساسية في النظام، وظيفة كل مكوّن، وكيف تتفاعل الأجزاء مع بعضها من لحظة تشغيل التطبيق وحتى تسجيل البيانات الصحية وعرضها وإدارتها.

## 1. الصورة العامة

يعتمد المشروع على معمارية ثنائية واضحة:

- الواجهة الأمامية مكتوبة بـ Flutter، وهي مسؤولة عن العرض، التنقل، إدارة الحالة المحلية، واستدعاء الـ API.
- الواجهة الخلفية مبنية على Django + Django REST Framework، وهي مسؤولة عن المصادقة، حفظ البيانات، تنفيذ منطق الأعمال، احتساب النقاط، وتجميع بيانات لوحة التحكم.
- توجد طبقة تنسيق خاصة بالحالات المزمنة توصل بين الأدوية، المؤشرات، القيود الصحية، والتقييم اليومي.
- توجد طبقة إشعارات محلية في Flutter تعمل بالتكامل مع بيانات التذكير القادمة من الباكند، خصوصًا في الأدوية المزمنة.

التدفق الأعلى في النظام هو:

`Flutter UI -> Controller -> API class -> HttpClient/Dio -> Django endpoint -> Service/Coordinator -> Models/Repositories -> Database`

## 2. المكونات الرئيسية في الواجهة الخلفية

### 2.1 مشروع Django الجذر

الملف المحوري: `Implementation/vitamate_backend/vitamate_project/urls.py`

وظيفته الأساسية:

- تعريف نقطة الدخول لكل واجهات الـ API.
- ربط مسارات المصادقة مع مسارات الـ router الخاصة بالميزات الصحية.
- فصل مسارات العقود العامة مثل `/api/dashboard/` و`/api/history/` و`/api/auth/...`.

التفاعل مع بقية المكونات:

- يوجّه طلبات التتبع العامة إلى `core.views`.
- يوجّه طلبات الحالات المزمنة إلى `core.chronic_views`.
- يوجّه طلبات الحساب الشخصي إلى `users.views`.

### 2.2 تطبيق `users`

الملفات المحورية:

- `Implementation/vitamate_backend/users/views.py`
- `Implementation/vitamate_backend/users/models.py`
- `Implementation/vitamate_backend/users/services/user_profile_service.py`
- `Implementation/vitamate_backend/users/services/profile_metrics_calculator.py`

وظيفته الأساسية:

- إدارة التسجيل، تحديث الحساب، وضمان وجود `UserProfile` لكل مستخدم.
- حفظ البيانات الصحية الأساسية مثل الوزن، الطول، الجنس، وتفضيلات النوم والتذكيرات.
- احتساب القيم المشتقة مثل الأهداف اليومية للماء والسعرات والخطوات والحرق.

التفاعل مع بقية المكونات:

- عند استدعاء `/api/auth/me/` يتم التأكد من وجود `UserProfile`.
- طبقة `UserProfileService` تستخدم `ProfileMetricsCalculator` لإعادة حساب الأهداف المشتقة بعد أي تعديل على الملف الصحي.
- `HealthTrackerCoordinator` يعتمد على `UserProfile` لقراءة الأهداف الأساسية قبل إنتاج dashboard/history.

### 2.3 تطبيق `core` كنواة الدومين الصحي

الملف المحوري: `Implementation/vitamate_backend/core/models.py`

وظيفته الأساسية:

- احتواء الكيانات الأساسية للدومين الصحي.
- تمثيل سجلات الوجبات والماء والنشاط والنوم والخطوات والعادات والأدوية.
- تمثيل الدومين الخاص بالحالات المزمنة: نوع الحالة، قيودها، أهدافها، أدويتها، جداول الجرعات، السجلات اليومية، والتنبيهات.

أهم الكيانات:

- `FoodItem`, `MealLog`, `WaterLog`, `Exercise`, `ActivityLog`, `StepLog`, `SleepLog`
- `Medicine`, `MedicineLog`, `Habit`, `HabitLog`
- `ConditionType`, `UserCondition`, `ConditionRuleProfile`, `HealthRestriction`, `HealthTarget`
- `HealthIndicatorRecord`, `ConditionAlert`, `ConditionMedication`, `ConditionMedicationSchedule`, `ConditionMedicationLog`, `ConditionDailyEvaluation`, `ConditionPointsAudit`

التفاعل مع بقية المكونات:

- الـ views والـ services تقرأ وتكتب هذه الموديلات مباشرة أو عبر repositories.
- الـ coordinator يبني dashboard/history من تجميع هذه الكيانات.
- طبقة الحالات المزمنة تستخدم هذه النماذج لتوليد القيود الفعالة والتقييم اليومي.

### 2.4 `core.views` للميزات الصحية الأساسية

الملف المحوري: `Implementation/vitamate_backend/core/views.py`

وظيفته الأساسية:

- تقديم CRUD وواجهات القراءة/الكتابة للوجبات والماء والخطوات والنوم والنشاط والعادات.
- إبقاء الـ views رفيعة قدر الإمكان.
- تمرير الكتابة إلى خدمات command services، وتمرير القراءة المركبة إلى `HealthTrackerCoordinator`.

التفاعل مع بقية المكونات:

- `MealLogViewSet` يستدعي `NutritionService.log_meal`.
- `WaterLogViewSet` يستدعي `WaterService.log_water`.
- `StepLogViewSet` يستدعي `StepsService.log_steps`.
- `ActivityLogViewSet` يستدعي `ActivityService.log_activity`.
- `SleepLogViewSet` يستدعي `SleepService.log_sleep`.
- `DashboardView` و`StatsHistoryView` يعتمدان على `HealthTrackerCoordinator` كمصدر وحيد للتجميع.

### 2.5 خدمات الكتابة الصحية الأساسية

الملفات المحورية:

- `Implementation/vitamate_backend/core/services/nutrition_service.py`
- `Implementation/vitamate_backend/core/services/water_service.py`
- `Implementation/vitamate_backend/core/services/steps_service.py`
- `Implementation/vitamate_backend/core/services/activity_service.py`
- `Implementation/vitamate_backend/core/services/sleep_service.py`

وظيفتها الأساسية:

- تنفيذ أوامر الكتابة command side مثل تسجيل الوجبة أو الماء أو النوم.
- عزل منطق النقاط والآثار الجانبية عن الـ views.
- استخدام repositories والموديلات لكتابة البيانات ثم استدعاء `PointsService` عندما يلزم.

ملاحظة معمارية مهمة:

- هذه الخدمات ليست trackers.
- هي command services مختصة بالكتابة.
- طبقة الـ trackers موجودة على جهة القراءة read side لتوحيد تمثيل البيانات عند تكوين snapshots.

### 2.6 `HealthTrackerCoordinator`

الملف المحوري: `Implementation/vitamate_backend/core/services/health_tracker_coordinator.py`

وظيفته الأساسية:

- تجميع البيانات الموزعة بين عدة جداول لإنتاج payload موحد للـ dashboard.
- إنتاج تاريخ مختصر لآخر سبعة أيام في `/api/history/`.
- احتساب المؤشرات النهائية بالاستناد إلى `UserProfile` والقيود الصحية والحالات المزمنة والبيانات اليومية.

التفاعل مع بقية المكونات:

- يقرأ `UserProfile`, `MealLog`, `WaterLog`, `SleepLog`, `StepLog`, `ActivityLog`.
- يتكامل مع `ConditionIntegrationCoordinator` للحصول على القيود الفعالة للحالات المزمنة.
- يستخدم `HealthConstraintEngine` لحساب القيم المعدلة مثل `calories_remaining` و`adjusted_water_target`.
- يقرأ `UserScoreRepository` لجلب النقاط والمستوى.
- يبني قائمة `BaseTracker` adapters ثم يحولها إلى `TrackerSnapshot`.

### 2.7 `core/domain/trackers`

الملفات المحورية:

- `Implementation/vitamate_backend/core/domain/trackers/base.py`
- `Implementation/vitamate_backend/core/domain/trackers/adapters.py`

وظيفته الأساسية:

- تعريف عقدة تجريدية موحدة للمتتبعات `BaseTracker`.
- توحيد شكل snapshot لأي tracker بصرف النظر عن مصدر البيانات.
- تمكين `HealthTrackerCoordinator` من العمل على قائمة متجانسة من trackers بدل منطق متفرّع لكل نوع.

المتتبعات الحالية:

- `ActivityTrackerAdapter`
- `StepsTrackerAdapter`
- `SleepTrackerAdapter`
- `HydrationTrackerAdapter`
- `NutritionTrackerAdapter`
- `MedicationTrackerAdapter`
- `HabitTrackerAdapter`
- `ChronicConditionTrackerAdapter`

التفاعل مع بقية المكونات:

- لا تكتب البيانات ولا تتعامل مع الـ API مباشرة.
- تستلم قيمًا مجمّعة من الـ coordinator وتعيد `TrackerSnapshot`.
- فائدتها الأساسية الحالية هي توحيد القراءة الداخلية وليس توفير API مستقل حتى الآن.

### 2.8 مكوّن الحالات المزمنة

الملفات المحورية:

- `Implementation/vitamate_backend/core/chronic_views.py`
- `Implementation/vitamate_backend/core/services/chronic_condition_service.py`
- `Implementation/vitamate_backend/core/services/condition_medication_service.py`
- `Implementation/vitamate_backend/core/services/condition_constraint_engine.py`
- `Implementation/vitamate_backend/core/services/condition_integration_coordinator.py`
- `Implementation/vitamate_backend/core/services/condition_points_evaluator.py`

وظيفته الأساسية:

- إدارة الحالات المزمنة والقيود الصحية المرتبطة بها.
- إدارة الأدوية المزمنة والجداول اليومية والحالات مثل taken/missed/snoozed/skipped.
- تقييم الالتزام الدوائي والالتزام بالقيود اليومية.
- إنتاج قيود أكثر أمانًا لتغذية dashboard/history وبقية الميزات.

التفاعل مع بقية المكونات:

- `UserConditionViewSet` يمرر الإنشاء والتعديل إلى الموديلات ثم يطلب sync من `ConditionIntegrationCoordinator`.
- `ConditionIntegrationCoordinator` يعيد بناء الأهداف ويطلق التقييم اليومي.
- `ConditionConstraintEngine` يدمج قيود الحالات مع الأهداف العامة للمستخدم.
- `ConditionMedicationService` يدير تنفيذ الجرعات وسجلّاتها.
- `HealthTrackerCoordinator` يقرأ الناتج النهائي للحالات المزمنة ويحقنه في dashboard/history.

### 2.9 `gamification`

الملف المحوري: `Implementation/vitamate_backend/gamification/services/points_service.py`

وظيفته الأساسية:

- تطبيق قواعد النقاط بصورة مركزية بدل نشرها داخل كل endpoint.
- زيادة أو إنقاص النقاط حسب النشاط والماء والنوم والخطوات والوجبات.

التفاعل مع بقية المكونات:

- خدمات الكتابة في `core/services` تستدعي `PointsService`.
- `UserScoreRepository` يضمن وجود سجل النقاط ويعيده أو ينشئه عند الحاجة.
- الـ dashboard يقرأ النقاط النهائية من repository وليس من حسابات لحظية في الواجهة الأمامية.

## 3. المكونات الرئيسية في الواجهة الأمامية

### 3.1 نقطة التشغيل وبناء التطبيق

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/main.dart`
- `Implementation/vitamate_frontend/lib/app.dart`
- `Implementation/vitamate_frontend/lib/core/routing/routes.dart`

وظيفتها الأساسية:

- تهيئة `NotificationsService` و`HttpClient` قبل تشغيل الواجهة.
- تعريف جميع الشاشات والمسارات.
- إبقاء نقطة الدخول بسيطة وواضحة.

التفاعل مع بقية المكونات:

- `main.dart` يضمن أن الشبكة والإشعارات جاهزتان قبل `runApp`.
- `app.dart` يربط المسارات بشاشات الميزات.
- `Routes` يمنع التكرار النصي لمسارات التنقل.

### 3.2 البنية الأساسية المشتركة في Flutter

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/core/network/http_client.dart`
- `Implementation/vitamate_frontend/lib/core/network/auth_interceptor.dart`
- `Implementation/vitamate_frontend/lib/core/storage/secure_storage.dart`
- `Implementation/vitamate_frontend/lib/core/config/api_endpoints.dart`
- `Implementation/vitamate_frontend/lib/core/notifications/notifications_service.dart`

وظيفتها الأساسية:

- `HttpClient` يوفّر `Dio` موحدًا لكل التطبيق.
- `AuthInterceptor` يحقن `Authorization` token ويحاول refresh عند 401.
- `SecureStorage` يحفظ access/refresh tokens وبعض الإعدادات المحلية.
- `ApiEndpoints` يحدد عقود المسارات ويحلّ base URL القابل للوصول.
- `NotificationsService` يدير الإشعارات المحلية اليومية وإشعارات جرعات الحالات المزمنة.

التفاعل مع بقية المكونات:

- كل API class في Flutter تمر عبر `HttpClient.dio`.
- `AuthRepository` يكتب ويقرأ التوكنات عبر `SecureStorage`.
- `ChronicConditionsController` يرسل خطط الجرعات إلى `NotificationsService.syncChronicMedicationReminders`.

### 3.3 مكوّن المصادقة

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/auth/data/auth_api.dart`
- `Implementation/vitamate_frontend/lib/auth/data/auth_repository.dart`
- `Implementation/vitamate_frontend/lib/auth/state/auth_controller.dart`

وظيفته الأساسية:

- تنفيذ التسجيل وتسجيل الدخول وجلب/تحديث بيانات المستخدم.
- تحويل JSON الخام إلى نماذج typed مثل `AuthUser`.
- فصل واجهة الشبكة عن واجهة الحالة.

التفاعل مع بقية المكونات:

- الشاشة تستدعي `AuthController`.
- `AuthController` يستدعي `AuthRepository`.
- `AuthRepository` يستدعي `AuthApi`.
- `AuthApi` يستخدم `HttpClient.dio`.
- بعد login يتم حفظ التوكنات ثم قراءة `/api/auth/me/` لملء الحالة typed.

### 3.4 مكوّن Home

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/features/home/data/home_api.dart`
- `Implementation/vitamate_frontend/lib/features/home/state/home_controller.dart`
- `Implementation/vitamate_frontend/lib/features/home/models/dashboard_data.dart`
- `Implementation/vitamate_frontend/lib/features/home/screens/home_screen.dart`

وظيفته الأساسية:

- جلب dashboard من الباكند وتحويله إلى تمثيل مناسب للواجهة.
- عرض ملخص اليوم والنقاط والتقدم والحالات المزمنة.

التفاعل مع بقية المكونات:

- `HomeController` يطلب dashboard من `HomeApi`.
- `DashboardData` يفكك payload القادم من الباكند.
- `HomeScreen` يعرض وحدات التنقل إلى بقية الميزات.

### 3.5 مكوّن Stats / History

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/features/stats/data/stats_api.dart`
- `Implementation/vitamate_frontend/lib/features/stats/state/stats_controller.dart`

وظيفته الأساسية:

- تحميل dashboard الحالي والتاريخ الأسبوعي.
- تحويل history إلى عناصر قابلة للرسم والتحليل داخل الواجهة.

التفاعل مع بقية المكونات:

- يعتمد على `/api/dashboard/` و`/api/history/`.
- يعرض أثر القيود المزمنة على الالتزام والجرعات المعلقة بجانب الإحصاءات العامة.

### 3.6 ميزات التتبع اليومية

الأمثلة الأساسية:

- `water`
- `sleep`
- `nutrition`
- `steps`
- `activity`

وظيفتها الأساسية:

- كل ميزة تمتلك API class خاصة بها.
- كل ميزة تمتلك state/controller وشاشة عرض وإدخال.
- الكتابة تتم عبر endpoints الخاصة بالميزة، والقراءة النهائية غالبًا تُعرض أيضًا من dashboard/history.

التفاعل مع بقية المكونات:

- إدخال البيانات من الشاشة يمر إلى API class.
- الباكند يسجل البيانات ويطبّق منطق النقاط.
- عند الرجوع إلى Home أو Stats يظهر الأثر لأن dashboard يُعاد بناؤه من البيانات المخزنة.

### 3.7 مكوّن الحالات المزمنة في Flutter

الملفات المحورية:

- `Implementation/vitamate_frontend/lib/features/chronic_conditions/data/chronic_conditions_api.dart`
- `Implementation/vitamate_frontend/lib/features/chronic_conditions/state/chronic_conditions_controller.dart`
- `Implementation/vitamate_frontend/lib/features/chronic_conditions/screens/chronic_conditions_screen.dart`
- `Implementation/vitamate_frontend/lib/features/chronic_conditions/screens/chronic_condition_detail_screen.dart`

وظيفته الأساسية:

- جلب قائمة الحالات، أنواع الحالات، الأدوية، الجداول، والتنبيهات.
- إنشاء وتعديل وتعطيل الحالات والأدوية.
- تنفيذ أوامر الجرعات `take/miss/snooze/skip`.
- تحويل جداول الجرعات إلى خطط إشعار محلي.

التفاعل مع بقية المكونات:

- `ChronicConditionsController` يجمّع البيانات من `ChronicConditionsApi`.
- بعد أي تعديل أو تحميل، يحسب الجرعات اليومية ويعيد مزامنة الإشعارات المحلية.
- عند تنفيذ snooze، يتم استدعاء endpoint في الباكند ثم جدولة إشعار محلي جديد على الجهاز.

## 4. تدفقات العمل الأساسية بين المكوّنات

### 4.1 تدفق تسجيل الدخول

- المستخدم يملأ نموذج `LoginScreen`.
- الشاشة تستدعي `AuthController.login`.
- `AuthController` يمرر الطلب إلى `AuthRepository.login`.
- `AuthRepository` ينفذ `/api/auth/login/` ثم يحفظ التوكنات في `SecureStorage`.
- بعدها يستدعي `/api/auth/me/` ويحصل على `AuthUser`.
- `AuthInterceptor` يستخدم التوكن تلقائيًا مع باقي الطلبات المحمية.

### 4.2 تدفق dashboard

- `HomeController` أو `StatsController` يستدعيان endpoint `/api/dashboard/`.
- `DashboardView` في الباكند يستدعي `HealthTrackerCoordinator`.
- الـ coordinator يقرأ السجلات اليومية والملف الصحي والنقاط والقيود المزمنة.
- يتم إرجاع payload موحد للفرونت.
- `DashboardData` أو `StatsController` يفككان الاستجابة إلى حالة قابلة للعرض.

### 4.3 تدفق history

- `StatsController` يستدعي `/api/history/`.
- `StatsHistoryView` يطلب history من `HealthTrackerCoordinator`.
- يتم إرجاع سبعة أيام من القيم المجمعة.
- الواجهة تحول الأيام إلى `DayStat` ثم ترسم المخططات والجداول.

### 4.4 تدفق تسجيل وجبة أو ماء أو نوم أو خطوات أو نشاط

- المستخدم يدخل بيانات جديدة في إحدى الشاشات.
- API class في Flutter يرسل POST إلى endpoint المناسب.
- الـ ViewSet في Django يستدعي service مختصة بالكتابة.
- الخدمة تحفظ السجل وتطبق قواعد النقاط.
- عند إعادة تحميل Home أو Stats، تظهر النتائج الجديدة لأن التجميع يعتمد على البيانات المخزنة.

### 4.5 تدفق الحالات المزمنة والأدوية

- المستخدم ينشئ حالة مزمنة من الشاشة.
- `ChronicConditionsApi` يرسل الطلب إلى `UserConditionViewSet`.
- بعد الحفظ، `ConditionIntegrationCoordinator` يعيد بناء الأهداف ويقيّم الحالة.
- `HealthTrackerCoordinator` يقرأ القيود الناتجة ويعكسها في dashboard/history.
- عند إضافة دواء أو تعديل جدول، تتحول الجرعات إلى reminders محلية في Flutter.

### 4.6 تدفق تنفيذ جرعة دواء

- المستخدم يضغط `Taken` أو `Missed` أو `Snooze` أو `Skip` في واجهة التفاصيل.
- `ChronicConditionsController` يستدعي endpoint المناسب.
- `ConditionMedicationService` يحدّث log الجرعة ويعيد الحالة الجديدة.
- `ChronicConditionsController` يحدّث العرض، ويلغي أو يعيد جدولة إشعار snooze محليًا حسب الحالة.

## 5. وظيفة كل مكوّن باختصار شديد

- `users`: إدارة الحساب والملف الصحي والأهداف المشتقة.
- `core.models`: مصدر الحقيقة لبيانات الصحة اليومية والحالات المزمنة.
- `core.views`: طبقة HTTP رفيعة للميزات الصحية العامة.
- `core.chronic_views`: طبقة HTTP رفيعة للحالات المزمنة.
- `HealthTrackerCoordinator`: طبقة التجميع المركزية للقراءة.
- `...LoggingService`: طبقات الكتابة الخاصة بالسجلات اليومية.
- `ConditionIntegrationCoordinator`: مزامنة الأهداف والتقييمات بعد تغيّر الحالة المزمنة.
- `ConditionConstraintEngine`: دمج القيود المزمنة مع الأهداف العامة.
- `BaseTracker` وadapters: توحيد تمثيل trackers على جهة القراءة.
- `PointsService`: تطبيق قواعد النقاط بصورة مركزية.
- `HttpClient/AuthInterceptor`: طبقة الشبكة المشتركة في Flutter.
- `AuthController`: حالة المصادقة typed.
- `HomeController`: تحميل dashboard للواجهة الرئيسية.
- `StatsController`: تحميل dashboard + history للتحليل.
- `ChronicConditionsController`: إدارة دورة حياة الحالات المزمنة في الواجهة مع مزامنة التذكيرات.
- `NotificationsService`: تشغيل التذكيرات المحلية اليومية والمزمنة.

## 6. ملاحظات معمارية مهمة في النسخة الحالية

- الـ trackers موجودة الآن على جهة القراءة فقط، وهذا منطقي لأن وظيفتها هي التوحيد وليس الكتابة.
- خدمات النوم/الماء/الغذاء/الخطوات/النشاط هي command services وليست بديلًا عن trackers.
- الـ dashboard والـ history لهما الآن مصدر تجميع واحد في الباكند، وهذا يقلل الازدواجية.
- الواجهة الأمامية تتبع نمطًا أنظف من السابق: `API/Data -> typed models -> controller -> screen/widgets`.
- شاشة `Score` في Flutter ما تزال placeholder وظيفيًا وليست موديولًا مكتملًا بعد.
- المجلد `Implementation/food_ai_service` لا يظهر في المسار التشغيلي الأساسي الحالي، ويبدو منفصلًا عن تدفق التطبيق الرئيس في هذه النسخة.

## 7. الخلاصة

المشروع منظم حول فكرتين رئيسيتين:

- الكتابة اليومية تمر عبر خدمات متخصصة تحفظ البيانات وتطبق الآثار الجانبية مثل النقاط.
- القراءة المجمعة تمر عبر `HealthTrackerCoordinator` الذي يدمج الملف الصحي والسجلات اليومية والقيود المزمنة في صورة واحدة تصلح للـ dashboard وhistory.

هذا الفصل يعطي المشروع قابلية أعلى للصيانة لأن:

- الـ views تبقى رفيعة.
- قواعد الأعمال تبقى في services/coordinators.
- الواجهة الأمامية تتعامل مع عقود واضحة وموديلات typed.
- طبقة الحالات المزمنة أصبحت قادرة على التأثير في بقية التتبعات بدون نسخ منطق داخل كل شاشة أو endpoint.

## 8. مرفقات مرجعية مقترحة

إذا أردت توسيع التقرير لاحقًا، فهذه أفضل ملفات مرجعية للرجوع السريع:

- `Implementation/vitamate_backend/vitamate_project/urls.py`
- `Implementation/vitamate_backend/core/views.py`
- `Implementation/vitamate_backend/core/chronic_views.py`
- `Implementation/vitamate_backend/core/services/health_tracker_coordinator.py`
- `Implementation/vitamate_backend/core/services/condition_integration_coordinator.py`
- `Implementation/vitamate_backend/core/domain/trackers/base.py`
- `Implementation/vitamate_backend/core/domain/trackers/adapters.py`
- `Implementation/vitamate_backend/users/services/user_profile_service.py`
- `Implementation/vitamate_backend/gamification/services/points_service.py`
- `Implementation/vitamate_frontend/lib/main.dart`
- `Implementation/vitamate_frontend/lib/app.dart`
- `Implementation/vitamate_frontend/lib/core/network/http_client.dart`
- `Implementation/vitamate_frontend/lib/auth/state/auth_controller.dart`
- `Implementation/vitamate_frontend/lib/features/home/state/home_controller.dart`
- `Implementation/vitamate_frontend/lib/features/stats/state/stats_controller.dart`
- `Implementation/vitamate_frontend/lib/features/chronic_conditions/state/chronic_conditions_controller.dart`
