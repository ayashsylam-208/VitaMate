# VitaMate Comprehensive Testing Report

            ## تقرير شامل جداً عن الاختبارات والتحقق في مشروع VitaMate

            **اسم المشروع:** VitaMate  
            **نوع التقرير:** Comprehensive Testing / Verification / Validation Report  
            **لغة التقرير:** العربية  
            **تاريخ توليد التقرير:** `2026-04-22`  
            **المسار الجذري للمشروع:** `C:\Users\Salam Ayash\Desktop\VitaMate`  
            **ملفات المخرجات المرتبطة:**  
            - `VitaMate_Comprehensive_Testing_Report_Source.md`
            - `VitaMate_Comprehensive_Testing_Report_AR.md`
            - `VitaMate_Testing_File_Index.csv`
            - `VitaMate_Comprehensive_Testing_Report_AR.docx`

            ---

            ## صفحة المحتويات

            - 1. ملخص تنفيذي
- 2. تعريف المشروع ومكوناته
- 3. خريطة بنية المشروع والمسارات المهمة
- 4. فلسفة الـ Testing والتحقق في VitaMate
- 5. Unit Testing
- 6. Integration Testing
- 7. Frontend / Widget / UI Testing
- 8. E2E / Flutter Integration Flow Testing
- 9. API Contract Validation
- 10. Performance & Load Testing
- 11. CI/CD and Security Verification
- 12. الأدوات والتقنيات المستخدمة في التحقق والاختبار
- 13. كيفية تشغيل الاختبارات والتفعيل العملي
- 14. النتائج والأدلة الموجودة فعلياً
- 15. دراسة حالة تحسين الأداء
- 16. شرح ملفات الـ Testing واحداً واحداً
- 17. مصفوفة ربط متطلبات التكليف بالتنفيذ
- 18. الفجوات والملاحظات
- 19. الخلاصة والتوصيات
- 20. الملخص النهائي المتوافق مع ملف الطلبات

## 1. ملخص تنفيذي

مشروع **VitaMate** هو مشروع صحة رقمية يجمع بين **Backend** مبني على **Django REST** و**Frontend** مبني على **Flutter**، ويهدف إلى تتبع سلوكيات صحية يومية مثل الماء والخطوات والنوم والنشاط والوجبات، بالإضافة إلى حالات مزمنة مثل السكري وارتفاع الضغط، مع طبقة أدوية وتذكيرات وGamification.

من منظور الاختبار والتحقق، لا يعتمد المشروع على نوع واحد من الفحوصات، بل على **منظومة طبقية** تشمل:

- اختبارات backend business logic وAPI باستخدام Django test runner و`APITestCase`.
- اختبارات frontend للوحدات والمنطق وواجهات Flutter باستخدام `flutter test`.
- اختبارات تكاملية حقيقية على Android emulator باستخدام `integration_test`.
- اختبارات عقود API للتأكد من ثبات بنية JSON المستهلكة من تطبيق Flutter.
- اختبارات أداء وتحميل باستخدام `Locust` على `/api/dashboard/` و`/api/history/`.
- فحوصات أمن وجودة في `pre-commit` و`Gitleaks` و`flutter analyze` و`makemigrations --check`.
- خط CI واضح في GitHub Actions يجمع كل ما سبق في pipeline واحدة.

المؤشرات الكمية التي أمكن استخراجها من المشروع نفسه:

- **Backend test files الرسمية:** `27` ملفاً تنفيذياً.
- **عدد سيناريوهات backend تقريبياً:** `91` سيناريو.
- **Frontend unit/widget test files:** `13` ملفاً.
- **عدد سيناريوهات frontend unit/widget تقريبياً:** `22` سيناريو.
- **Flutter integration test files التنفيذية:** `3` ملفات، فيها `2` سيناريوين رئيسيين.
- **عدد ملفات الفهرس النهائية المرتبطة بالاختبار والجودة:** `70` ملفاً/وثيقة.
- **الملفات المشروحة فردياً داخل هذا التقرير:** `52` ملفاً.
- **الملفات الثانوية المتشابهة المجمعة:** `18` ملفاً.

النتيجة العامة: المشروع يملك **منظومة اختبار وتحقيق ناضجة نسبياً**، مع نقطة تميز واضحة في قسم الأداء بسبب وجود baseline وafter evidence، ولكن هناك أيضاً **فجوة مهمة بالنسبة للتكليف**: لم أجد Playwright فعلياً، بل وجدت `Flutter integration_test` كبديل عملي مناسب لتطبيق Flutter native.

## 2. تعريف المشروع ومكوناته

### 2.1 ما هو VitaMate؟

**VitaMate** هو تطبيق صحة ونمط حياة. فكرته ليست مجرد إدخال بيانات يومية، بل بناء صورة موحدة عن حالة المستخدم الصحية عبر أكثر من بُعد:

- الترطيب: كمية الماء والمشروبات.
- النشاط: الخطوات والتمارين والسعرات المحروقة.
- النوم: ساعات النوم وجودته.
- التغذية: الوجبات والمشروبات والقيم الغذائية.
- الأمراض المزمنة: مثل السكري وارتفاع الضغط وارتفاع الدهون.
- الأدوية: خطط الجرعات، الالتزام، والتنبيهات.
- التحفيز: نقاط ومستويات Gamification.

### 2.2 ما المشكلة التي يحلها؟

كثير من التطبيقات الصحية تعالج كل بعد بمعزل عن الآخر. VitaMate يحاول حل هذه المشكلة عبر:

- جمع السلوك الصحي اليومي في نموذج موحد.
- جعل dashboard وhistory تعكسان أكثر من tracker في نفس الوقت.
- ربط الحالات المزمنة بقيود غذائية وحركية ودوائية.
- جعل الأدوية والحالات المزمنة تؤثر على الملخصات والتنبيهات والالتزام.

### 2.3 ما المكونات الرئيسية؟

المشروع مقسوم إلى مكونين أساسيين:

1. **Backend**: مسؤول عن قواعد العمل، تخزين البيانات، واجهات API، التقييمات المزمنة، قيود trackers، وتجميع dashboard/history.
2. **Frontend**: تطبيق Flutter يعرض هذه البيانات، يدير التفاعل مع المستخدم، ويشغل التذكيرات المحلية وبعض اختبارات الواجهة والتكامل.

### 2.4 ما التقنيات المستخدمة؟

الأدوات الفعلية التي ظهرت في المشروع:

- **Django 5 + Django REST Framework** في backend.
- **Flutter** في frontend.
- **SimpleJWT** للمصادقة بالتوكنات.
- **PostgreSQL** في CI والأداء كقاعدة البيانات الرسمية للاختبارات الثقيلة.
- **Flutter test / integration_test** لاختبارات الواجهة.
- **Locust** لاختبارات الأداء.
- **GitHub Actions** للتشغيل الآلي.
- **pre-commit** و**Gitleaks** للجودة والأمان.

### 2.5 كيف يتوزع المشروع بين backend وfrontend؟

- المسار `Implementation/vitamate_backend` يحتوي backend الفعلي: API، services، repositories، management commands، واختبارات Django.
- المسار `Implementation/vitamate_frontend` يحتوي تطبيق Flutter: الشاشات، controllers، APIs، واختبارات widget/unit/integration.
- المسار `Implementation/docs/performance` يحتوي evidence الأداء الرسمية.
- المسار `.github/workflows` يحتوي تعريف الـ CI.

## 3. خريطة بنية المشروع والمسارات المهمة

قبل الدخول في الاختبارات نفسها، من المهم شرح أدوار المسارات حتى يفهم القارئ الخارجي أين يبحث عن كل نوع تحقق:

| المسار | الدور |
| --- | --- |
| `README.md` | نقطة الدخول التوثيقية للمشروع، وفيها أوامر الاختبار المحلية وشرح الـ CI. |
| `.github/workflows/ci.yml` | خط التشغيل الآلي في GitHub Actions. |
| `.pre-commit-config.yaml` | سياسة الجودة المحلية قبل الدمج. |
| `.gitleaks.toml` و`.gitleaksignore` | ضبط فحص التسريبات السرية. |
| `Implementation/vitamate_backend` | Backend Django REST: القواعد، الـ API، management commands، واختبارات backend. |
| `Implementation/vitamate_backend/core/tests` | القسم الأضخم من اختبارات backend الوظيفية والعقدية والتكاملية. |
| `Implementation/vitamate_backend/users/tests` | اختبارات auth/profile. |
| `Implementation/vitamate_backend/gamification/tests` | اختبارات gamification/points. |
| `Implementation/vitamate_backend/loadtest` | تعريفات Locust الرسمية. |
| `Implementation/vitamate_backend/core/management/commands` | أوامر seed الخاصة بالاختبار والأداء. |
| `Implementation/vitamate_frontend/test` | اختبارات Flutter unit/widget/controller. |
| `Implementation/vitamate_frontend/integration_test` | الاختبارات التكاملية التي تشغل التطبيق الحقيقي على emulator. |
| `Implementation/vitamate_frontend/test_driver` | driver المطلوب لـ `flutter drive`. |
| `Implementation/docs/performance` | before/after CSVs والتقارير النصية. |

من الناحية الهندسية، البنية تقول شيئاً مهماً: **الاختبار في VitaMate ليس مجلداً واحداً**، بل شبكة موزعة عبر config + code + docs + evidence.

## 4. فلسفة الـ Testing والتحقق في VitaMate

عند قراءة المشروع ككل، تظهر فلسفة تحقق متعددة الطبقات:

### 4.1 Verification

التحقق هنا يعني: هل كل طبقة بُنيت كما ينبغي؟

- هل business logic في backend صحيحة؟ هذا تغطيه suites مثل `test_constraints.py` و`test_points.py`.
- هل endpoints ترجع payloads ثابتة؟ هذا تغطيه `test_api_contracts.py` و`api_contract_baseline.md`.
- هل frontend controllers تتعامل مع الأخطاء والحالات المتوقعة؟ هذا تغطيه اختبارات Flutter unit/widget.
- هل pipeline نفسها تمنع الأسرار والكسور البنيوية؟ هذا تغطيه `ci.yml` و`pre-commit` و`gitleaks`.

### 4.2 Validation

التحقق من القيمة الفعلية للمستخدم النهائي يظهر أساساً في:

- `chronic_flow_test.dart`: لأنه يشغل رحلة مستخدم حقيقية من login حتى ظهور أثر الحالة المزمنة في الواجهة.
- `smoke_login_home_test.dart`: لأنه يتأكد أن التطبيق يصل إلى Home ويعرض أقسامه الحرجة.
- تقارير الأداء: لأنها تجيب سؤالاً عملياً، هل endpoints الأساسية سريعة بما يكفي للاستخدام الحقيقي؟

### 4.3 لماذا هذه الطبقات معاً؟

لأن المشروع يجمع بين صحة يومية، حالات مزمنة، وأدوية. في هذا النوع من الأنظمة، الخطأ ليس مجرد bug بصري؛ يمكن أن يكون:

- Contract مكسور يوقف التطبيق.
- حساب التزام دوائي خاطئ.
- بطء شديد في dashboard/history يجعل الشاشة غير قابلة للاستخدام.
- تسريب secret أو كسر في CI يمنع الاستقرار.

لهذا السبب بنية التحقق هنا موزعة بين:

- **Unit / service-level tests**
- **API and integration tests**
- **Widget/UI tests**
- **Flutter integration tests**
- **Performance evidence**
- **CI/security gates**

## 5. Unit Testing

### 5.1 الهدف

هذا المستوى يختبر منطق الوحدات والخدمات بصورة مباشرة نسبياً، مع أقل قدر ممكن من التعقيد الخارجي. في VitaMate يظهر هذا في backend وfrontend معاً.

### 5.2 أين يوجد؟

- Backend: `Implementation/vitamate_backend/core/tests`, `Implementation/vitamate_backend/users/tests`, `Implementation/vitamate_backend/gamification/tests`
- Frontend: `Implementation/vitamate_frontend/test`

### 5.3 كيف يتم تشغيله؟

```bash
cd Implementation/vitamate_backend
python manage.py test users core gamification --verbosity 1
```

```bash
cd Implementation/vitamate_frontend
flutter test
```

### 5.4 ما الذي يتحقق منه تحديداً؟

في backend:

- حساب النقاط والمستوى.
- قيود الحالات المزمنة.
- upsert للخطوات.
- حساب مدة النوم.
- حساب الحرق في النشاط.
- profile metrics.

في frontend:

- AuthController وحالات login.
- token refresh interceptor.
- تخزين التوكن.
- سلوك controllers مثل الماء والتغذية والأدوية والحالات المزمنة.
- أجزاء من widget behavior مثل login screen وpermission UI.

### 5.5 الأدوات المستخدمة

- Backend: Django test runner + `TestCase` / `APITestCase`
- Frontend: `flutter_test`

### 5.6 الأدلة الكمية

- **Backend suites التنفيذية:** `27` ملفات.
- **Backend test scenarios تقريبياً:** `91`.
- **Frontend unit/widget suites:** `13` ملفات.
- **Frontend unit/widget scenarios تقريبياً:** `22`.

### 5.7 نقاط القوة

- التغطية لا تقتصر على happy path.
- توجد edge cases واضحة مثل uniqueness، read-only computed fields، permission-denied UI، وتوثيق gap معروف في `test_auth.py`.
- توجد factories ومساعدات مشتركة تقلل الضوضاء وتزيد قابلية صيانة الاختبارات.

### 5.8 القيود والملاحظات

- لم أجد coverage report ملتزماً في الريبو.
- runner الرسمي في backend هو Django test runner، وليس `pytest`، رغم وجود `.pytest_cache` محلياً داخل workspace.

## 6. Integration Testing

### 6.1 الهدف

هذا المستوى يتأكد أن المكونات تتكامل فعلاً: endpoint مع قاعدة البيانات، service مع repository، أو frontend مع backend الحقيقي.

### 6.2 أين يوجد؟

في VitaMate يظهر هذا في شكلين:

- اختبارات Django التي تضرب endpoints حقيقية وتقرأ من قاعدة البيانات.
- Flutter integration tests التي تشغل التطبيق الحقيقي ضد backend Django حي.

### 6.3 أمثلة backend integration

- `test_api_contracts.py`
- `test_chronic_conditions.py`
- `test_medications.py`
- `test_water.py`
- `test_nutrition.py`
- `test_health_state_orchestration.py`

هذه الملفات لا تختبر function منعزلة فقط؛ بل تختبر سلوك API وقاعدة البيانات وتفاعل أكثر من طبقة في وقت واحد.

### 6.4 أمثلة frontend integration

- `smoke_login_home_test.dart`
- `chronic_flow_test.dart`

### 6.5 نقاط القوة

- الاعتماد على backend حقيقي في اختبارات Flutter integration.
- وجود أوامر seed رسمية reproducible قبل الاختبارات.
- وجود اختبارات backend تحقق contract وسلامة ownership في الوقت نفسه.

### 6.6 القيود

- E2E UI موجودة، لكن ليست Playwright حرفياً.
- لم أجد ملفات execution logs ملتزمة في git لهذه الاختبارات، لذلك evidence التشغيل الموثق داخل الريبو أقوى في الأداء من integration.

## 7. Frontend / Widget / UI Testing

### 7.1 لماذا هو مهم هنا؟

لأن frontend في VitaMate لا يعرض بيانات فقط، بل يدير:

- login/auth state
- permission handling
- optimistic and non-optimistic controller state
- chronic flow UI
- medication reminders sync

### 7.2 الملفات الأهم

- `auth_flow_test.dart`
- `auth_interceptor_test.dart`
- `steps_permission_ui_test.dart`
- `chronic_conditions_screen_test.dart`
- `medications_controller_test.dart`
- `nutrition_controller_test.dart`
- `water_controller_test.dart`

### 7.3 ما الذي يتم التحقق منه؟

- validators والتنقل بين الشاشات
- token refresh behavior
- ظهور رسائل permission الصحيحة
- parsing للـ dashboard/chronic/medication payloads
- مزامنة reminders
- تفاعل الماء والتغذية مع حدود السكر لمرضى السكري

### 7.4 نقاط القوة

- استخدام Fake APIs وFake adapters بدلاً من شبكة حقيقية في طبقة widget/unit، وهذا يجعل الاختبارات أسرع وأقل هشاشة.
- عزل plugin channels في الاختبارات التي تحتاج ذلك، خصوصاً secure storage وlocal notifications.

### 7.5 ملاحظات

- هذا المستوى لا يحل محل integration tests، بل يسبقها ويعزل الأعطال بسرعة أكبر.

## 8. E2E / Flutter Integration Flow Testing

### 8.1 ماذا يوجد فعلياً؟

الموجود فعلياً في المشروع هو **Flutter `integration_test`**، وليس Playwright.

هذا مهم جداً لأن التكليف الجامعي طلب Playwright حرفياً، لكن الكود الموجود يوضح أن الفريق اختار أداة Flutter الأصلية لأن التطبيق **تطبيق Flutter native** وليس تطبيق ويب.

### 8.2 الملفات الأساسية

- `Implementation/vitamate_frontend/integration_test/test_helpers.dart`
- `Implementation/vitamate_frontend/integration_test/smoke_login_home_test.dart`
- `Implementation/vitamate_frontend/integration_test/chronic_flow_test.dart`
- `Implementation/vitamate_frontend/test_driver/integration_test.dart`
- `Implementation/vitamate_frontend/lib/bootstrap.dart`
- `Implementation/vitamate_frontend/lib/core/testing/app_test_keys.dart`

### 8.3 السيناريوهات الموجودة

1. **Smoke Login/Home**
   - فتح التطبيق
   - login
   - انتظار Home
   - التحقق من `Daily Health Score`
   - التحقق من وجود زر Conditions Center

2. **Chronic Hypertension Flow**
   - login
   - فتح Conditions Center
   - إضافة Hypertension
   - إضافة reading جديدة
   - التحقق من summary card وقائمة القراءات
   - الرجوع إلى Home والتحقق من اختفاء empty state

### 8.4 كيف تُشغّل؟

```bash
cd Implementation/vitamate_backend
python manage.py migrate
python manage.py seed_integration_user --scenario chronic_flow --reset
python manage.py runserver 0.0.0.0:8000
```

```bash
cd Implementation/vitamate_frontend
flutter pub get
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/smoke_login_home_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/chronic_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 8.5 الحكم التحليلي

- من **الناحية التقنية**: هذا E2E حقيقي وقوي.
- من **ناحية مطابقة نص التكليف**: هذا لا يحقق Playwright حرفياً، وبالتالي يجب وصفه في المصفوفة لاحقاً كـ **جزئي بالنسبة لمتطلب الأداة**.

## 9. API Contract Validation

VitaMate لا يكتفي بالتحقق من status codes. المشروع يملك طبقتين واضحتين لعقود API:

1. **اختبارات تنفيذية** في `test_api_contracts.py`
2. **وثيقة baseline مرجعية** في `api_contract_baseline.md`

### لماذا هذا مهم؟

لأن تطبيق Flutter يعتمد على بنية JSON معينة. إذا تغيّر المفتاح أو شكل العنصر، قد ينهار التطبيق حتى لو endpoint ما زالت ترجع `200 OK`.

### ما العقود المراقبة فعلياً؟

- `GET /api/auth/me/`
- `GET /api/dashboard/`
- `GET /api/history/`
- `POST /api/water/`
- `POST /api/steps/`
- `POST /api/sleep/`
- `POST /api/activities/`
- `POST /api/meals/`

### نقاط القوة

- وجود حد أدنى واضح للمفاتيح المطلوبة.
- توثيق نصي + اختبارات قابلة للتنفيذ.
- ربط chronic summary أيضاً بـ dashboard/history contract.

### القيود

- العقد يركز على بنية payload، لا على schema formal مثل OpenAPI contract testing tool.

## 10. Performance & Load Testing

### 10.1 الهدف

التحقق من سلوك endpoints الحرجة تحت حمل متكرر، وليس فقط تحت طلب واحد يدوي.

### 10.2 الأداة

الأداة الرسمية هنا هي **Locust**، وهي مثبتة في `requirements.txt` ومستخدمة عبر `loadtest/locustfile.py`.

### 10.3 السيناريوهات الرسمية

- `LOCUST_SCENARIO=dashboard` ثم `GET /api/dashboard/`
- `LOCUST_SCENARIO=history` ثم `GET /api/history/`

وفي الحالتين هناك login و`/api/auth/me/` كخطوة تمهيدية حتى يصبح الحمل ممثلاً لمستخدم موثق، لا لطلب عام مجهول.

### 10.4 Dataset

أمر `seed_performance_dataset` يزرع:

- pool مستخدمين ثابتة (`locust0` .. `locust39`)
- UserProfile صالح لكل مستخدم
- 7 أيام على الأقل من water / steps / sleep / meals / activities
- حالات مزمنة
- أدوية وجداول وسجلات وتقييمات

### 10.5 أوامر التشغيل الرسمية

```powershell
cd Implementation/vitamate_backend
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_performance_dataset --profile representative --reset
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

```powershell
$env:LOCUST_SCENARIO="dashboard"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\docs\performance\before\dashboard --only-summary
```

```powershell
$env:LOCUST_SCENARIO="history"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\docs\performance\before\history --only-summary
```

### 10.6 النتائج الأساسية

| Endpoint | Avg Before ms | Avg After ms | التحسن % | P95 Before ms | P95 After ms | RPS Before | RPS After | Failures Before | Failures After |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `/api/dashboard/` | 355.85 | 142.82 | 59.87% | 720 | 240 | 8.40 | 9.12 | 0 | 0 |
| `/api/history/` | 5261.65 | 817.39 | 84.47% | 6400 | 1500 | 2.68 | 7.02 | 0 | 0 |

### 10.7 القراءة السريعة

- `history` كان أبطأ بكثير من `dashboard` قبل التحسين.
- بعد التحسين، ما يزال `history` أبطأ، لكنه لم يعد في نطاق الثواني المتعددة كما كان.
- `dashboard` تحسن أيضاً، لكن أثر التحسين الأكبر كان على `history`.

## 11. CI/CD and Security Verification

### 11.1 ماذا يفعل الـ CI؟

ملف `ci.yml` يبني pipeline من ستة jobs صريحة:

- `gitleaks`
- `pre-commit`
- `backend-tests`
- `flutter-analyze`
- `flutter-test`
- `flutter-integration-test`

### 11.2 كيف نتحقق من backend؟

عبر:

- `python manage.py makemigrations --check --dry-run`
- `python manage.py migrate --noinput`
- `python manage.py test users core gamification`

### 11.3 كيف نتحقق من frontend؟

عبر:

- `flutter analyze`
- `flutter test`
- `flutter drive` للاختبارات التكاملية

### 11.4 كيف نتحقق من الأمان؟

- `Gitleaks` داخل CI
- `Gitleaks` داخل `pre-commit`
- فحوصات merge conflicts وprivate keys قبل الدمج

### 11.5 كيف نتحقق من الجودة قبل الدمج؟

- developer محلياً يشغل `pre-commit run --all-files`
- CI يعيد تشغيل نفس الفكرة مركزياً
- Flutter static analysis موجود كمرحلة مستقلة
- migration drift مغطى بـ `makemigrations --check`

### 11.6 evidence الفعلية داخل الريبو

الموجود المؤكد داخل الريبو هو **تعريف pipeline نفسها**، لكن:

- لم أجد badge CI في README.
- لم أجد screenshots أو log exports ملتزمة في git تثبت run أخضر/أحمر بعينه.

لذلك من المهم التفريق بين:

- **وجود آلية CI**: نعم، موجودة بوضوح.
- **وجود evidence تاريخية ملتزمة لتنفيذ CI**: لم أجدها داخل الريبو نفسه.

## 12. الأدوات والتقنيات المستخدمة في التحقق والاختبار

| الأداة | لماذا استُخدمت؟ | كيف تُشغّل؟ | أين تدخل في الـ workflow؟ | ما الذي تكشفه؟ |
| --- | --- | --- | --- | --- |
| Django test runner | runner الرسمي لاختبارات backend | `python manage.py test ...` | محلياً وداخل CI | أخطاء business logic وAPI والتكامل مع DB |
| `APITestCase` | لاختبار endpoints الحقيقية | ضمن Django tests | backend suites | صحة الاستجابات والعقود والصلاحيات |
| `flutter_test` | لاختبارات unit/widget/controller في Flutter | `flutter test` | محلياً وداخل CI | regressions في الواجهة والمنطق |
| `integration_test` | لاختبارات Flutter التكاملية الحقيقية | `flutter drive ...` | محلياً وداخل CI | رحلات مستخدم كاملة ضد backend حقيقي |
| `Locust` | لقياس الحمل والأداء | `locust -f loadtest/locustfile.py ...` | محلياً في baseline/after | زمن الاستجابة، throughput، الفشل، bottlenecks |
| `GitHub Actions` | لتجميع خطوات التحقق آلياً | عبر push/PR/workflow_dispatch | CI المركزي | كسر build أو quality gate |
| `Gitleaks` | لاكتشاف الأسرار المسربة | داخل `pre-commit` وCI | قبل الدمج وداخل pipeline | كلمات مرور/مفاتيح/توكنات مسربة |
| `pre-commit` | لتشغيل hooks المحلية | `pre-commit run --all-files` | محلياً قبل commit | مشاكل صياغة وأمن مبكرة |
| `flutter analyze` | تحليل ساكن لكود Flutter | `flutter analyze` | محلياً وداخل CI | linting/static issues |
| `makemigrations --check` | كشف drift في migrations | `python manage.py makemigrations --check --dry-run` | backend CI | تغييرات models غير المهاجرة |
| management commands الخاصة بالـ seed | تجهيز بيانات reproducible | `seed_integration_user` و`seed_performance_dataset` | قبل integration/performance | اتساق setup وقابلية الإعادة |

ملاحظة مهمة: لم أجد `pytest` runner أو Playwright tests حقيقية داخل المشروع. لذلك لم أقدمها كأدوات مستخدمة فعلاً، بل ذكرتها فقط عند مقارنة المشروع مع التكليف.

## 13. كيفية تشغيل الاختبارات والتفعيل العملي

### 13.1 Backend

```bash
cd Implementation/vitamate_backend
python manage.py makemigrations --check --dry-run
python manage.py test users core gamification --verbosity 1
```

### 13.2 Frontend

```bash
cd Implementation/vitamate_frontend
flutter pub get
flutter analyze
flutter test
```

### 13.3 Flutter integration tests

```bash
cd Implementation/vitamate_backend
python manage.py migrate
python manage.py seed_integration_user --scenario chronic_flow --reset
python manage.py runserver 0.0.0.0:8000
```

```bash
cd Implementation/vitamate_frontend
flutter pub get
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/smoke_login_home_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/chronic_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 13.4 Performance / Load

```powershell
cd Implementation/vitamate_backend
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_performance_dataset --profile representative --reset
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

```powershell
$env:LOCUST_SCENARIO="dashboard"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\docs\performance\before\dashboard --only-summary
```

```powershell
$env:LOCUST_SCENARIO="history"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\docs\performance\before\history --only-summary
```

### 13.5 pre-commit والأمان

```bash
pip install pre-commit
pre-commit install
git add -A
pre-commit run --all-files --show-diff-on-failure
```

### 13.6 متطلبات البيئة

- Backend يعتمد افتراضياً على **PostgreSQL** كما يظهر في `.env.example` وCI.
- يوجد تعليق يوضح **SQLite fallback** محلياً عبر `VITAMATE_USE_SQLITE=1` عند الحاجة.
- Flutter integration tests تحتاج Android emulator لأن عنوان الـ backend يكون `http://10.0.2.2:8000`.

## 14. النتائج والأدلة الموجودة فعلياً

هذا القسم يلتزم حرفياً بما وُجد داخل المشروع أو في الوثائق الموجودة فيه.

### 14.1 أدلة الأداء الموجودة

الأدلة الملتزمة داخل المشروع:

- `Implementation/docs/performance/baseline_notes.md`
- `Implementation/docs/performance/performance_report.md`
- ملفات CSV before/after في `Implementation/docs/performance/before` و`Implementation/docs/performance/after`

### 14.2 ملخص النتائج الرقمية المؤكدة

| Endpoint | Avg Before | Avg After | P95 Before | P95 After | RPS Before | RPS After | Failures Before | Failures After |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `/api/dashboard/` | 355.85 ms | 142.82 ms | 720 ms | 240 ms | 8.40 | 9.12 | 0 | 0 |
| `/api/history/` | 5261.65 ms | 817.39 ms | 6400 ms | 1500 ms | 2.68 | 7.02 | 0 | 0 |

### 14.3 ما الذي لم أجده؟

- لم أجد coverage report ملتزماً في git.
- لم أجد badge أو screenshot لآخر CI run داخل README أو docs.
- لم أجد Playwright test files فعلية.
- لم أجد JUnit/XML test reports ملتزمة داخل الريبو.

### 14.4 كيف أتعامل مع هذا في التقييم؟

هذا لا يعني أن الاختبارات غير موجودة؛ بل يعني أن **evidence التنفيذ الملتزم** أقوى في performance من بقية الأقسام، بينما بقية الأقسام مدعومة أكثر بوجود الكود وتعريفات التشغيل والـ CI workflow نفسها.

## 15. دراسة حالة تحسين الأداء

### 15.1 ما كانت المشكلة؟

الوثائق والأرقام تؤكد أن `GET /api/history/` كان عنق الزجاجة الأكبر. قبل التحسين كان:

- متوسطه حوالي **5261.65 ms**
- P95 حوالي **6400 ms**
- throughput حوالي **2.68 RPS**

بالمقارنة، كان `/api/dashboard/` أبطأ من المطلوب لكنه أقل حدة بكثير.

### 15.2 أين كان البطء؟

من `performance_report.md` ومن اختبارات orchestration والملفات الإنتاجية، المشكلة كانت في:

- fallback path في `history` كان يعيد بناء projection كامل لكل يوم ثم يقتطع `history_entry` فقط.
- تحميل القيود active constraints أكثر من مرة داخل الطلب.
- إعادة حساب target values من خلال queries متكررة.
- تكرار حساب ملخص الأدوية اليومي بدلاً من مسار واحد مجمع.
- تضخيم reads الخاصة بالحالات المزمنة والrule profiles والأهداف.

### 15.3 ما الذي تغير؟

- إدخال `build_history_entry()` الخفيف.
- تجهيز context موحد عبر `prepare_context()`.
- إنشاء `ActiveConstraintBundle` لإعادة استخدام القيود.
- إدخال `effective_numeric_value_from_constraints()` لاستعمال القيود المحمّلة مسبقاً.
- دمج عدّ الجرعات عبر `today_dose_counts()`.
- إضافة `schedules_for_user_on_date()` مع prefetch للسجلات اليومية.

### 15.4 لماذا تحسن `history` أكثر من `dashboard`؟

لأن المشكلة الأصلية كانت مرتبطة أكثر بمسار fallback التاريخي على مدى 7 أيام. كل يوم كان يحمل overhead إضافياً. عندما تم استبدال projection الكامل لكل يوم بمسار أخف:

- انخفض العمل المتكرر بشكل جذري.
- انخفضت قراءة القيود والملفات المزمنة والأدوية.
- صار المسار أقرب إلى payload المطلوب فعلاً من `/api/history/`.

### 15.5 النتيجة النهائية

- تحسن متوسط `/api/dashboard/` بحوالي **59.87%**.
- تحسن متوسط `/api/history/` بحوالي **84.47%**.
- لم تُسجل failures على endpoint target في before أو after حسب CSVs الرسمية.

### 15.6 كيف نعرف أن العقد لم تنكسر؟

يوجد coupling واضح بين تحسين الأداء والحفاظ على العقد عبر:

- `test_api_contracts.py`
- `api_contract_baseline.md`
- `test_health_state_orchestration.py`

أي أن التحسين لم يكن مجرد tuning، بل جرى ضبطه باختبارات انحدار تحمي شكل البيانات وسلوك orchestration.

### ملفات الإنتاج التي تحمل أثر التحسين
التقرير لا يشرح فقط Locust والوثائق، بل يوضح أيضاً أين تغيّر مسار القراءة نفسه داخل الكود الإنتاجي:

| الملف | المسار الكامل | أثر التعديل |
| --- | --- | --- |
| `health_tracker_coordinator.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\tracking\health_tracker_coordinator.py` | حوّل fallback الخاص بـ history إلى استدعاء `build_history_entry()` الخفيف بدلاً من بناء projection كامل لكل يوم. |
| `health_state_projection_service.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\orchestration\health_state_projection_service.py` | أضاف `prepare_context()` و`_build_constraint_bundle()` لإعادة استخدام القيود والسياق المشترك على مستوى الطلب الواحد. |
| `health_state_projection_service.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\orchestration\health_state_projection_service.py` | أدخل `build_history_entry()` ليحسب فقط ما يحتاجه `/api/history/` بدل payload projection الكامل. |
| `condition_constraint_engine.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\chronic\condition_constraint_engine.py` | حضّر rule profiles وeffective targets دفعة واحدة لإزالة أعمال متكررة وملامح N+1 في المسار المزمن. |
| `constraint_read_service.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\constraints\constraint_read_service.py` | أضاف `effective_numeric_value_from_constraints()` لاستثمار القيود المحمّلة مسبقاً بدل query جديد لكل قيمة. |
| `condition_medication_service.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\chronic\condition_medication_service.py` | استبدل إعادة بناء قوائم الجرعات مرتين بمسار `today_dose_counts()` الواحد لحساب total/pending في مرور واحد. |
| `medication_repository.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\repositories\medication\medication_repository.py` | أضاف `schedules_for_user_on_date()` مع prefetch للسجلات اليومية لتقليل استعلامات الأدوية. |
| `medication_adherence_service.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\medication\medication_adherence_service.py` | حوّل تلخيص counts اليومية إلى مسار يعتمد على logs اليومية المحمّلة مرة واحدة ثم يعدّ الحالات في الذاكرة. |

#### `health_tracker_coordinator.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\tracking\health_tracker_coordinator.py`
- **الدور في التحسين:** حوّل fallback الخاص بـ history إلى استدعاء `build_history_entry()` الخفيف بدلاً من بناء projection كامل لكل يوم.
```python
0067:     def build_history(self, *, user, today: date | None = None, days: int = 7) -> list[dict] | None:
0068:         today = today or date.today()
0069:         start = today - timedelta(days=max(days - 1, 0))
0070:         state_by_date = {
0071:             item.state_date: item
0072:             for item in self._state_reader.list_daily_states(
0073:                 user=user,
0074:                 start_date=start,
0075:                 end_date=today,
0076:             )
0077:         }
0078:         prepared_context = self._projection_service.prepare_context(user=user)
0079:         if prepared_context is None:
0080:             return None
0081: 
0082:         history = []
0083:         for offset in range(days):
0084:             state_date = start + timedelta(days=offset)
0085:             state = state_by_date.get(state_date)
0086:             if state is not None:
0087:                 entry = dict(state.progress_summary.get("history_entry") or {})
0088:                 if entry:
0089:                     history.append(entry)
0090:                     continue
0091: 
0092:             fallback = self._projection_service.build_history_entry(
0093:                 user=user,
0094:                 state_date=state_date,
0095:                 prepared_context=prepared_context,
0096:             )
0097:             if fallback is None:
0098:                 return None
0099:             history.append(dict(fallback))
0100: 
```

هذا المقتطف مهم لأنه يبين أن التحسين لم يكن superficial tuning، بل تغييراً في read path نفسه أو في طريقة إعادة استخدام البيانات المحمّلة مسبقاً.

#### `health_state_projection_service.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\orchestration\health_state_projection_service.py`
- **الدور في التحسين:** أضاف `prepare_context()` و`_build_constraint_bundle()` لإعادة استخدام القيود والسياق المشترك على مستوى الطلب الواحد.
```python
0442:     def prepare_context(self, *, user) -> dict | None:
0443:         try:
0444:             profile = DashboardReadRepository.get_profile(user)
0445:         except UserProfile.DoesNotExist:
0446:             return None
0447:         return {
0448:             "profile": profile,
0449:             "constraint_bundle": self._build_constraint_bundle(user=user),
0450:             "condition_context": self._condition_constraint_engine.prepare_context(user=user),
0451:         }
0452: 
0453:     def _effective_numeric_constraint_from_bundle(
0454:         self,
0455:         *,
0456:         constraint_bundle: ActiveConstraintBundle,
0457:         tracker_type: str,
0458:         metric_key: str,
0459:         fallback,
0460:     ):
0461:         value = ConstraintReadService.effective_numeric_value_from_constraints(
0462:             constraints=constraint_bundle.metric_lookup.get((tracker_type, metric_key), []),
0463:             fallback=fallback,
0464:         )
0465:         return fallback if value is None else value
0466: 
0467:     def _build_constraint_bundle(self, *, user) -> ActiveConstraintBundle:
0468:         grouped_summary: dict[str, list[dict]] = defaultdict(list)
0469:         metric_lookup: dict[tuple[str, str], list] = defaultdict(list)
0470:         for constraint in ConstraintReadService.active_for_user(user=user):
0471:             grouped_summary[constraint.tracker_type].append(
0472:                 ConstraintReadService.serialize_constraint(constraint)
0473:             )
0474:             metric_lookup[(constraint.tracker_type, constraint.metric_key)].append(constraint)
0475:         return ActiveConstraintBundle(
0476:             summary=dict(grouped_summary),
0477:             metric_lookup=dict(metric_lookup),
0478:         )
```

هذا المقتطف مهم لأنه يبين أن التحسين لم يكن superficial tuning، بل تغييراً في read path نفسه أو في طريقة إعادة استخدام البيانات المحمّلة مسبقاً.

#### `health_state_projection_service.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\orchestration\health_state_projection_service.py`
- **الدور في التحسين:** أدخل `build_history_entry()` ليحسب فقط ما يحتاجه `/api/history/` بدل payload projection الكامل.
```python
0316:     def build_history_entry(
0317:         self,
0318:         *,
0319:         user,
0320:         state_date: date,
0321:         prepared_context: dict | None = None,
0322:     ) -> dict | None:
0323:         context = prepared_context or self.prepare_context(user=user)
0324:         if context is None:
0325:             return None
0326:         profile = context["profile"]
0327:         constraint_bundle = context["constraint_bundle"]
0328: 
0329:         effective_constraints = self._condition_constraint_engine.build_effective_constraints(
0330:             user=user,
0331:             profile=profile,
0332:             on_date=state_date,
0333:             prepared_context=context["condition_context"],
0334:         )
0335:         calories_target = int(
0336:             self._effective_numeric_constraint_from_bundle(
0337:                 constraint_bundle=constraint_bundle,
0338:                 tracker_type="nutrition",
0339:                 metric_key="calories_kcal",
0340:                 fallback=effective_constraints.calories_target,
0341:             )
0342:         )
0343:         water_target_liters = float(
0344:             self._effective_numeric_constraint_from_bundle(
0345:                 constraint_bundle=constraint_bundle,
0346:                 tracker_type="hydration",
0347:                 metric_key="daily_water_liters",
0348:                 fallback=effective_constraints.water_target_liters,
0349:             )
0350:         )
0351:         steps_target = int(
0352:             self._effective_numeric_constraint_from_bundle(
0353:                 constraint_bundle=constraint_bundle,
0354:                 tracker_type="steps",
0355:                 metric_key="steps_count",
0356:                 fallback=effective_constraints.step_target,
0357:             )
0358:         )
0359:         burn_target = int(
0360:             self._effective_numeric_constraint_from_bundle(
0361:                 constraint_bundle=constraint_bundle,
0362:                 tracker_type="activity",
0363:                 metric_key="calories_burned",
0364:                 fallback=effective_constraints.burn_target,
0365:             )
0366:         )
0367:         sleep_goal_hours = float(
0368:             self._effective_numeric_constraint_from_bundle(
0369:                 constraint_bundle=constraint_bundle,
0370:                 tracker_type="sleep",
0371:                 metric_key="sleep_hours",
0372:                 fallback=profile.recommended_sleep_hours,
0373:             )
0374:         )
0375: 
0376:         meals = list(DashboardReadRepository.meal_logs_on_date(user=user, log_date=state_date))
0377:         nutrition_totals = NutritionService.summarize_meal_logs(meals)
0378:         calories_in = int(round(nutrition_totals["calories_kcal"]))
0379: 
0380:         activities = list(DashboardReadRepository.activity_logs_on_date(user=user, log_date=state_date))
0381:         exercise_burn = sum(activity.calories_burned for activity in activities)
0382:         exercise_minutes = sum(activity.duration_minutes for activity in activities)
0383:         exercise_count = len(activities)
0384: 
0385:         steps_log = DashboardReadRepository.step_log_on_date(user=user, log_date=state_date)
0386:         if steps_log is None:
0387:             steps_log = StepLog(user=user, date=state_date, steps_count=0, distance_km=0)
0388:         steps_burn = int((steps_log.steps_count or 0) * 0.04)
0389:         steps_burn_rate = 0
0390:         if steps_log.distance_km:
```

هذا المقتطف مهم لأنه يبين أن التحسين لم يكن superficial tuning، بل تغييراً في read path نفسه أو في طريقة إعادة استخدام البيانات المحمّلة مسبقاً.

#### `condition_constraint_engine.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\services\chronic\condition_constraint_engine.py`
- **الدور في التحسين:** حضّر rule profiles وeffective targets دفعة واحدة لإزالة أعمال متكررة وملامح N+1 في المسار المزمن.
```python
0123:     @classmethod
0124:     def prepare_context(cls, *, user) -> dict:
0125:         conditions = cls._active_conditions(user)
0126:         return {
0127:             "conditions": conditions,
0128:             "rule_profiles": cls._rule_profiles_for_conditions(conditions),
0129:             "effective_targets": [cls._effective_target_map(condition) for condition in conditions],
0130:         }
0131: 
0132:     @classmethod
0133:     def build_effective_constraints(
0134:         cls,
0135:         *,
0136:         user,
0137:         profile,
0138:         on_date: date | None = None,
0139:         prepared_context: dict | None = None,
0140:     ) -> EffectiveConditionConstraints:
0141:         on_date = on_date or date.today()
0142:         prepared_context = prepared_context or {}
0143:         conditions = prepared_context.get("conditions")
0144:         if conditions is None:
0145:             conditions = cls._active_conditions(user)
0146:         if not conditions:
0147:             return EffectiveConditionConstraints(
0148:                 calories_target=profile.daily_calorie_target,
0149:                 water_target_liters=profile.daily_water_target,
0150:                 step_target=profile.daily_step_goal,
0151:                 burn_target=profile.daily_burn_goal,
0152:                 exercise_intensity_mode="standard",
0153:                 applied_summaries=(),
0154:                 active_condition_labels=(),
0155:                 medication_count_today=0,
0156:                 pending_doses_today=0,
0157:                 adherence_percent=0.0,
0158:             )
0159: 
0160:         severity_rank = max(cls._severity_rank(condition) for condition in conditions)
0161:         rule_profiles = prepared_context.get("rule_profiles")
0162:         if rule_profiles is None:
0163:             rule_profiles = cls._rule_profiles_for_conditions(conditions)
0164:         condition_slugs = {
0165:             ConditionCatalogService.canonical_slug(condition.condition_type)
0166:             for condition in conditions
0167:         }
0168:         labels = tuple(ConditionCatalogService.display_name(condition.condition_type) for condition in conditions)
0169:         effective_targets = prepared_context.get("effective_targets")
0170:         if effective_targets is None:
```

هذا المقتطف مهم لأنه يبين أن التحسين لم يكن superficial tuning، بل تغييراً في read path نفسه أو في طريقة إعادة استخدام البيانات المحمّلة مسبقاً.

## 16. شرح ملفات الـ Testing واحداً واحداً

هذا القسم هو قلب التقرير. رتبت الملفات حسب الفئة، وشرحت كل ملف مهم فردياً، ثم جمعت الملفات الثانوية المتشابهة في مجموعات مستقلة.

### CI Workflow File

#### `ci.yml`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\.github\workflows\ci.yml`
- **الفئة:** `CI Workflow File`
- **الغرض الأساسي:** الملف المركزي لخط أنابيب GitHub Actions؛ يربط بين الأمن، الجودة، اختبارات Django، اختبارات Flutter، وFlutter integration tests.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن كل Pull Request أو Push يمر عبر فحص أسرار، pre-commit، اختبارات backend، التحليل الساكن، اختبارات frontend، ثم اختبار تكاملي على Android emulator.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** اخترت هذا المقتطف لأنه يظهر البداية الفعلية للـ pipeline وترتيب Jobs الأمن والجودة والاختبار.

```yaml
0019: jobs:
0020:   gitleaks:
0021:     name: Security (Gitleaks)
0022:     runs-on: ubuntu-latest
0023:     steps:
0024:       - name: Checkout repository
0025:         uses: actions/checkout@v4
0026: 
0027:       - name: Install Gitleaks
0028:         run: |
0029:           mkdir -p /tmp/gitleaks
0030:           curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" -o /tmp/gitleaks/gitleaks.tar.gz
0031:           tar -xzf /tmp/gitleaks/gitleaks.tar.gz -C /tmp/gitleaks
0032:           chmod +x /tmp/gitleaks/gitleaks
0033: 
0034:       - name: Stage repository for snapshot scan
0035:         run: git add -A
0036: 
0037:       - name: Run Gitleaks scan
0038:         run: /tmp/gitleaks/gitleaks git --pre-commit --staged --config .gitleaks.toml --gitleaks-ignore-path .gitleaksignore --redact --verbose
0039: 
0040:   pre-commit:
0041:     name: Quality (pre-commit)
0042:     runs-on: ubuntu-latest
0043:     steps:
0044:       - name: Checkout repository
0045:         uses: actions/checkout@v4
0046: 
0047:       - name: Set up Python
0048:         uses: actions/setup-python@v5
0049:         with:
0050:           python-version: ${{ env.PYTHON_VERSION }}
0051: 
0052:       - name: Install pre-commit and Gitleaks
0053:         run: |
0054:           python -m pip install --upgrade pip
0055:           pip install pre-commit
0056:           mkdir -p /tmp/gitleaks
0057:           curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" -o /tmp/gitleaks/gitleaks.tar.gz
0058:           tar -xzf /tmp/gitleaks/gitleaks.tar.gz -C /tmp/gitleaks
0059:           chmod +x /tmp/gitleaks/gitleaks
0060:           sudo mv /tmp/gitleaks/gitleaks /usr/local/bin/gitleaks
0061: 
0062:       - name: Stage repository for staged-only hooks
0063:         run: git add -A
0064: 
0065:       - name: Run pre-commit checks
0066:         run: pre-commit run --all-files --show-diff-on-failure
0067: 
0068:   backend-tests:
0069:     name: Backend Tests (Django + Postgres)
0070:     runs-on: ubuntu-latest
0071:     needs:
0072:       - gitleaks
0073:       - pre-commit
0074:     services:
0075:       postgres:
0076:         image: postgres:17
0077:         env:
0078:           POSTGRES_DB: vitamate
0079:           POSTGRES_USER: vitamate
0080:           POSTGRES_PASSWORD: vitamate
0081:         ports:
0082:           - 5432:5432
0083:         options: >-
0084:           --health-cmd "pg_isready -U vitamate -d vitamate"
0085:           --health-interval 10s
0086:           --health-timeout 5s
0087:           --health-retries 5
0088:     defaults:
0089:       run:
0090:         working-directory: Implementation/vitamate_backend
0091:     env:
0092:       DJANGO_ENV: dev
0093:       DJANGO_SECRET_KEY: ci-secret-key
0094:       POSTGRES_DB: vitamate
0095:       POSTGRES_USER: vitamate
0096:       POSTGRES_PASSWORD: vitamate
0097:       POSTGRES_HOST: 127.0.0.1
0098:       POSTGRES_PORT: "5432"
0099:     steps:
0100:       - name: Checkout repository
0101:         uses: actions/checkout@v4
0102: 
0103:       - name: Set up Python
0104:         uses: actions/setup-python@v5
0105:         with:
0106:           python-version: ${{ env.PYTHON_VERSION }}
0107:           cache: pip
0108:           cache-dependency-path: Implementation/vitamate_backend/requirements.txt
0109: 
0110:       - name: Install backend dependencies
0111:         run: |
0112:           python -m pip install --upgrade pip
0113:           pip install -r requirements.txt
0114: 
0115:       - name: Check pending migrations
0116:         run: python manage.py makemigrations --check --dry-run
0117: 
0118:       - name: Apply migrations on CI database
0119:         run: python manage.py migrate --noinput
0120: 
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Security/Quality Config

#### `.pre-commit-config.yaml`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\.pre-commit-config.yaml`
- **الفئة:** `Security/Quality Config`
- **الغرض الأساسي:** يضبط الـ hooks المحلية التي تعمل قبل الدفع أو قبل الدمج، ويضيف فحص الأسرار محلياً عبر gitleaks إلى جانب فحوصات الصياغة الأساسية.
- **ما الذي يختبره أو يفعّله:** يتحقق من YAML/JSON، تعارضات الدمج، المفاتيح الخاصة، ثم يسد ثغرة التسريبات السرية قبل الوصول إلى CI.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** الملف قصير ويستحق عرضه بالكامل لأنه يمثل سياسة الجودة المحلية بشكل مباشر.

```yaml
0001: repos:
0002:   - repo: https://github.com/pre-commit/pre-commit-hooks
0003:     rev: v5.0.0
0004:     hooks:
0005:       - id: check-yaml
0006:       - id: check-json
0007:       - id: check-merge-conflict
0008:       - id: detect-private-key
0009:   - repo: local
0010:     hooks:
0011:       - id: gitleaks
0012:         name: Detect hardcoded secrets
0013:         entry: gitleaks git --pre-commit --redact --staged --verbose --config .gitleaks.toml --gitleaks-ignore-path .gitleaksignore
0014:         language: system
0015:         pass_filenames: false
0016:         always_run: true
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `.gitleaks.toml`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\.gitleaks.toml`
- **الفئة:** `Security/Quality Config`
- **الغرض الأساسي:** يضبط استثناءات Gitleaks الخاصة بهذا المشروع، بحيث يُخفض الإيجابيات الكاذبة دون تعطيل الفحص الحقيقي للأسرار.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن استثناءات التسريبات موثقة ومحددة بالمسار أو النمط، لا بفتح الباب على مصراعيه.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** المقتطف يبين بوضوح كيف جرى تضييق allowlists على ملفات ونصوص معروفة فقط.

```toml
0001: title = "VitaMate Gitleaks Config"
0002: 
0003: [extend]
0004: useDefault = true
0005: 
0006: [[allowlists]]
0007: description = "Ignore known Sidekiq env-var example false positive in docs"
0008: paths = ['''(?i)^README\.md$''']
0009: regexes = ['''BUNDLE_ENTERPRISE__CONTRIBSYS__COM''']
0010: 
0011: [[allowlists]]
0012: description = "Ignore local temporary gitleaks binaries downloaded only for validation"
0013: paths = ['''(?i)^Implementation/tmp_gitleaks/''']
0014: 
0015: [[allowlists]]
0016: description = "Ignore static chronic condition seed migration false positives"
0017: paths = ['''(?i)^Implementation/vitamate_backend/core/migrations/0005_seed_chronic_condition_catalog\.py$''']
0018: stopwords = ['''activity_minutes_7d''']
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `.gitleaksignore`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\.gitleaksignore`
- **الفئة:** `Security/Quality Config`
- **الغرض الأساسي:** قائمة بصمات محددة جداً يتم تجاهلها بعد مراجعة يدوية، وغرضها التعامل مع false positives المتبقية.
- **ما الذي يختبره أو يفعّله:** تتحكم في تجاهل بصمات ثابتة فقط، لا في تعطيل الأداة نفسها.
- **الأهمية داخل المنظومة:** `supportive`
- **سبب اختيار المقتطف:** الملف قصير ويظهر أن الاستثناءات جاءت على مستوى fingerprint لا على مستوى تعطيل الفحص.

```text
0001: Implementation/vitamate_backend/core/migrations/0005_seed_chronic_condition_catalog.py:generic-api-key:54
0002: Implementation/vitamate_backend/core/migrations/0005_seed_chronic_condition_catalog.py:generic-api-key:57
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `.env.example`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\.env.example`
- **الفئة:** `Security/Quality Config`
- **الغرض الأساسي:** يوفر نموذج البيئة الافتراضية لتشغيل backend، ويكشف قاعدة البيانات الافتراضية وإمكانية SQLite fallback محلياً.
- **ما الذي يختبره أو يفعّله:** يتحقق غير مباشرة من أن أوامر الاختبار تعتمد على بيئة قابلة لإعادة الضبط وأن CI لا يعتمد على أسرار محلية غامضة.
- **الأهمية داخل المنظومة:** `supportive`
- **سبب اختيار المقتطف:** المقتطف مهم لأنه يحدد Postgres كخيار افتراضي ويظهر fallback المحلي إلى SQLite عند الحاجة.

```text
0001: DJANGO_ENV=dev
0002: DJANGO_SECRET_KEY=change-me
0003: DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2
0004: DJANGO_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
0005: # Set this only when you explicitly want SQLite fallback for local dev.
0006: # VITAMATE_USE_SQLITE=1
0007: POSTGRES_DB=vitamate
0008: POSTGRES_USER=vitamate
0009: POSTGRES_PASSWORD=vitamate
0010: POSTGRES_HOST=localhost
0011: POSTGRES_PORT=5432
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Testing Documentation

#### `README.md`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\README.md`
- **الفئة:** `Testing Documentation`
- **الغرض الأساسي:** الوثيقة الجذرية التي تجمع شرح المشروع، أوامر تشغيل الاختبارات، وسياسة CI المحلية والعامة.
- **ما الذي يختبره أو يفعّله:** لا تنفذ اختباراً بحد ذاتها، لكنها توثق طريق التشغيل الرسمي لكل طبقة اختبار وتشرح كيف تُقرأ نتائج CI.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** اخترت هذا المقتطف لأنه يلخص أوامر التشغيل الأساسية محلياً ويشرح فلسفة استبدال Playwright بـ Flutter integration_test.

```markdown
0038: ### Backend
0039: ```bash
0040: cd Implementation/vitamate_backend
0041: python -m venv .venv
0042: .venv\Scripts\activate
0043: pip install -r requirements.txt
0044: python manage.py migrate
0045: python manage.py runserver
0046: ```
0047: 
0048: ### Frontend
0049: ```bash
0050: cd Implementation/vitamate_frontend
0051: flutter pub get
0052: flutter run
0053: ```
0054: 
0055: ## Local Quality Checks
0056: 
0057: ### Backend tests
0058: ```bash
0059: cd Implementation/vitamate_backend
0060: python manage.py makemigrations --check --dry-run
0061: python manage.py test users core gamification --verbosity 1
0062: ```
0063: 
0064: ### Frontend checks
0065: ```bash
0066: cd Implementation/vitamate_frontend
0067: flutter analyze
0068: flutter test
0069: ```
0070: 
0071: ### Flutter integration tests
0072: Playwright was replaced with Flutter `integration_test` because the client is a native Flutter application and the required E2E flow must exercise the real mobile UI layer, not a browser shell.
0073: 
0074: Prepare the backend and the reproducible E2E user:
0075: ```bash
0076: cd Implementation/vitamate_backend
0077: python manage.py migrate
0078: python manage.py seed_integration_user --scenario chronic_flow --reset
0079: python manage.py runserver 0.0.0.0:8000
0080: ```
0081: 
0082: Run the Flutter integration tests on an Android emulator:
0083: ```bash
0084: cd Implementation/vitamate_frontend
0085: flutter pub get
0086: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/smoke_login_home_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
0087: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/chronic_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
0088: ```
0089: 
0090: The E2E seed command creates or resets:
0091: - username: `e2e_chronic`
0092: - password: `Pass123!`
0093: 
0094: The Flutter integration flow uses a real backend and validates the chronic-care path:
0095: - login
0096: - open `Conditions Center`
0097: - add `Hypertension`
0098: - add a follow-up reading
0099: - verify the updated detail summary and the `Home` conditions section
0100: 
0101: Integration test operating notes:
0102: - Run the smoke test first. It isolates login and home loading before the full chronic scenario.
0103: - If the backend was already used by a previous run, rerun `seed_integration_user --scenario chronic_flow --reset` before executing the chronic flow again.
0104: - CI uses the same `flutter drive` approach on an Android emulator.
0105: 
0106: ### Medications flow notes
0107: - The frontend uses one shared medication flow for both manual medications and condition-linked medications.
0108: - The add/edit flow sends `source_type="manual"` for the Medications page.
0109: - The chronic-condition detail path sends `source_type="condition"` together with `user_condition_id`.
0110: - Reminder sync is backend-driven through `/api/medications/reminder-sync/`, then projected locally by `NotificationsService.syncMedicationReminders(...)`.
0111: - Today dose rows and adherence state come from backend APIs such as `/api/medications/today/`; the UI should not calculate an independent medication state.
0112: 
0113: ### iOS launch assets
0114: - To customize the iOS launch screen, replace the assets under `Implementation/vitamate_frontend/ios/Runner/Assets.xcassets/LaunchImage.imageset`.
0115: 
0116: ### Pre-commit with secrets scanning
0117: Install `pre-commit` and make sure the `gitleaks` CLI is available on your `PATH`.
0118: 
0119: ```bash
0120: pip install pre-commit
0121: pre-commit install
0122: git add -A
0123: pre-commit run --all-files --show-diff-on-failure
0124: ```
0125: 
0126: The local `pre-commit` flow includes:
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `requirements.txt`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\requirements.txt`
- **الفئة:** `Testing Documentation`
- **الغرض الأساسي:** يسجل اعتماديات backend، ومن زاوية الاختبار يهمنا خصوصاً إضافة `locust` واعتماديات Django وDRF.
- **ما الذي يختبره أو يفعّله:** يوثق الأدوات المتاحة للتشغيل الفعلي؛ ووجود `locust` هنا دليل على أن اختبار الأداء جزء من البيئة الرسمية.
- **الأهمية داخل المنظومة:** `supportive`
- **سبب اختيار المقتطف:** أبرز هذا المقتطف لأن السطر الخاص بـ Locust يثبت إدخال أداة الأداء إلى البيئة الرسمية للمشروع.

```text
0001: a s g i r e f = = 3 . 1 1 . 0 
0002:  
0003:  D j a n g o = = 5 . 2 . 1 0 
0004:  
0005:  d j a n g o - c o r s - h e a d e r s = = 4 . 9 . 0 
0006:  
0007:  d j a n g o r e s t f r a m e w o r k = = 3 . 1 6 . 1 
0008:  
0009:  d j a n g o r e s t f r a m e w o r k _ s i m p l e j w t = = 5 . 5 . 1 
0010:  
0011:  P y J W T = = 2 . 1 0 . 1 
0012:  
0013:  p s y c o p g [ b i n a r y ] > = 3 . 2 , < 4 
0014:  
0015:  s e t u p t o o l s = = 5 7 . 4 . 0 
0016:  
0017:  s q l p a r s e = = 0 . 5 . 5 
0018:  
0019:  t z d a t a = = 2 0 2 5 . 3 
0020:  
0021:  
0022:  
0023:  l o c u s t > = 2 . 4 3 , < 3 
0024:  
0025:  
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `api_contract_baseline.md`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\docs\api_contract_baseline.md`
- **الفئة:** `Testing Documentation`
- **الغرض الأساسي:** مرجع نصي ثابت يصف عقود JSON العامة التي يعتمد عليها تطبيق Flutter.
- **ما الذي يختبره أو يفعّله:** يخدم كخط أساس مرجعي لعقود API، ويكمل الاختبارات البرمجية في `test_api_contracts.py`.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** المقتطف يوضح بجلاء العقد العام لـ `/api/auth/me/` و`/api/dashboard/` و`/api/history/` بوصفها واجهات استهلاك أساسية.

```markdown
0001: # VitaMate Backend API Contract Baseline
0002: 
0003: This baseline captures the public JSON contracts currently consumed by the Flutter app.
0004: It is used as a regression reference during the gradual Strangler/Adapter migration.
0005: 
0006: ## Auth
0007: 
0008: ### `GET /api/auth/me/`
0009: 
0010: - Must return account/profile fields used by app settings and onboarding.
0011: - Expected keys (minimum):  
0012:   `username`, `first_name`, `last_name`, `email`, `weight`, `height`, `activity_level`,
0013:   `goal`, `daily_step_goal`, `gender`, `birth_date`, `recommended_sleep_hours`,
0014:   `target_wake_time`, `target_bed_time`, `enable_sleep_improvement`,
0015:   `preferred_activity_type`, `enable_activity_reminders`,
0016:   `activity_reminder_interval_hours`, `enable_water_reminders`,
0017:   `water_reminder_interval_minutes`.
0018: 
0019: ### `PATCH /api/auth/me/`
0020: 
0021: - Supports direct profile fields above.
0022: - Backward compatible with onboarding payload field `age`:
0023:   - `age` is accepted and converted internally to `birth_date`.
0024: 
0025: ## Dashboard and History
0026: 
0027: ### `GET /api/dashboard/`
0028: 
0029: - Top-level keys: `summary`, `hydration`, `sleep`, `activity`, `gamification`.
0030: - Nested minimum keys:
0031:   - `summary`: `calories_target`, `calories_consumed`, `calories_remaining`, `calories_burned`, `burn_target`
0032:   - `hydration`: `target`, `current`, `adjusted_target`
0033:   - `sleep`: `target_bed_time`, `target_wake_time`, `recommended_sleep_hours`, `logged_hours_today`, `progress_percent`
0034:   - `activity`: `steps`, `steps_target`, `distance_km`, `steps_burned`, `steps_burn_rate`
0035:   - `gamification`: `points`, `level`
0036: 
0037: ### `GET /api/history/`
0038: 
0039: - Top-level key: `history` (array).
0040: - Per-item minimum keys:
0041:   `date`, `water_current`, `water_target`, `steps`, `steps_target`, `distance_km`,
0042:   `steps_burned`, `steps_burn_rate`, `calories_in`, `calories_target`,
0043:   `calories_burned`, `sleep_hours`, `sleep_target`, `exercise_minutes`,
0044:   `points_estimate`, `burn_target`, `burn_current`.
0045: 
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `baseline_notes.md`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\baseline_notes.md`
- **الفئة:** `Testing Documentation`
- **الغرض الأساسي:** الوثيقة التي تشرح baseline الرسمي قبل التحسين: البيئة، أوامر التشغيل، عدد المستخدمين، زمن التشغيل، وجدول المقاييس الأولية.
- **ما الذي يختبره أو يفعّله:** تمثل المرجع النصي الأساسي لسيناريو before وتشير صراحة إلى أن `/api/history/` كان عنق الزجاجة الأوضح.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** اخترت هذا المقتطف لأنه يجمع commands baseline وجدول المقاييس الأولية في مكان واحد.

```markdown
0001: # Performance Baseline Notes
0002: 
0003: This file captures the pre-optimization baseline for:
0004: 
0005: - `GET /api/dashboard/`
0006: - `GET /api/history/`
0007: 
0008: ## Environment
0009: 
0010: - Date: `2026-04-22`
0011: - Backend host: `http://127.0.0.1:8000`
0012: - Database: `Postgres` via default backend development settings
0013: - Dataset profile: `representative`
0014: - Seed command:
0015:   - `python manage.py seed_performance_dataset --profile representative --reset`
0016: - Locust scenario mode:
0017:   - `LOCUST_SCENARIO=dashboard`
0018:   - `LOCUST_SCENARIO=history`
0019: - User pool: `locust0` .. `locust39`
0020: 
0021: ## Official Commands
0022: 
0023: From `Implementation/vitamate_backend`:
0024: 
0025: ```powershell
0026: .\.venv\Scripts\python.exe manage.py migrate
0027: .\.venv\Scripts\python.exe manage.py seed_performance_dataset --profile representative --reset
0028: .\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
0029: ```
0030: 
0031: Dashboard run:
0032: 
0033: ```powershell
0034: $env:LOCUST_SCENARIO="dashboard"
0035: locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\\docs\\performance\\before\\dashboard --only-summary
0036: ```
0037: 
0038: History run:
0039: 
0040: ```powershell
0041: $env:LOCUST_SCENARIO="history"
0042: locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\\docs\\performance\\before\\history --only-summary
0043: ```
0044: 
0045: ## Baseline Table
0046: 
0047: | Endpoint | Users | Spawn rate | Run time | Avg ms | P95 ms | Max ms | RPS | Failures |
0048: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
0049: | `/api/dashboard/` | 20 | 5 | 2m | 355.85 | 720 | 1203.86 | 8.40 | 0 |
0050: | `/api/history/` | 20 | 5 | 2m | 5261.65 | 6400 | 6876.79 | 2.68 | 0 |
0051: 
0052: ## Initial Bottleneck Notes
0053: 
0054: - Dashboard: stable under the baseline profile, but still slower than desirable for a primary home-screen read. The current baseline sits at 355.85 ms average and 720 ms at P95.
0055: - History: dominant bottleneck in the current baseline. Average latency is about 5.26s with P95 at 6.4s, which is far above dashboard latency under the same load profile.
0056: - Does fallback appear dominant: likely yes for `history`, based on the large gap between `dashboard` and `history` under the same seed dataset. This is an inference from the measurements, not yet query-count proof.
0057: - Any failures or instability: none in the successful baseline runs. The only earlier failure was harness-related because the seeded user pool was smaller than the Locust pool; that mismatch was corrected by reseeding the full 40-user pool before the official runs.
0058: 
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `performance_report.md`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\performance_report.md`
- **الفئة:** `Testing Documentation`
- **الغرض الأساسي:** التقرير التحليلي before/after للأداء، ويحتوي جداول المقارنة، تفسير bottlenecks، والتغييرات المطبقة وأثرها.
- **ما الذي يختبره أو يفعّله:** يقدم الدليل النصي الأقوى على أن عمل performance testing لم يتوقف عند القياس بل وصل إلى optimization case study.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** المقتطف يركز على جدول before/after وتعليل مصادر البطء والتحسينات المنفذة.

```markdown
0001: # Performance Report
0002: 
0003: ## Summary
0004: 
0005: - Optimization target:
0006:   - `GET /api/dashboard/`
0007:   - `GET /api/history/`
0008: - Dataset profile: `representative`
0009: - Evidence mode: `CSV + Notes`
0010: 
0011: ## Before vs After
0012: 
0013: | Endpoint | Metric | Before | After | Delta |
0014: | --- | --- | --- | --- | --- |
0015: | `/api/dashboard/` | Avg ms | 355.85 | 142.82 | -213.03 ms |
0016: | `/api/dashboard/` | P95 ms | 720 | 240 | -480 ms |
0017: | `/api/dashboard/` | RPS | 8.40 | 9.12 | +0.72 |
0018: | `/api/dashboard/` | Failures | 0 | 0 | 0 |
0019: | `/api/history/` | Avg ms | 5261.65 | 817.39 | -4444.26 ms |
0020: | `/api/history/` | P95 ms | 6400 | 1500 | -4900 ms |
0021: | `/api/history/` | RPS | 2.68 | 7.02 | +4.34 |
0022: | `/api/history/` | Failures | 0 | 0 | 0 |
0023: 
0024: ## Bottlenecks
0025: 
0026: - Fallback path cost: confirmed main bottleneck for `history`. The old path built a full projection for each day and then used only `history_entry`.
0027: - Constraint reuse cost: dashboard/history were repeatedly loading active constraints and recomputing effective numeric targets within the same request path.
0028: - Medication summary query cost: day counts were computed through repeated queryset `.count()` calls and condition dose counts rebuilt the same daily plan twice.
0029: - Activity/profile read amplification: `history` fallback rebuilt warnings, targets, snapshots, and dashboard-only structures that were never returned by `/api/history/`.
0030: 
0031: ## Changes Applied
0032: 
0033: - Added a lightweight `build_history_entry()` path in the projection service so `history` fallback now computes only the fields returned by `/api/history/`.
0034: - Reused an active-constraint bundle inside the projection request path instead of querying active constraints separately for each numeric target.
0035: - Added shared condition context preparation so active conditions, rule profiles, and target maps are prepared once and reused across daily history entries.
0036: - Reworked medication day counting to use a single pass over daily logs instead of multiple filtered `.count()` queries.
0037: - Replaced duplicate medication dose-list rebuilds with a shared `today_dose_counts()` path.
0038: - Removed N+1-style reads in condition adherence/target resolution by batching daily evaluations and condition rule profile loading.
0039: 
0040: ## Interpretation
0041: 
0042: - What improved: both endpoints improved, but `history` improved the most. Average latency dropped from 5261.65 ms to 817.39 ms, and throughput rose from 2.68 RPS to 7.02 RPS.
0043: - Why it improved: the main gain came from stopping full daily projection builds for history fallback and reducing repeated queries for constraints, conditions, and medication summary calculations.
0044: - Remaining limits: `history` is still slower than `dashboard`, which suggests there is still value in query-count instrumentation and deeper optimization around daily log aggregation and snapshot coverage.
0045: 
0046: ## Artifacts
0047: 
0048: - `docs/performance/before/`
0049: - `docs/performance/after/`
0050: - `docs/performance/baseline_notes.md`
0051: - `docs/performance/before/dashboard_stats.csv`
0052: - `docs/performance/before/history_stats.csv`
0053: - `docs/performance/after/dashboard_stats.csv`
0054: - `docs/performance/after/history_stats.csv`
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Test Utility

#### `helpers.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\test_utils\helpers.py`
- **الفئة:** `Test Utility`
- **الغرض الأساسي:** مجموعة مصانع ومساعدات مشتركة لإنشاء مستخدمين وملفات شخصية وعناصر طعام وتمارين، ولتوليد APIClient موثق بجلسة JWT.
- **ما الذي يختبره أو يفعّله:** تقلل تكرار setup داخل اختبارات backend وتضمن أن كل suite تبدأ من بيانات اختبار متسقة.
- **الأهمية داخل المنظومة:** `critical`
- **الدوال: `create_user_with_profile`, `auth_client_for_user`, `create_food_item`, `create_exercise`, `get_steps_for`**
- **سبب اختيار المقتطف:** المقتطف يبين أهم factories الموحّدة المستخدمة عبر عدة suites، خصوصاً إنشاء المستخدم وتسجيل الدخول الآلي.

```python
0001: from datetime import date
0002: 
0003: from django.contrib.auth.models import User
0004: from rest_framework.test import APIClient
0005: 
0006: from core.models import FoodItem, Exercise, StepLog
0007: from users.models import UserProfile
0008: from users.services.user_profile_service import UserProfileService
0009: 
0010: 
0011: def create_user_with_profile(
0012:     username: str,
0013:     password: str = "Pass123!",
0014:     email: str | None = None,
0015:     *,
0016:     height: float = 170,
0017:     weight: float = 70,
0018:     gender: str = "M",
0019:     activity_level: float = 1.2,
0020: ) -> User:
0021:     """
0022:     Factory: create a user and attach/update UserProfile with sensible defaults.
0023:     Handles cases where signals already created a profile.
0024:     """
0025:     user, _ = User.objects.get_or_create(
0026:         username=username,
0027:         defaults={
0028:             "password": password,
0029:             "email": email or f"{username}@example.com",
0030:             "first_name": "Test",
0031:             "last_name": "User",
0032:         },
0033:     )
0034:     if not user.check_password(password):
0035:         user.set_password(password)
0036:         user.save()
0037: 
0038:     profile, _ = UserProfile.objects.get_or_create(
0039:         user=user,
0040:         defaults={
0041:             "birth_date": date(2000, 1, 1),
0042:             "gender": gender,
0043:             "height": height,
0044:             "weight": weight,
0045:             "activity_level": activity_level,
0046:         },
0047:     )
0048:     profile.gender = gender
0049:     profile.height = height
0050:     profile.weight = weight
0051:     profile.activity_level = activity_level
0052:     UserProfileService.recalculate_profile(profile)
0053:     return user
0054: 
0055: 
0056: def auth_client_for_user(user: User, password: str = "Pass123!") -> APIClient:
0057:     """
0058:     Login through SimpleJWT and return an APIClient with Authorization header set.
0059:     """
0060:     client = APIClient()
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Test Data / Seed Utility

#### `seed_integration_user.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\management\commands\seed_integration_user.py`
- **الفئة:** `Test Data / Seed Utility`
- **الغرض الأساسي:** أمر Django management لتجهيز مستخدم E2E ثابت باسم `e2e_chronic` قبل تشغيل Flutter integration tests.
- **ما الذي يختبره أو يفعّله:** يتحقق من قابلية إعادة الإنتاج للتجارب التكاملية عبر إعادة ضبط بيانات المستخدم فقط دون العبث ببيانات النظام العامة.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `Command`**
- **سبب اختيار المقتطف:** هذا المقتطف يوضح منطق إنشاء المستخدم الثابت وإعادة ضبط حالته قبل سيناريو chronic flow.

```python
0027: class Command(BaseCommand):
0028:     help = "Create or reset the reproducible E2E user used by Flutter integration tests."
0029: 
0030:     def add_arguments(self, parser):
0031:         parser.add_argument("--scenario", default="chronic_flow")
0032:         parser.add_argument("--reset", action="store_true")
0033:         parser.add_argument("--username", default="e2e_chronic")
0034:         parser.add_argument("--password", default="Pass123!")
0035: 
0036:     def handle(self, *args, **options):
0037:         scenario = options["scenario"]
0038:         if scenario != "chronic_flow":
0039:             raise CommandError(
0040:                 f"Unsupported scenario '{scenario}'. Only 'chronic_flow' is available."
0041:             )
0042: 
0043:         username = options["username"]
0044:         password = options["password"]
0045:         reset = options["reset"]
0046: 
0047:         with transaction.atomic():
0048:             user, _ = User.objects.get_or_create(
0049:                 username=username,
0050:                 defaults={
0051:                     "email": f"{username}@example.com",
0052:                     "first_name": "E2E",
0053:                     "last_name": "Chronic",
0054:                 },
0055:             )
0056: 
0057:             user.email = f"{username}@example.com"
0058:             user.first_name = "E2E"
0059:             user.last_name = "Chronic"
0060:             if not user.check_password(password):
0061:                 user.set_password(password)
0062:             user.save()
0063: 
0064:             profile = UserProfileService.ensure_profile(user)
0065:             profile.gender = profile.gender or "M"
0066:             profile.height = profile.height or 170
0067:             profile.weight = profile.weight or 70
0068:             profile.activity_level = profile.activity_level or 1.2
0069:             profile.save()
0070: 
0071:             if reset:
0072:                 self._reset_user_state(user)
0073: 
0074:             UserScore.objects.update_or_create(
0075:                 user=user,
0076:                 defaults={"total_points": 0, "level": 1},
0077:             )
0078: 
0079:         self.stdout.write(
0080:             self.style.SUCCESS(
0081:                 f"Prepared integration user '{username}' for scenario '{scenario}'."
0082:             )
0083:         )
0084: 
0085:     def _reset_user_state(self, user: User) -> None:
0086:         ConditionMedication.objects.filter(user=user).delete()
0087:         UserCondition.objects.filter(user=user).delete()
0088: 
0089:         MealLog.objects.filter(user=user).delete()
0090:         WaterLog.objects.filter(user=user).delete()
0091:         StepLog.objects.filter(user=user).delete()
0092:         SleepLog.objects.filter(user=user).delete()
0093:         ActivityLog.objects.filter(user=user).delete()
0094: 
0095:         Habit.objects.filter(user=user).delete()
0096:         Medicine.objects.filter(user=user).delete()
0097: 
0098:         UserNutrientTarget.objects.filter(user=user).delete()
0099:         ResolvedTrackerConstraint.objects.filter(user=user).delete()
0100:         ConstraintResolutionRun.objects.filter(user=user).delete()
0101: 
0102:         UnifiedHealthState.objects.filter(user=user).delete()
0103:         HealthStateComputationRun.objects.filter(user=user).delete()
0104:         HealthStateDelta.objects.filter(user=user).delete()
0105:         NotificationDispatchRecord.objects.filter(user=user).delete()
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `seed_performance_dataset.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\management\commands\seed_performance_dataset.py`
- **الفئة:** `Test Data / Seed Utility`
- **الغرض الأساسي:** أمر كبير لتوليد Dataset تمثيلية لاختبارات Locust، تشمل مستخدمين ثابتين وسبعة أيام على الأقل من البيانات الصحية والمزمنة والدوائية.
- **ما الذي يختبره أو يفعّله:** يضمن أن baseline الأداء قابل لإعادة التشغيل وأن سيناريوي `/api/dashboard/` و`/api/history/` لا يقاسان على بيانات مصطنعة بسيطة جداً.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `SeedContext`, `Command`**
- **سبب اختيار المقتطف:** أبرز المقتطف الذي يبين كيف تُزرع بيانات الأيام السبعة والحالات المزمنة والأدوية لكل مستخدم من pool الأداء.

```python
0144:     def _seed_user(self, *, user: User, index: int, context: SeedContext) -> None:
0145:         habits = self._seed_habits(user=user)
0146:         hypertension = self._seed_hypertension_condition(
0147:             user=user,
0148:             index=index,
0149:             context=context,
0150:         )
0151:         diabetes = None
0152:         if index % 4 == 0:
0153:             diabetes = self._seed_diabetes_condition(
0154:                 user=user,
0155:                 index=index,
0156:                 context=context,
0157:             )
0158: 
0159:         for day_offset in range(context.day_count):
0160:             target_day = (context.today - timedelta(days=context.day_count - day_offset - 1)).date()
0161:             self._seed_day_logs(
0162:                 user=user,
0163:                 index=index,
0164:                 target_day=target_day,
0165:                 day_offset=day_offset,
0166:                 context=context,
0167:             )
0168:             self._seed_habit_logs(
0169:                 habits=habits,
0170:                 index=index,
0171:                 target_day=target_day,
0172:                 day_offset=day_offset,
0173:             )
0174:             self._seed_medication_logs_for_day(
0175:                 condition=hypertension,
0176:                 index=index,
0177:                 target_day=target_day,
0178:                 day_offset=day_offset,
0179:             )
0180:             self._seed_condition_evaluation(
0181:                 condition=hypertension,
0182:                 index=index,
0183:                 target_day=target_day,
0184:                 day_offset=day_offset,
0185:             )
0186:             if diabetes is not None:
0187:                 self._seed_medication_logs_for_day(
0188:                     condition=diabetes,
0189:                     index=index,
0190:                     target_day=target_day,
0191:                     day_offset=day_offset,
0192:                 )
0193:                 self._seed_condition_evaluation(
0194:                     condition=diabetes,
0195:                     index=index,
0196:                     target_day=target_day,
0197:                     day_offset=day_offset,
0198:                 )
0199: 
0200:         self._seed_indicator_records(
0201:             condition=hypertension,
0202:             index=index,
0203:             recorded_at=context.today - timedelta(minutes=15),
0204:         )
0205:         if diabetes is not None:
0206:             self._seed_indicator_records(
0207:                 condition=diabetes,
0208:                 index=index,
0209:                 recorded_at=context.today - timedelta(minutes=8),
0210:             )
0211: 
0212:     def _seed_day_logs(
0213:         self,
0214:         *,
0215:         user: User,
0216:         index: int,
0217:         target_day,
0218:         day_offset: int,
0219:         context: SeedContext,
0220:     ) -> None:
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Performance Test File

#### `locustfile.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\loadtest\locustfile.py`
- **الفئة:** `Performance Test File`
- **الغرض الأساسي:** تعريف Locust الرسمي للمشروع، ويدعم سيناريوين منفصلين: `dashboard` و`history` مع pool مستخدمين seeded ثابتة.
- **ما الذي يختبره أو يفعّله:** يقيس زمن الاستجابة والـ throughput والفشل على endpoint واحد واضح في كل مرة، بعد login و`/api/auth/me/` التمهيدي.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_UserPool`, `VitaMateUser`**
- **سبب اختيار المقتطف:** المقتطف يوضح أهم قرارين في harness: تثبيت user pool، وعزل السيناريو بين `/api/dashboard/` و`/api/history/`.

```python
0001: """
0002: Locust load test for VitaMate backend.
0003: 
0004: Run example (dashboard):
0005:   set LOCUST_SCENARIO=dashboard
0006:   locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5
0007: 
0008: Run example (history):
0009:   set LOCUST_SCENARIO=history
0010:   locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5
0011: 
0012: Metrics (avg, p95, failures) are available in Locust UI/CSV exports.
0013: The script expects a seeded fixed user pool such as locust0..locust39.
0014: """
0015: 
0016: import os
0017: import threading
0018: 
0019: from locust import HttpUser, between, task
0020: from locust.exception import StopUser
0021: 
0022: 
0023: class _UserPool:
0024:     """Thread-safe sequential assignment of seeded test users."""
0025: 
0026:     _lock = threading.Lock()
0027:     _counter = 0
0028: 
0029:     @classmethod
0030:     def next_username(cls, base: str, pool_size: int) -> str:
0031:         with cls._lock:
0032:             username = f"{base}{cls._counter % pool_size}"
0033:             cls._counter += 1
0034:             return username
0035: 
0036: 
0037: class VitaMateUser(HttpUser):
0038:     wait_time = between(1, 3)
0039:     SUPPORTED_SCENARIOS = {
0040:         "dashboard": "/api/dashboard/",
0041:         "history": "/api/history/",
0042:     }
0043: 
0044:     def on_start(self):
0045:         self.scenario = (os.getenv("LOCUST_SCENARIO", "dashboard") or "dashboard").strip().lower()
0046:         if self.scenario not in self.SUPPORTED_SCENARIOS:
0047:             raise StopUser(f"Unsupported LOCUST_SCENARIO '{self.scenario}'.")
0048: 
0049:         base = os.getenv("LOCUST_USERNAME_BASE", "locust")
0050:         pool_size = int(os.getenv("LOCUST_USER_POOL", "40"))
0051:         self.password = os.getenv("LOCUST_PASSWORD", "Pass123!")
0052:         self.username = _UserPool.next_username(base, pool_size)
0053: 
0054:         res = self.client.post(
0055:             "/api/auth/login/",
0056:             json={"username": self.username, "password": self.password},
0057:             name="/api/auth/login/",
0058:         )
0059:         if res.status_code != 200:
0060:             raise StopUser(
0061:                 f"Login failed for '{self.username}'. Seed the performance dataset before running Locust."
0062:             )
0063: 
0064:         payload = res.json()
0065:         token = payload.get("access")
0066:         if not token:
0067:             raise StopUser(f"JWT access token missing for '{self.username}'.")
0068: 
0069:         self.client.headers.update({"Authorization": f"Bearer {token}"})
0070:         profile_res = self.client.get("/api/auth/me/", name="/api/auth/me/")
0071:         if profile_res.status_code != 200:
0072:             raise StopUser(f"Profile load failed for '{self.username}'.")
0073: 
0074:     @task
0075:     def read_primary_endpoint(self):
0076:         endpoint = self.SUPPORTED_SCENARIOS[self.scenario]
0077:         self.client.get(endpoint, name=endpoint)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Backend Test File

#### `test_api_contracts.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_api_contracts.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** Suite شديدة الأهمية لعقود API وصلاحيات الوصول وبنية payloads الخاصة بالـ auth/dashboard/history والـ trackers.
- **ما الذي يختبره أو يفعّله:** تتحقق من ثبات المفاتيح العامة في JSON، ومن بقاء history على سبعة أيام، ومن تضمين chronic summary داخل dashboard/history.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `ApiAccessTests`, `StepsServiceTests`, `ApiContractTests`, `DashboardCoordinatorTests`**
- **أبرز السيناريوهات: `test_protected_endpoint_requires_auth`, `test_user_isolation_on_water_logs`, `test_steps_upsert_keeps_single_daily_record`, `test_auth_me_contract`, `test_dashboard_contract`, `test_history_contract`, `test_water_post_contract`, `test_steps_post_contract`**
- **سبب اختيار المقتطف:** اخترت هذا المقتطف لأنه الأكثر تمثيلاً لاختبار العقد العام للـ API لا مجرد صحة status code.

```python
0066: class ApiContractTests(TestCase):
0067:     def setUp(self):
0068:         self.user = create_user_with_profile(username="contractuser")
0069:         self.client_auth = auth_client_for_user(self.user)
0070:         self.exercise = create_exercise(name="Run", met_value=8.0)
0071:         self.food = create_food_item(name="Rice", calories_100g=150)
0072: 
0073:     def test_auth_me_contract(self):
0074:         res = self.client_auth.get("/api/auth/me/")
0075:         self.assertEqual(res.status_code, status.HTTP_200_OK)
0076: 
0077:         expected_keys = {
0078:             "username",
0079:             "first_name",
0080:             "last_name",
0081:             "email",
0082:             "weight",
0083:             "height",
0084:             "activity_level",
0085:             "goal",
0086:             "daily_step_goal",
0087:             "gender",
0088:             "birth_date",
0089:             "recommended_sleep_hours",
0090:             "target_wake_time",
0091:             "target_bed_time",
0092:             "enable_sleep_improvement",
0093:             "preferred_activity_type",
0094:             "enable_activity_reminders",
0095:             "activity_reminder_interval_hours",
0096:             "enable_water_reminders",
0097:             "water_reminder_interval_minutes",
0098:         }
0099:         self.assertTrue(expected_keys.issubset(set(res.data.keys())))
0100: 
0101:     def test_dashboard_contract(self):
0102:         self.client_auth.post("/api/water/", {"amount_liter": 0.5}, format="json")
0103:         self.client_auth.post("/api/steps/", {"steps_count": 1500, "distance_km": 1.1}, format="json")
0104:         self.client_auth.post(
0105:             "/api/activities/",
0106:             {"exercise": self.exercise.id, "duration_minutes": 20},
0107:             format="json",
0108:         )
0109:         self.client_auth.post(
0110:             "/api/meals/",
0111:             {"food": self.food.id, "meal_type": "lunch", "quantity_grams": 100},
0112:             format="json",
0113:         )
0114: 
0115:         res = self.client_auth.get("/api/dashboard/")
0116:         self.assertEqual(res.status_code, status.HTTP_200_OK)
0117: 
0118:         self.assertTrue({"summary", "hydration", "sleep", "activity", "gamification"}.issubset(res.data.keys()))
0119:         self.assertTrue(
0120:             {
0121:                 "calories_target",
0122:                 "calories_consumed",
0123:                 "calories_remaining",
0124:                 "calories_burned",
0125:                 "burn_target",
0126:             }.issubset(res.data["summary"].keys())
0127:         )
0128:         self.assertTrue({"target", "current", "adjusted_target"}.issubset(res.data["hydration"].keys()))
0129:         self.assertTrue(
0130:             {
0131:                 "target_bed_time",
0132:                 "target_wake_time",
0133:                 "recommended_sleep_hours",
0134:                 "logged_hours_today",
0135:                 "progress_percent",
0136:             }.issubset(res.data["sleep"].keys())
0137:         )
0138:         self.assertTrue(
0139:             {
0140:                 "steps",
0141:                 "steps_target",
0142:                 "distance_km",
0143:                 "steps_burned",
0144:                 "steps_burn_rate",
0145:             }.issubset(res.data["activity"].keys())
0146:         )
0147:         self.assertTrue({"points", "level"}.issubset(res.data["gamification"].keys()))
0148: 
0149:     def test_history_contract(self):
0150:         res = self.client_auth.get("/api/history/")
0151:         self.assertEqual(res.status_code, status.HTTP_200_OK)
0152:         self.assertIn("history", res.data)
0153:         self.assertEqual(len(res.data["history"]), 7)
0154: 
0155:         item = res.data["history"][0]
0156:         expected_keys = {
0157:             "date",
0158:             "water_current",
0159:             "water_target",
0160:             "steps",
0161:             "steps_target",
0162:             "distance_km",
0163:             "steps_burned",
0164:             "steps_burn_rate",
0165:             "calories_in",
0166:             "calories_target",
0167:             "calories_burned",
0168:             "sleep_hours",
0169:             "sleep_target",
0170:             "exercise_minutes",
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_health_state_orchestration.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\orchestration\test_health_state_orchestration.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** Suite انحدار للتنسيق orchestration وطبقة health-state، وتؤكد القراءة من snapshots أولاً وعدم إدخال side effects أثناء read paths.
- **ما الذي يختبره أو يفعّله:** تتحقق من أن dashboard/history يفضلان البيانات المادية الجاهزة، وأن fallback الجديد لتاريخ الأيام يستخدم `build_history_entry` الخفيف.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `HealthTrackerCoordinatorReadTests`, `HealthStateWriteFlowTests`, `DependencyAndNotificationTests`**
- **أبرز السيناريوهات: `test_dashboard_prefers_materialized_state_without_side_effects`, `test_history_reads_materialized_daily_snapshots_first`, `test_dashboard_fallback_is_read_only_when_snapshot_missing`, `test_history_fallback_uses_lightweight_history_builder`, `test_meal_log_creates_current_and_daily_unified_state_after_commit`, `test_backdated_medication_adherence_recomputes_current_and_daily`, `test_notification_decision_service_uses_delta_changes`**
- **سبب اختيار المقتطف:** هذا المقتطف يربط مباشرة بين اختبار الانحدار والتحسين الأدائي الذي خفف `history` بشكل ملموس.

```python
0136:     def test_history_reads_materialized_daily_snapshots_first(self):
0137:         today = date.today()
0138:         start = today - timedelta(days=6)
0139:         for offset in range(7):
0140:             day = start + timedelta(days=offset)
0141:             self._create_state(
0142:                 state_date=day,
0143:                 window_kind=UnifiedHealthState.WINDOW_DAILY,
0144:                 progress_summary={
0145:                     "history_entry": {
0146:                         "date": str(day),
0147:                         "water_current": float(offset),
0148:                         "water_target": 2.0,
0149:                         "steps": offset * 100,
0150:                         "steps_target": 8000,
0151:                         "distance_km": 0,
0152:                         "steps_burned": 0,
0153:                         "steps_burn_rate": 0,
0154:                         "calories_in": 0,
0155:                         "calories_target": 2000,
0156:                         "calories_burned": 0,
0157:                         "sleep_hours": 0,
0158:                         "sleep_target": 8.0,
0159:                         "exercise_minutes": 0,
0160:                         "points_estimate": 0,
0161:                         "burn_target": 300,
0162:                         "burn_current": 0,
0163:                     }
0164:                 },
0165:             )
0166: 
0167:         with patch(
0168:             "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_projection"
0169:         ) as projection_mock:
0170:             history = self.coordinator.build_history(user=self.user, today=today, days=7)
0171: 
0172:         self.assertEqual(len(history), 7)
0173:         self.assertEqual(history[0]["date"], str(start))
0174:         self.assertEqual(history[0]["water_current"], 0.0)
0175:         self.assertEqual(history[-1]["water_current"], 6.0)
0176:         projection_mock.assert_not_called()
0177: 
0178:     def test_dashboard_fallback_is_read_only_when_snapshot_missing(self):
0179:         with patch(
0180:             "core.services.chronic.condition_integration_coordinator.ConditionIntegrationCoordinator.sync_all_for_user"
0181:         ) as sync_mock, patch(
0182:             "core.services.constraints.constraint_recompute_dispatcher.ConstraintRecomputeDispatcher.dispatch_for_user"
0183:         ) as recompute_mock:
0184:             payload = self.coordinator.build_dashboard(user=self.user, today=date.today())
0185: 
0186:         self.assertIsNotNone(payload)
0187:         self.assertEqual(UnifiedHealthState.objects.filter(user=self.user).count(), 0)
0188:         sync_mock.assert_not_called()
0189:         recompute_mock.assert_not_called()
0190: 
0191:     def test_history_fallback_uses_lightweight_history_builder(self):
0192:         today = date.today()
0193:         start = today - timedelta(days=6)
0194:         history_entries = [
0195:             {"date": str(start + timedelta(days=offset)), "water_current": float(offset)}
0196:             for offset in range(7)
0197:         ]
0198: 
0199:         with patch(
0200:             "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_history_entry",
0201:             side_effect=history_entries,
0202:         ) as history_entry_mock, patch(
0203:             "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_projection"
0204:         ) as projection_mock:
0205:             history = self.coordinator.build_history(user=self.user, today=today, days=7)
0206: 
0207:         self.assertEqual(len(history), 7)
0208:         self.assertEqual(history[0]["date"], str(start))
0209:         self.assertEqual(history[-1]["water_current"], 6.0)
0210:         self.assertEqual(history_entry_mock.call_count, 7)
0211:         projection_mock.assert_not_called()
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_chronic_conditions.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\chronic\test_chronic_conditions.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي كتالوج الحالات المزمنة، إنشاء الحالة، إضافة القراءات، التقييمات، التنبيهات، السلامة بين المستخدمين، وارتباط dashboard/history بها.
- **ما الذي يختبره أو يفعّله:** يتحقق من business flow الفعلي للحالات المزمنة، بما في ذلك hypertension وdiabetes وdyslipidemia.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `ChronicConditionApiTests`**
- **أبرز السيناريوهات: `test_supported_catalog_returns_three_supported_conditions`, `test_create_condition_generates_profile_targets_and_evaluation`, `test_duplicate_active_condition_is_rejected`, `test_diabetes_reading_workflow_updates_evaluation_alerts_and_points`, `test_hypertension_reading_tightens_sodium_target`, `test_dyslipidemia_followup_updates_summary`, `test_reading_validation_rejects_wrong_indicator_for_condition`, `test_nested_endpoints_are_ownership_safe`**
- **ملاحظة:** اعتمدت في الشرح على أسماء السيناريوهات لأن الملف كبير ومتعدد التدفقات.
- **سبب اختيار المقتطف:** المقتطف المختار يوضح أن الاختبار لا يقف عند CRUD بل يصل إلى تأثير الحالة المزمنة على dashboard/history.

```python
0291:     def test_dashboard_and_history_keep_reflecting_condition_effects(self):
0292:         diabetes = self._create_condition(
0293:             "diabetes",
0294:             severity=self._severity_code("diabetes", "diabetes_intensive", "diabetes_managed"),
0295:         )
0296:         hypertension = self._create_condition(
0297:             "hypertension",
0298:             severity=self._severity_code("hypertension", "stage_2", "stage_1"),
0299:         )
0300:         self.assertEqual(diabetes.status_code, status.HTTP_201_CREATED)
0301:         self.assertEqual(hypertension.status_code, status.HTTP_201_CREATED)
0302: 
0303:         salty_food = create_food_item(
0304:             name="Salty Soup",
0305:             calories_100g=50,
0306:             sodium_mg_100g=2000,
0307:             fiber_100g=0,
0308:         )
0309:         self.client.post(
0310:             "/api/meals/",
0311:             {
0312:                 "food": salty_food.id,
0313:                 "meal_type": "lunch",
0314:                 "quantity_grams": 200,
0315:             },
0316:             format="json",
0317:         )
0318: 
0319:         dashboard = self.client.get("/api/dashboard/")
0320:         history = self.client.get("/api/history/")
0321:         self.assertEqual(dashboard.status_code, status.HTTP_200_OK)
0322:         self.assertEqual(history.status_code, status.HTTP_200_OK)
0323:         self.assertEqual(dashboard.data["chronic_conditions"]["count"], 2)
0324:         self.assertIn("applied_summaries", dashboard.data["chronic_conditions"])
0325:         self.assertIn("history", history.data)
0326:         self.assertIn("condition_adherence_percent", history.data["history"][0])
0327:         self.assertIn("pending_condition_doses", history.data["history"][0])
0328: 
0329:     def test_medication_actions_still_work_with_new_condition_flow(self):
0330:         schedule_time = (timezone.localtime() - timedelta(minutes=20)).strftime("%H:%M:%S")
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_medications.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\medication\test_medications.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي واجهات الأدوية الموحدة: الإنشاء، خطط اليوم، dose actions، adherence summary، الدمج مع الحالات المزمنة، وسلامة الوصول.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن طبقة الأدوية لا تعمل بمعزل عن chronic care وأن dashboard/history يعكسان حالة الجرعات.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `UnifiedMedicationApiTests`**
- **أبرز السيناريوهات: `test_create_manual_medication_generates_pending_dose_and_reminder_sync`, `test_create_condition_medication_uses_same_plan_model`, `test_chronic_medication_endpoint_syncs_legacy_medicine_mirror`, `test_interval_schedule_can_generate_multiple_doses_on_same_day`, `test_today_plan_and_dose_actions_update_concrete_log`, `test_snooze_skip_and_adherence_summary`, `test_dashboard_and_history_include_medication_state`, `test_deactivate_removes_pending_doses_from_today_plan`**
- **سبب اختيار المقتطف:** اخترت مقطعاً يبرز تداخل الأدوية مع dashboard/history لأن هذا جوهري أيضاً في الأداء وفي صحة العقود.

```python
0223:     def test_snooze_skip_and_adherence_summary(self):
0224:         create_res = self._create_manual_medication()
0225:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
0226:         log_id = self.client_auth.get("/api/medications/today/").data[0]["log_id"]
0227: 
0228:         snooze_until = timezone.now() + timedelta(minutes=15)
0229:         snooze_res = self.client_auth.post(
0230:             f"/api/medications/doses/{log_id}/snooze/",
0231:             {"snoozed_until": snooze_until.isoformat()},
0232:             format="json",
0233:         )
0234:         self.assertEqual(snooze_res.status_code, status.HTTP_200_OK, snooze_res.data)
0235:         self.assertEqual(snooze_res.data["status"], "snoozed")
0236: 
0237:         skip_res = self.client_auth.post(
0238:             f"/api/medications/doses/{log_id}/skipped/",
0239:             {"reason": "doctor paused for one day"},
0240:             format="json",
0241:         )
0242:         self.assertEqual(skip_res.status_code, status.HTTP_200_OK, skip_res.data)
0243:         self.assertEqual(skip_res.data["status"], "skipped")
0244: 
0245:         summary_res = self.client_auth.get("/api/medications/adherence-summary/")
0246:         self.assertEqual(summary_res.status_code, status.HTTP_200_OK)
0247:         self.assertGreaterEqual(summary_res.data["expected_doses"], 1)
0248:         self.assertEqual(summary_res.data["skipped_doses"], 1)
0249: 
0250:     def test_dashboard_and_history_include_medication_state(self):
0251:         create_res = self._create_manual_medication()
0252:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
0253: 
0254:         dashboard = self.client_auth.get("/api/dashboard/")
0255:         self.assertEqual(dashboard.status_code, status.HTTP_200_OK)
0256:         self.assertIn("medications", dashboard.data)
0257:         self.assertEqual(dashboard.data["medications"]["active_medications"], 1)
0258: 
0259:         history = self.client_auth.get("/api/history/")
0260:         self.assertEqual(history.status_code, status.HTTP_200_OK)
0261:         self.assertIn("medication_total_doses", history.data["history"][-1])
0262: 
0263:     def test_deactivate_removes_pending_doses_from_today_plan(self):
0264:         create_res = self._create_manual_medication()
0265:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
0266:         medication_id = create_res.data["medication"]["id"]
0267:         self.assertTrue(self.client_auth.get("/api/medications/today/").data)
0268: 
0269:         deactivate_res = self.client_auth.post(f"/api/medications/{medication_id}/deactivate/")
0270:         self.assertEqual(deactivate_res.status_code, status.HTTP_200_OK, deactivate_res.data)
0271:         today_res = self.client_auth.get("/api/medications/today/")
0272:         self.assertEqual(today_res.status_code, status.HTTP_200_OK)
0273:         self.assertEqual(today_res.data, [])
0274: 
0275:     def test_other_user_cannot_access_dose_action(self):
0276:         create_res = self._create_manual_medication()
0277:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
0278:         log_id = self.client_auth.get("/api/medications/today/").data[0]["log_id"]
0279: 
0280:         res = self.other_client.post(
0281:             f"/api/medications/doses/{log_id}/missed/",
0282:             {},
0283:             format="json",
0284:         )
0285:         self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
0286: 
0287:     def test_overdue_condition_schedule_log_generation_avoids_non_atomic_insert(self):
0288:         condition = self._condition()
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_constraints.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\constraints\test_constraints.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يختبر منطق حل القيود الصحية الناتجة عن الحالات المزمنة وملفات القواعد rule profiles.
- **ما الذي يختبره أو يفعّله:** يتحقق من materialization الافتراضي، وتسوية التعارضات، وإرجاع القيود النشطة عبر service وAPI.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `ConstraintResolutionTests`**
- **أبرز السيناريوهات: `test_resolution_materializes_profile_defaults`, `test_conflict_resolution_caps_profile_target_with_condition_max`, `test_recompute_dispatcher_supersedes_previous_constraints`, `test_tracker_read_service_and_api_return_active_constraints`**
- **سبب اختيار المقتطف:** المقتطف يوضح منطق conflict resolution وهو جزء أساسي من سلوك chronic care.

```python
0019: class ConstraintResolutionTests(TestCase):
0020:     def setUp(self):
0021:         self.user = create_user_with_profile(username="constraint-user", weight=91, height=175)
0022:         self.client = auth_client_for_user(self.user)
0023:         self.profile = self.user.userprofile
0024:         self.profile.daily_water_target = 3.0
0025:         self.profile.daily_calorie_target = 2100
0026:         self.profile.daily_step_goal = 7000
0027:         self.profile.daily_burn_goal = 350
0028:         self.profile.recommended_sleep_hours = 7.5
0029:         self.profile.save(
0030:             update_fields=[
0031:                 "daily_water_target",
0032:                 "daily_calorie_target",
0033:                 "daily_step_goal",
0034:                 "daily_burn_goal",
0035:                 "recommended_sleep_hours",
0036:             ]
0037:         )
0038:         ResolvedTrackerConstraint.objects.filter(user=self.user).delete()
0039:         ConstraintResolutionRun.objects.filter(user=self.user).delete()
0040: 
0041:     def test_resolution_materializes_profile_defaults(self):
0042:         run = ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
0043: 
0044:         self.assertEqual(run.run_status, ConstraintResolutionRun.STATUS_COMPLETED)
0045:         self.assertGreater(run.total_constraints_generated, 0)
0046: 
0047:         water_constraint = ResolvedTrackerConstraint.objects.get(
0048:             user=self.user,
0049:             status=ResolvedTrackerConstraint.STATUS_ACTIVE,
0050:             tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
0051:             metric_key="daily_water_liters",
0052:             rule_type=ResolvedTrackerConstraint.RULE_TARGET,
0053:         )
0054:         self.assertEqual(water_constraint.source_type, ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT)
0055:         self.assertAlmostEqual(water_constraint.target_value, 3.0)
0056: 
0057:     def test_conflict_resolution_caps_profile_target_with_condition_max(self):
0058:         self._create_hydration_max_condition(max_liters=2.0)
0059: 
0060:         ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
0061: 
0062:         effective_target = ResolvedTrackerConstraint.objects.get(
0063:             user=self.user,
0064:             status=ResolvedTrackerConstraint.STATUS_ACTIVE,
0065:             tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
0066:             metric_key="daily_water_liters",
0067:             rule_type=ResolvedTrackerConstraint.RULE_TARGET,
0068:         )
0069:         self.assertEqual(
0070:             effective_target.source_type,
0071:             ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE,
0072:         )
0073:         self.assertAlmostEqual(effective_target.target_value, 2.0)
0074:         self.assertEqual(
0075:             effective_target.explanation_payload["resolution_policy"],
0076:             "target_capped_by_safety_max",
0077:         )
0078: 
0079:         read_value = ConstraintReadService.effective_numeric_value(
0080:             user=self.user,
0081:             tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
0082:             metric_key="daily_water_liters",
0083:             fallback=3.0,
0084:         )
0085:         self.assertAlmostEqual(read_value, 2.0)
0086: 
0087:     def test_recompute_dispatcher_supersedes_previous_constraints(self):
0088:         ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
0089:         self.profile.daily_water_target = 2.7
0090:         self.profile.save(update_fields=["daily_water_target"])
0091: 
0092:         run = ConstraintRecomputeDispatcher.dispatch_for_user(
0093:             user=self.user,
0094:             trigger_type=ConstraintResolutionRun.TRIGGER_USER_PROFILE,
0095:             trigger_reference=str(self.profile.id),
0096:         )
0097: 
0098:         self.assertEqual(run.run_status, ConstraintResolutionRun.STATUS_COMPLETED)
0099:         self.assertGreater(run.total_constraints_superseded, 0)
0100:         active_value = ConstraintReadService.effective_numeric_value(
0101:             user=self.user,
0102:             tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
0103:             metric_key="daily_water_liters",
0104:         )
0105:         self.assertAlmostEqual(active_value, 2.7)
0106:         self.assertTrue(
0107:             ResolvedTrackerConstraint.objects.filter(
0108:                 user=self.user,
0109:                 status=ResolvedTrackerConstraint.STATUS_SUPERSEDED,
0110:             ).exists()
0111:         )
0112: 
0113:     def test_tracker_read_service_and_api_return_active_constraints(self):
0114:         ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
0115: 
0116:         summary = ConstraintReadService.active_summary_for_user(user=self.user)
0117:         self.assertIn(ResolvedTrackerConstraint.TRACKER_HYDRATION, summary)
0118: 
0119:         res = self.client.get("/api/health/constraints/hydration/")
0120:         self.assertEqual(res.status_code, status.HTTP_200_OK)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_water.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\hydration\test_water.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي شرب الماء والمشروبات المرتبطة بالـ catalog، والتكامل مع nutrition/hydration والـ points.
- **ما الذي يختبره أو يفعّله:** يتحقق من التخزين، التحديث، الحذف، انعكاس التقدم على dashboard، وربط beverage logs مع meal logs عند الحاجة.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `WaterTests`**
- **أبرز السيناريوهات: `test_create_water_log_and_persist`, `test_create_beverage_log_and_persist_metadata_from_legacy_catalog_match`, `test_catalog_beverage_logging_updates_nutrition_and_hydration`, `test_custom_beverage_reusable_is_private_and_searchable`, `test_patch_water_log_updates_linked_meal_log`, `test_delete_water_log_deletes_linked_meal_log`, `test_dashboard_hydration_reflects_water`, `test_points_awarded_on_water_log`**
- **سبب اختيار المقتطف:** المقتطف المختار يظهر تكامل الماء مع dashboard والـ points، لا مجرد إنشاء سجل ماء بسيط.

```python
0153:     def test_patch_water_log_updates_linked_meal_log(self):
0154:         tea = self._create_beverage(name="Black Tea", category="Tea", calories=1, caffeine=20)
0155:         coffee = self._create_beverage(name="Americano", category="Coffee", calories=2, caffeine=40)
0156: 
0157:         create_res = self.client_auth.post(
0158:             "/api/water/",
0159:             {"food_item": tea.id, "amount_ml": 200},
0160:             format="json",
0161:         )
0162:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
0163:         meal_id = create_res.data["linked_meal_log"]
0164:         log_id = create_res.data["id"]
0165: 
0166:         patch_res = self.client_auth.patch(
0167:             f"/api/water/{log_id}/",
0168:             {"food_item": coffee.id, "amount_ml": 100},
0169:             format="json",
0170:         )
0171:         self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
0172: 
0173:         log = WaterLog.objects.get(id=log_id)
0174:         self.assertEqual(log.food_item_id, coffee.id)
0175:         self.assertEqual(log.linked_meal_log_id, meal_id)
0176:         self.assertEqual(log.linked_meal_log.food_id, coffee.id)
0177:         self.assertEqual(log.linked_meal_log.milliliters_consumed, 100.0)
0178:         self.assertAlmostEqual(log.linked_meal_log.snapshot_caffeine_mg, 40.0)
0179: 
0180:     def test_delete_water_log_deletes_linked_meal_log(self):
0181:         coffee = self._create_beverage(name="Latte", category="Coffee", calories=30, caffeine=35)
0182:         create_res = self.client_auth.post(
0183:             "/api/water/",
0184:             {"food_item": coffee.id, "amount_ml": 150},
0185:             format="json",
0186:         )
0187:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
0188: 
0189:         log_id = create_res.data["id"]
0190:         meal_id = create_res.data["linked_meal_log"]
0191:         delete_res = self.client_auth.delete(f"/api/water/{log_id}/")
0192:         self.assertEqual(delete_res.status_code, status.HTTP_204_NO_CONTENT)
0193:         self.assertFalse(WaterLog.objects.filter(id=log_id).exists())
0194:         self.assertFalse(MealLog.objects.filter(id=meal_id).exists())
0195: 
0196:     def test_dashboard_hydration_reflects_water(self):
0197:         self.client_auth.post("/api/water/", {"amount_liter": 0.7}, format="json")
0198:         dash = self.client_auth.get("/api/dashboard/")
0199:         self.assertEqual(dash.status_code, status.HTTP_200_OK)
0200:         hydration = dash.data["hydration"]
0201:         self.assertGreaterEqual(float(hydration["current"]), 0.7)
0202: 
0203:     def test_points_awarded_on_water_log(self):
0204:         self.client_auth.post("/api/water/", {"amount_liter": 0.25}, format="json")
0205:         score = UserScore.objects.get(user=self.user)
0206:         self.assertGreaterEqual(score.total_points, 5)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_nutrition.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\nutrition\test_nutrition.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي الوجبات والمشروبات والـ nutrition snapshots وربط المشروبات بالترطيب والبحث في الطعام.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن التغذية تؤثر فعلاً على dashboard وأن snapshots تبقى ثابتة حتى لو تغيرت بيانات المصدر لاحقاً.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `NutritionTests`**
- **أبرز السيناريوهات: `test_food_and_meal_log_calories_reflected_in_dashboard`, `test_beverage_logging_by_ml_stores_snapshot`, `test_nutrition_snapshot_does_not_change_when_facts_change`, `test_patch_meal_log_keeps_meal_type_and_updates_amount`, `test_updating_drink_meal_updates_linked_hydration_progress`, `test_deleting_drink_meal_deletes_linked_hydration_log`, `test_food_search_uses_alias_category_and_filters`**
- **سبب اختيار المقتطف:** المقتطف يبرز قيمة snapshot وعدم إعادة كتابة التاريخ الغذائي عند تغير البيانات المرجعية.

```python
0116:     def test_nutrition_snapshot_does_not_change_when_facts_change(self):
0117:         coffee = FoodItem.objects.create(
0118:             name="Espresso",
0119:             item_type=FoodItem.TYPE_BEVERAGE,
0120:             density_g_per_ml=1.0,
0121:             calories_100g=4,
0122:         )
0123:         NutritionFacts.objects.create(
0124:             food_item=coffee,
0125:             basis_type=NutritionFacts.BASIS_PER_100ML,
0126:             basis_value=100,
0127:             calories_kcal=4,
0128:             caffeine_mg=80,
0129:         )
0130:         NutritionServingOption.objects.create(
0131:             food_item=coffee,
0132:             name="Shot 30ml",
0133:             amount=1,
0134:             unit="serving",
0135:             grams_equivalent=30,
0136:             milliliters_equivalent=30,
0137:             is_default=True,
0138:         )
0139: 
0140:         meal_res = self.client_auth.post(
0141:             "/api/meals/",
0142:             {"food": coffee.id, "meal_type": "drink", "quantity": 30, "unit": "ml"},
0143:             format="json",
0144:         )
0145:         self.assertEqual(meal_res.status_code, status.HTTP_201_CREATED)
0146:         log = MealLog.objects.get(id=meal_res.data["id"])
0147:         self.assertEqual(log.snapshot_caffeine_mg, 24)
0148: 
0149:         facts = coffee.nutrition_facts
0150:         facts.caffeine_mg = 200
0151:         facts.save()
0152: 
0153:         log.refresh_from_db()
0154:         self.assertEqual(log.snapshot_caffeine_mg, 24)
0155: 
0156:     def test_patch_meal_log_keeps_meal_type_and_updates_amount(self):
0157:         food = create_food_item(name="Rice", calories_100g=130)
0158: 
0159:         create_res = self.client_auth.post(
0160:             "/api/meals/",
0161:             {"food": food.id, "meal_type": "lunch", "quantity_grams": 100},
0162:             format="json",
0163:         )
0164:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
0165: 
0166:         meal_id = create_res.data["id"]
0167:         patch_res = self.client_auth.patch(
0168:             f"/api/meals/{meal_id}/",
0169:             {"quantity_grams": 200},
0170:             format="json",
0171:         )
0172:         self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
0173: 
0174:         meal = MealLog.objects.get(id=meal_id)
0175:         self.assertEqual(meal.meal_type, "lunch")
0176:         self.assertEqual(meal.quantity_grams, 200)
0177:         self.assertEqual(patch_res.data["total_calories"], 260)
0178: 
0179:     def test_updating_drink_meal_updates_linked_hydration_progress(self):
0180:         drink = FoodItem.objects.create(
0181:             name="Orange Juice",
0182:             item_type=FoodItem.TYPE_BEVERAGE,
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_seed_integration_user.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\management\test_seed_integration_user.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** اختبارات مباشرة لأمر `seed_integration_user` لضمان ثبات مستخدم الاختبار وإعادة ضبط حالته فقط.
- **ما الذي يختبره أو يفعّله:** تتحقق من reproducibility، ومن حذف حالة المستخدم السابقة عند `--reset`، ومن رفض السيناريوهات غير المعروفة.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `SeedIntegrationUserCommandTests`**
- **أبرز السيناريوهات: `test_command_creates_reproducible_e2e_user`, `test_reset_clears_existing_user_specific_state`, `test_unknown_scenario_is_rejected`**
- **سبب اختيار المقتطف:** المقتطف المختار يوضح أن الـ seed نفسه مغطى باختبار backend مستقل، وليس مجرد utility بلا حماية.

```python
0015: class SeedIntegrationUserCommandTests(TestCase):
0016:     def test_command_creates_reproducible_e2e_user(self):
0017:         call_command("seed_integration_user", scenario="chronic_flow", reset=True)
0018: 
0019:         user = User.objects.get(username="e2e_chronic")
0020:         self.assertTrue(user.check_password("Pass123!"))
0021:         self.assertIsNotNone(user.userprofile)
0022: 
0023:         score = UserScore.objects.get(user=user)
0024:         self.assertEqual(score.total_points, 0)
0025:         self.assertEqual(score.level, 1)
0026:         self.assertFalse(UserCondition.objects.filter(user=user).exists())
0027:         self.assertFalse(WaterLog.objects.filter(user=user).exists())
0028:         self.assertFalse(MealLog.objects.filter(user=user).exists())
0029: 
0030:     def test_reset_clears_existing_user_specific_state(self):
0031:         user = create_user_with_profile(username="e2e_chronic")
0032:         UserScore.objects.update_or_create(
0033:             user=user,
0034:             defaults={"total_points": 250, "level": 3},
0035:         )
0036: 
0037:         condition_type = ConditionType.objects.filter(slug="hypertension").first()
0038:         self.assertIsNotNone(condition_type)
0039:         UserCondition.objects.create(
0040:             user=user,
0041:             condition_type=condition_type,
0042:             status="active",
0043:             severity_code="stage_1",
0044:         )
0045:         WaterLog.objects.create(user=user, amount_liter=0.4)
0046:         MealLog.objects.create(
0047:             user=user,
0048:             food=create_food_item(name="Reset Meal"),
0049:             meal_type="lunch",
0050:             quantity_grams=120,
0051:         )
0052: 
0053:         call_command("seed_integration_user", scenario="chronic_flow", reset=True)
0054: 
0055:         user.refresh_from_db()
0056:         score = UserScore.objects.get(user=user)
0057:         self.assertEqual(score.total_points, 0)
0058:         self.assertEqual(score.level, 1)
0059:         self.assertFalse(UserCondition.objects.filter(user=user).exists())
0060:         self.assertFalse(WaterLog.objects.filter(user=user).exists())
0061:         self.assertFalse(MealLog.objects.filter(user=user).exists())
0062: 
0063:     def test_unknown_scenario_is_rejected(self):
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_seed_performance_dataset.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\management\test_seed_performance_dataset.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** اختبارات لأمر `seed_performance_dataset` الذي يغذي Locust ببيانات تمثيلية قابلة لإعادة الإنتاج.
- **ما الذي يختبره أو يفعّله:** تتحقق من إنشاء pool الأداء، واستبدال الحالة السابقة عند reset، ورفض profile غير المدعوم.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `SeedPerformanceDatasetCommandTests`**
- **أبرز السيناريوهات: `test_command_creates_representative_dataset_for_seeded_pool`, `test_reset_replaces_existing_user_state`, `test_unknown_profile_is_rejected`**
- **سبب اختيار المقتطف:** هذا المقتطف يثبت أن بنية بيانات الأداء نفسها تم اختبارها، لا مجرد استخدامها لاحقاً في Locust.

```python
0019: class SeedPerformanceDatasetCommandTests(TestCase):
0020:     def test_command_creates_representative_dataset_for_seeded_pool(self):
0021:         call_command(
0022:             "seed_performance_dataset",
0023:             profile="representative",
0024:             reset=True,
0025:             user_count=2,
0026:             days=3,
0027:         )
0028: 
0029:         for username in ("locust0", "locust1"):
0030:             user = User.objects.get(username=username)
0031:             self.assertTrue(user.check_password("Pass123!"))
0032:             self.assertIsNotNone(user.userprofile)
0033: 
0034:             self.assertGreater(MealLog.objects.filter(user=user).count(), 0)
0035:             self.assertGreater(WaterLog.objects.filter(user=user).count(), 0)
0036:             self.assertGreater(StepLog.objects.filter(user=user).count(), 0)
0037:             self.assertGreater(SleepLog.objects.filter(user=user).count(), 0)
0038:             self.assertGreater(ActivityLog.objects.filter(user=user).count(), 0)
0039:             self.assertGreater(ConditionMedication.objects.filter(user=user).count(), 0)
0040:             self.assertGreater(ConditionMedicationLog.objects.filter(medication__user=user).count(), 0)
0041:             self.assertGreater(UserCondition.objects.filter(user=user).count(), 0)
0042:             self.assertFalse(UnifiedHealthState.objects.filter(user=user).exists())
0043: 
0044:     def test_reset_replaces_existing_user_state(self):
0045:         user = create_user_with_profile(username="locust0")
0046:         StepLog.objects.create(user=user, steps_count=800)
0047:         WaterLog.objects.create(user=user, amount_liter=0.3)
0048:         MealLog.objects.create(
0049:             user=user,
0050:             food=create_food_item(name="Old Meal"),
0051:             meal_type="lunch",
0052:             quantity_grams=120,
0053:         )
0054:         UnifiedHealthState.objects.create(
0055:             user=user,
0056:             state_date=user.userprofile.birth_date,
0057:             window_kind=UnifiedHealthState.WINDOW_CURRENT,
0058:         )
0059: 
0060:         call_command(
0061:             "seed_performance_dataset",
0062:             profile="representative",
0063:             reset=True,
0064:             user_count=1,
0065:             days=2,
0066:         )
0067: 
0068:         user = User.objects.get(username="locust0")
0069:         self.assertGreater(MealLog.objects.filter(user=user).count(), 0)
0070:         self.assertGreater(WaterLog.objects.filter(user=user).count(), 0)
0071:         self.assertGreater(StepLog.objects.filter(user=user).count(), 0)
0072:         self.assertFalse(UnifiedHealthState.objects.filter(user=user).exists())
0073: 
0074:     def test_unknown_profile_is_rejected(self):
0075:         with self.assertRaises(CommandError):
0076:             call_command("seed_performance_dataset", profile="unknown")
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_import_paths.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_import_paths.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** اختبار توافقية import paths بعد إعادة تنظيم الحزم، حتى لا ينكسر الكود القديم أثناء refactor.
- **ما الذي يختبره أو يفعّله:** يتحقق من بقاء المسارات القديمة والجديدة قابلة للاستيراد، وهو guard مهم في المشاريع التي تمر بعمليات restructuring.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `CoreImportCompatibilityTests`**
- **أبرز السيناريوهات: `test_models_barrel_exports_remain_available`, `test_legacy_service_and_repository_import_paths_still_work`, `test_new_structured_import_paths_are_available`**
- **سبب اختيار المقتطف:** المقتطف يوضح أن suite الجودة لا تقتصر على business logic، بل تشمل الاستقرار البنيوي للكود أيضاً.

```python
0001: from django.test import SimpleTestCase
0002: 
0003: 
0004: class CoreImportCompatibilityTests(SimpleTestCase):
0005:     def test_models_barrel_exports_remain_available(self):
0006:         from core.models import ConditionMedication, FoodItem, ResolvedTrackerConstraint, StepLog
0007: 
0008:         self.assertIsNotNone(FoodItem)
0009:         self.assertIsNotNone(StepLog)
0010:         self.assertIsNotNone(ConditionMedication)
0011:         self.assertIsNotNone(ResolvedTrackerConstraint)
0012: 
0013:     def test_legacy_service_and_repository_import_paths_still_work(self):
0014:         from core.repositories.step_log_repository import StepRepository
0015:         from core.repositories.food_item_repository import NutritionCatalogRepository
0016:         from core.services.health_tracker_coordinator import HealthTrackerCoordinator
0017:         from core.services.nutrition_service import NutritionService
0018: 
0019:         self.assertIsNotNone(StepRepository)
0020:         self.assertIsNotNone(NutritionCatalogRepository)
0021:         self.assertIsNotNone(HealthTrackerCoordinator)
0022:         self.assertIsNotNone(NutritionService)
0023: 
0024:     def test_new_structured_import_paths_are_available(self):
0025:         from core.api.nutrition.views import FoodItemViewSet
0026:         from core.repositories.medication.medication_repository import MedicationRepository
0027:         from core.services.chronic.condition_setup_service import ConditionSetupService
0028:         from core.services.tracking.steps_service import StepsService
0029: 
0030:         self.assertIsNotNone(FoodItemViewSet)
0031:         self.assertIsNotNone(MedicationRepository)
0032:         self.assertIsNotNone(ConditionSetupService)
0033:         self.assertIsNotNone(StepsService)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_isolation_and_permissions.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_isolation_and_permissions.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي حدود الصلاحيات والعزل بين المستخدمين على بعض endpoints الحساسة.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن الموارد المحمية تحتاج auth، وأن كل مستخدم يرى بياناته فقط في water logs والحالات المزمنة.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `PermissionsTests`**
- **أبرز السيناريوهات: `test_protected_endpoints_require_auth`, `test_cross_user_isolation_for_water_logs`, `test_cross_user_isolation_for_chronic_conditions`**
- **سبب اختيار المقتطف:** المقتطف يوضح بجلاء أن التحقق الأمني هنا functional security verification وليس مجرد role flag صامت.

```python
0008: class PermissionsTests(APITestCase):
0009:     protected_endpoints = [
0010:         "/api/meals/",
0011:         "/api/water/",
0012:         "/api/steps/",
0013:         "/api/sleep/",
0014:         "/api/activities/",
0015:         "/api/dashboard/",
0016:         "/api/history/",
0017:         "/api/condition-types/",
0018:         "/api/user-conditions/",
0019:         "/api/condition-medications/",
0020:         "/api/condition-medication-schedules/",
0021:         "/api/health-indicators/",
0022:     ]
0023: 
0024:     def test_protected_endpoints_require_auth(self):
0025:         for path in self.protected_endpoints:
0026:             res = self.client.get(path)
0027:             self.assertIn(
0028:                 res.status_code,
0029:                 (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN),
0030:                 msg=f"Path {path} should be protected",
0031:             )
0032: 
0033:     def test_cross_user_isolation_for_water_logs(self):
0034:         user_a = create_user_with_profile(username="userA")
0035:         user_b = create_user_with_profile(username="userB")
0036: 
0037:         client_a = auth_client_for_user(user_a)
0038:         client_b = auth_client_for_user(user_b)
0039: 
0040:         res_a = client_a.post("/api/water/", {"amount_liter": 1.0}, format="json")
0041:         self.assertEqual(res_a.status_code, status.HTTP_201_CREATED)
0042: 
0043:         res_b = client_b.get("/api/water/")
0044:         self.assertEqual(res_b.status_code, status.HTTP_200_OK)
0045:         self.assertEqual(len(res_b.data), 0, "User B should not see User A water logs")
0046: 
0047:     def test_cross_user_isolation_for_chronic_conditions(self):
0048:         user_a = create_user_with_profile(username="conditionUserA")
0049:         user_b = create_user_with_profile(username="conditionUserB")
0050: 
0051:         client_a = auth_client_for_user(user_a)
0052:         client_b = auth_client_for_user(user_b)
0053: 
0054:         condition_type_res = client_a.get("/api/condition-types/")
0055:         self.assertEqual(condition_type_res.status_code, status.HTTP_200_OK)
0056:         diabetes_id = next(
0057:             item["id"] for item in condition_type_res.data if item["code"] == "diabetes"
0058:         )
0059: 
0060:         create_res = client_a.post(
0061:             "/api/user-conditions/",
0062:             {
0063:                 "condition_type": diabetes_id,
0064:                 "status": "active",
0065:                 "severity_code": "diabetes_managed",
0066:             },
0067:             format="json",
0068:         )
0069:         self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
0070: 
0071:         res_b = client_b.get("/api/user-conditions/")
0072:         self.assertEqual(res_b.status_code, status.HTTP_200_OK)
0073:         self.assertEqual(len(res_b.data), 0, "User B should not see User A conditions")
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_activity.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_activity.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** اختبار مصغر يركز على حساب السعرات المحروقة من نشاط بدني وفق MET.
- **ما الذي يختبره أو يفعّله:** يتحقق من صحة معادلة الحرق في activity log.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `ActivityTests`**
- **أبرز السيناريوهات: `test_activity_calories_computed_from_met`**
- **سبب اختيار المقتطف:** الملف صغير ومباشر ويظهر نموذج unit-style backend test قصير ومركز.

```python
0001: from rest_framework import status
0002: from rest_framework.test import APITestCase
0003: 
0004: from test_utils.helpers import auth_client_for_user, create_exercise, create_user_with_profile
0005: 
0006: 
0007: class ActivityTests(APITestCase):
0008:     def setUp(self):
0009:         self.user = create_user_with_profile(username="activityuser", weight=70)
0010:         self.client_auth = auth_client_for_user(self.user)
0011:         self.exercise = create_exercise(name="Run", met_value=8.0)
0012: 
0013:     def test_activity_calories_computed_from_met(self):
0014:         res = self.client_auth.post(
0015:             "/api/activities/",
0016:             {"exercise": self.exercise.id, "duration_minutes": 30},
0017:             format="json",
0018:         )
0019:         self.assertEqual(res.status_code, status.HTTP_201_CREATED)
0020:         self.assertIn("calories_burned", res.data)
0021:         # Expected: (MET * 3.5 * weight / 200) * minutes = (8*3.5*70/200)*30 = 294
0022:         self.assertAlmostEqual(int(res.data["calories_burned"]), 294, delta=2)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_sleep.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_sleep.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** اختبار مخصص للتأكد من حساب مدة النوم وكون بعض الحقول read-only كما يجب.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن sleep duration لا تُكسر بعكس القيم المرسلة وأن endpoint يحسبها بشكل صحيح.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `SleepTests`**
- **أبرز السيناريوهات: `test_sleep_duration_computed_and_read_only`**
- **سبب اختيار المقتطف:** أبقيت المقتطف قصيراً لأن الملف نفسه يمثل مثالاً واضحاً على اختبار tracker متخصّص.

```python
0001: from datetime import timedelta
0002: 
0003: from django.utils import timezone
0004: from rest_framework import status
0005: from rest_framework.test import APITestCase
0006: 
0007: from core.models import SleepLog
0008: from test_utils.helpers import auth_client_for_user, create_user_with_profile
0009: 
0010: 
0011: class SleepTests(APITestCase):
0012:     def setUp(self):
0013:         self.user = create_user_with_profile(username="sleepuser")
0014:         self.client_auth = auth_client_for_user(self.user)
0015: 
0016:     def test_sleep_duration_computed_and_read_only(self):
0017:         start = timezone.now() - timedelta(hours=8)
0018:         end = timezone.now()
0019:         res = self.client_auth.post(
0020:             "/api/sleep/",
0021:             {
0022:                 "start_time": start.isoformat(),
0023:                 "end_time": end.isoformat(),
0024:                 "quality": "Deep",
0025:                 "duration_hours": 0,  # should be ignored
0026:             },
0027:             format="json",
0028:         )
0029:         self.assertEqual(res.status_code, status.HTTP_201_CREATED)
0030:         self.assertIn("duration_hours", res.data)
0031:         self.assertAlmostEqual(float(res.data["duration_hours"]), 8.0, delta=0.2)
0032: 
0033:         log = SleepLog.objects.get(user=self.user)
0034:         self.assertAlmostEqual(log.duration_hours, 8.0, delta=0.2)
0035:         self.assertNotEqual(float(res.data["duration_hours"]), 0)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_steps.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_steps.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي منطق upsert للخطوات والمسافة وقاعدة uniqueness على سجل اليوم الواحد.
- **ما الذي يختبره أو يفعّله:** يتحقق من عدم تكرار سجل الخطوات لنفس المستخدم/اليوم ومن احتساب المسافة تلقائياً عند نقص البيانات.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `StepsTests`**
- **أبرز السيناريوهات: `test_upsert_same_day_single_record`, `test_unique_per_user_date`, `test_distance_autocalculated_when_missing`, `test_repository_upsert_allows_zero_values`**
- **سبب اختيار المقتطف:** المقتطف يوضح التركيز على edge cases وقواعد البيانات لا على happy path فقط.

```python
0011: class StepsTests(APITestCase):
0012:     def setUp(self):
0013:         self.user = create_user_with_profile(username="stepsuser", height=175, weight=70)
0014:         self.client_auth = auth_client_for_user(self.user)
0015: 
0016:     def test_upsert_same_day_single_record(self):
0017:         r1 = self.client_auth.post("/api/steps/", {"steps_count": 1000, "distance_km": 1.0}, format="json")
0018:         self.assertIn(r1.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))
0019:         r2 = self.client_auth.post("/api/steps/", {"steps_count": 2000, "distance_km": 1.5}, format="json")
0020:         self.assertIn(r2.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))
0021: 
0022:         qs = StepLog.objects.filter(user=self.user)
0023:         self.assertEqual(qs.count(), 1)
0024:         self.assertEqual(qs.first().steps_count, 2000)
0025: 
0026:     def test_unique_per_user_date(self):
0027:         other = create_user_with_profile(username="other", height=180, weight=75)
0028:         client_other = auth_client_for_user(other)
0029: 
0030:         self.client_auth.post("/api/steps/", {"steps_count": 500, "distance_km": 0.4}, format="json")
0031:         client_other.post("/api/steps/", {"steps_count": 800, "distance_km": 0.6}, format="json")
0032: 
0033:         self.assertEqual(StepLog.objects.filter(user=self.user).count(), 1)
0034:         self.assertEqual(StepLog.objects.filter(user=other).count(), 1)
0035: 
0036:     def test_distance_autocalculated_when_missing(self):
0037:         res = self.client_auth.post("/api/steps/", {"steps_count": 2000}, format="json")
0038:         self.assertEqual(res.status_code, status.HTTP_201_CREATED)
0039:         self.assertIn("distance_km", res.data)
0040:         self.assertGreater(float(res.data["distance_km"]), 0)
0041: 
0042:     def test_repository_upsert_allows_zero_values(self):
0043:         StepRepository.upsert_for_user_date(
0044:             user=self.user,
0045:             log_date=date.today(),
0046:             steps_count=1200,
0047:             distance_km=0.95,
0048:         )
0049: 
0050:         updated = StepRepository.upsert_for_user_date(
0051:             user=self.user,
0052:             log_date=date.today(),
0053:             steps_count=0,
0054:             distance_km=0,
0055:         )
0056: 
0057:         self.assertEqual(updated.steps_count, 0)
0058:         self.assertEqual(updated.distance_km, 0)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_auth.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\users\tests\test_auth.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي التسجيل والدخول واسترجاع/تعديل الملف الشخصي والتوافق الخلفي لحقل `age` مع `birth_date`.
- **ما الذي يختبره أو يفعّله:** يتحقق من JWT login، وفشل كلمة المرور الخاطئة، وتعديل profile. كما يوثق gap معروف عبر `expectedFailure` في uniqueness للبريد الإلكتروني.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `AuthTests`**
- **أبرز السيناريوهات: `test_registration_success`, `test_registration_existing_email_fails`, `test_login_success_returns_tokens`, `test_login_wrong_password_fails`, `test_me_returns_profile`, `test_me_update_profile`, `test_me_update_profile_accepts_age`, `test_me_update_profile_accepts_birth_date`**
- **سبب اختيار المقتطف:** المقتطف المختار مهم لأنه يكشف أيضاً فجوة معروفة موثقة داخل suite نفسها، وهذا يزيد قيمة التقرير التحليلية.

```python
0011: class AuthTests(APITestCase):
0012:     def test_registration_success(self):
0013:         payload = {
0014:             "username": "newuser",
0015:             "password": "Secret123!",
0016:             "email": "newuser@example.com",
0017:             "first_name": "New",
0018:             "last_name": "User",
0019:         }
0020:         res = self.client.post("/api/auth/register/", payload, format="json")
0021:         self.assertEqual(res.status_code, status.HTTP_201_CREATED)
0022:         user = User.objects.get(username="newuser")
0023:         self.assertTrue(user.check_password(payload["password"]))
0024: 
0025:     @unittest.expectedFailure
0026:     def test_registration_existing_email_fails(self):
0027:         """
0028:         Known gap: email is not enforced unique in the current serializer.
0029:         Marked expectedFailure to document requirement vs. implementation.
0030:         """
0031:         create_user_with_profile(username="user1", email="dup@example.com")
0032:         res = self.client.post(
0033:             "/api/auth/register/",
0034:             {
0035:                 "username": "user2",
0036:                 "password": "Secret123!",
0037:                 "email": "dup@example.com",
0038:                 "first_name": "Dup",
0039:                 "last_name": "User",
0040:             },
0041:             format="json",
0042:         )
0043:         self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
0044: 
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_profile_metrics.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\users\tests\test_profile_metrics.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي حساب الأهداف اليومية ووقت النوم المتوقع من profile metrics.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن خدمة حساب المقاييس الأساسية للمستخدم تعطي نتائج متناسقة قبل أن تستهلكها بقية الطبقات.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `ProfileMetricsCalculatorTests`**
- **أبرز السيناريوهات: `test_calculates_daily_targets_and_bedtime`, `test_apply_updates_profile_fields`**
- **سبب اختيار المقتطف:** المقتطف يوضح أن backend لا يختبر endpoints فقط، بل يختبر الخدمات الحسابية الأساسية أيضاً.

```python
0001: from datetime import time
0002: 
0003: from django.test import TestCase
0004: 
0005: from test_utils.helpers import create_user_with_profile
0006: from users.services.profile_metrics_calculator import ProfileMetricsCalculator
0007: 
0008: 
0009: class ProfileMetricsCalculatorTests(TestCase):
0010:     def test_calculates_daily_targets_and_bedtime(self):
0011:         user = create_user_with_profile(
0012:             username="metricsuser",
0013:             weight=82,
0014:             height=182,
0015:             activity_level=1.55,
0016:         )
0017:         profile = user.userprofile
0018:         profile.goal = "lose"
0019:         profile.recommended_sleep_hours = 7.5
0020:         profile.target_wake_time = time(7, 0)
0021: 
0022:         metrics = ProfileMetricsCalculator.calculate(profile)
0023: 
0024:         self.assertGreater(metrics.daily_calorie_target, 0)
0025:         self.assertGreater(metrics.daily_water_target, 0)
0026:         self.assertGreaterEqual(metrics.daily_step_goal, 5000)
0027:         self.assertGreater(metrics.daily_burn_goal, 0)
0028:         self.assertEqual(metrics.target_bed_time, time(23, 30))
0029: 
0030:     def test_apply_updates_profile_fields(self):
0031:         user = create_user_with_profile(username="metricsapply")
0032:         profile = user.userprofile
0033:         profile.weight = 90
0034:         profile.height = 180
0035:         profile.goal = "gain"
0036: 
0037:         ProfileMetricsCalculator.apply(profile, persist=True)
0038:         profile.refresh_from_db()
0039: 
0040:         self.assertGreater(profile.daily_calorie_target, 0)
0041:         self.assertGreater(profile.daily_water_target, 0)
0042:         self.assertGreater(profile.daily_step_goal, 0)
0043:         self.assertGreater(profile.daily_burn_goal, 0)
0044:         self.assertGreater(profile.bmi, 0)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `test_points.py`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\gamification\tests\test_points.py`
- **الفئة:** `Backend Test File`
- **الغرض الأساسي:** يغطي نقاط gamification، التدرج بالمستوى، عدم النزول تحت الصفر، وعقوبة تجاوز السعرات.
- **ما الذي يختبره أو يفعّله:** يتحقق من business logic مستقل نسبياً عن باقي الوحدات لكنه يؤثر على dashboard والملخص العام.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `PointsServiceTests`**
- **أبرز السيناريوهات: `test_award_points_and_level_progression`, `test_deduct_points_not_below_zero`, `test_meal_penalty_when_over_target`**
- **سبب اختيار المقتطف:** الملف صغير وواضح، ويخدم التقرير كمثال على اختبار خدمة domain صافية.

```python
0001: from django.test import TestCase
0002: 
0003: from gamification.models import UserScore
0004: from gamification.services.points_service import PointsService
0005: from test_utils.helpers import create_user_with_profile
0006: 
0007: 
0008: class PointsServiceTests(TestCase):
0009:     def setUp(self):
0010:         self.user = create_user_with_profile(username="pointsuser", weight=70)
0011: 
0012:     def test_award_points_and_level_progression(self):
0013:         PointsService.add_points(self.user, 1200)
0014:         score = UserScore.objects.get(user=self.user)
0015:         self.assertEqual(score.total_points, 1200)
0016:         self.assertEqual(score.level, 2)
0017: 
0018:     def test_deduct_points_not_below_zero(self):
0019:         PointsService.add_points(self.user, 10)
0020:         PointsService.deduct_points(self.user, 50)
0021:         score = UserScore.objects.get(user=self.user)
0022:         self.assertEqual(score.total_points, 0)
0023: 
0024:     def test_meal_penalty_when_over_target(self):
0025:         # target calorie default from profile.calculate_metrics
0026:         PointsService.apply_meal_points(self.user, calories_in=5000, target=2000)
0027:         score = UserScore.objects.get(user=self.user)
0028:         self.assertLessEqual(score.total_points, 0)
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Testability Support File

#### `pubspec.yaml`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\pubspec.yaml`
- **الفئة:** `Testability Support File`
- **الغرض الأساسي:** يعرف اعتماديات Flutter الرسمية، ومن زاوية الاختبار يهمنا وجود `flutter_test` و`integration_test` في `dev_dependencies`.
- **ما الذي يختبره أو يفعّله:** يوثق أن طبقة frontend تملك أدوات الاختبار الرسمية ضمن المشروع نفسه لا عبر أدوات خارجية غير مصرح بها.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** المقتطف يبين صراحة إضافة `integration_test` واعتماد `flutter_test` ضمن البيئة التطويرية.

```yaml
0034:   dio: ^5.7.0
0035:   flutter_secure_storage: ^9.2.2
0036:   flutter_local_notifications: ^17.0.0
0037:   timezone: ^0.9.2
0038:   shared_preferences: ^2.2.3
0039:   pedometer: ^4.1.1
0040:   permission_handler: ^11.1.0
0041:   intl: ^0.19.0
0042: 
0043:   # The following adds the Cupertino Icons font to your application.
0044:   # Use with the CupertinoIcons class for iOS style icons.
0045:   cupertino_icons: ^1.0.8
0046: 
0047: dev_dependencies:
0048:   flutter_test:
0049:     sdk: flutter
0050:   integration_test:
0051:     sdk: flutter
0052: 
0053:   # The "flutter_lints" package below contains a set of recommended lints to
0054:   # encourage good coding practices. The lint set provided by the package is
0055:   # activated in the `analysis_options.yaml` file located at the root of your
0056:   # package. See that file for information about deactivating specific lint
0057:   # rules and activating additional ones.
0058:   flutter_lints: ^6.0.0
0059: 
0060: # For information on the generic Dart part of this file, see the
0061: # following page: https://dart.dev/tools/pub/pubspec
0062: 
0063: # The following section is specific to Flutter packages.
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `bootstrap.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\bootstrap.dart`
- **الفئة:** `Testability Support File`
- **الغرض الأساسي:** يفصل إقلاع التطبيق عن `main.dart` ويتيح تشغيله مع تعطيل notifications في وضع integration tests.
- **ما الذي يختبره أو يفعّله:** يتحقق تصميمياً من أن الاختبارات يمكنها إقلاع التطبيق الحقيقي مع تخفيف أسباب flakiness على الـ emulator.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** هذا المقتطف هو أساس bootstrap القابل للاختبار، وهو خطوة محورية في Stage 3 من العمل.

```dart
0001: import 'package:flutter/material.dart';
0002: 
0003: import 'app.dart';
0004: import 'core/network/http_client.dart';
0005: import 'core/notifications/notifications_service.dart';
0006: import 'core/runtime/app_runtime.dart';
0007: 
0008: Future<void> runVitaMateApp({bool enableNotifications = true}) async {
0009:   WidgetsFlutterBinding.ensureInitialized();
0010: 
0011:   AppRuntime.configure(enableNotifications: enableNotifications);
0012: 
0013:   if (AppRuntime.notificationsEnabled) {
0014:     await NotificationsService.init();
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `main.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\main.dart`
- **الفئة:** `Testability Support File`
- **الغرض الأساسي:** entrypoint الإنتاجي البسيط الذي يستدعي bootstrap المشترك دون تخصيصات خاصة بالاختبار.
- **ما الذي يختبره أو يفعّله:** يحافظ على فصل واضح بين تشغيل الإنتاج وتشغيل الاختبار.
- **الأهمية داخل المنظومة:** `supportive`
- **سبب اختيار المقتطف:** المقتطف قصير لكنه يثبت أن main لم يعد يحمل تعقيد التهيئة مباشرة.

```dart
0001: import 'bootstrap.dart';
0002: 
0003: Future<void> main() async {
0004:   await runVitaMateApp();
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `app_test_keys.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\core\testing\app_test_keys.dart`
- **الفئة:** `Testability Support File`
- **الغرض الأساسي:** مصفوفة المفاتيح الثابتة لعناصر الواجهة الحرجة التي تعتمد عليها Flutter integration tests.
- **ما الذي يختبره أو يفعّله:** تضمن selectors مستقرة وغير معتمدة فقط على نصوص UI، خصوصاً في login وhome وchronic flows.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `AppTestKeys`**
- **سبب اختيار المقتطف:** المقتطف يبين مباشرة naming convention للمفاتيح وكيف جرى تعميمها على المسارات الحيوية.

```dart
0001: class AppTestKeys {
0002:   AppTestKeys._();
0003: 
0004:   static const loginUsernameField = 'login.usernameField';
0005:   static const loginPasswordField = 'login.passwordField';
0006:   static const loginSubmitButton = 'login.submitButton';
0007: 
0008:   static const homeConditionsCenterAddButton =
0009:       'home.conditionsCenter.addButton';
0010:   static const homeConditionsCenterOpenButton =
0011:       'home.conditionsCenter.openButton';
0012: 
0013:   static const chronicScreenHeader = 'chronic.screen.header';
0014:   static const chronicCreateSaveButton = 'chronic.create.saveButton';
0015:   static const chronicDetailAddReadingButton =
0016:       'chronic.detail.addReadingButton';
0017:   static const chronicDetailSummaryCard = 'chronic.detail.summaryCard';
0018:   static const chronicDetailReadingsList = 'chronic.detail.readingsList';
0019:   static const chronicReadingSaveButton = 'chronic.reading.saveButton';
0020:   static const chronicDetailBackButton = 'chronic.detail.backButton';
0021: 
0022:   static String homeConditionCard(String slug) =>
0023:       'home.conditionsCenter.card.$slug';
0024: 
0025:   static String chronicSupportedAddButton(String slug) =>
0026:       'chronic.supported.$slug.addButton';
0027: 
0028:   static String chronicCreateField({
0029:     required String slug,
0030:     required String field,
0031:   }) => 'chronic.create.$slug.$field';
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Frontend Test File

#### `auth_controller_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_controller_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي AuthController نفسه: نجاح login وتحوّل أخطاء Dio إلى رسائل مناسبة للمستخدم.
- **ما الذي يختبره أو يفعّله:** يتحقق من منطق state management في طبقة controller دون تشغيل واجهة كاملة.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeAuthRepository`**
- **أبرز السيناريوهات: `login populates typed me state`, `login maps dio auth errors to a user-facing message`**
- **ملاحظة:** تم الاعتماد على أسماء السيناريوهات من الملف نفسه في الشرح التفصيلي.

```dart
0062:   setUpAll(() {
0063:     HttpClient.initForTesting();
0064:   });
0065: 
0066:   test('login populates typed me state', () async {
0067:     final controller = AuthController(
0068:       repo: _FakeAuthRepository(user: _sampleUser()),
0069:     );
0070: 
0071:     final success = await controller.login('salam', 'Secret123');
0072: 
0073:     expect(success, isTrue);
0074:     expect(controller.error, isNull);
0075:     expect(controller.isLoading, isFalse);
0076:     expect(controller.me, isNotNull);
0077:     expect(controller.me!.fullName, 'Salam Ayash');
0078:     expect(controller.me!.profile.dailyStepGoal, 9000);
0079:   });
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `auth_flow_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_flow_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** اختبار widget/flow لشاشة الدخول مع HTTP adapter وهمي وقنوات plugins مزيفة لتجنب MissingPluginException.
- **ما الذي يختبره أو يفعّله:** يتحقق من validators، تعبئة الحقول، نجاح login، ثم الانتقال إلى route الـ Home.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `FakeAdapter`**
- **أبرز السيناريوهات: `Login validators and successful navigation`**
- **سبب اختيار المقتطف:** المقتطف يوضح كيف تم عزل شاشة login عن الشبكة الحقيقية مع إبقاء السلوك نفسه من منظور الواجهة.

```dart
0039: void main() {
0040:   TestWidgetsFlutterBinding.ensureInitialized();
0041: 
0042:   setUp(() {
0043:     // Mock secure storage channel to avoid MissingPluginException.
0044:     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
0045:         .setMockMethodCallHandler(
0046:           const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
0047:           (call) async => null,
0048:         );
0049: 
0050:     // Mock notifications channel to avoid plugin errors on showWelcomeBack.
0051:     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
0052:         .setMockMethodCallHandler(
0053:           const MethodChannel('dexterous.com/flutter/local_notifications'),
0054:           (call) async => null,
0055:         );
0056: 
0057:     // Provide fake HTTP responses for login.
0058:     HttpClient.initForTesting();
0059:     HttpClient.dio.httpClientAdapter = FakeAdapter({
0060:       "POST /api/auth/login/": ResponseBody.fromString(
0061:         jsonEncode({"access": "tok", "refresh": "rtok"}),
0062:         200,
0063:         headers: {
0064:           Headers.contentTypeHeader: [Headers.jsonContentType],
0065:         },
0066:       ),
0067:       "GET /api/auth/me/": ResponseBody.fromString(
0068:         jsonEncode({
0069:           "username": "user1",
0070:           "first_name": "User",
0071:           "last_name": "One",
0072:           "email": "user1@example.com",
0073:           "profile": {
0074:             "weight": 80,
0075:             "height": 175,
0076:             "activity_level": 1.55,
0077:             "goal": "maintain",
0078:             "daily_step_goal": 8000,
0079:             "gender": "male",
0080:             "birth_date": "2000-01-01",
0081:             "recommended_sleep_hours": 8,
0082:             "target_wake_time": "07:00:00",
0083:             "target_bed_time": "23:00:00",
0084:             "enable_sleep_improvement": true,
0085:             "preferred_activity_type": "walking",
0086:             "enable_activity_reminders": true,
0087:             "activity_reminder_interval_hours": 2,
0088:             "enable_water_reminders": true,
0089:             "water_reminder_interval_minutes": 60,
0090:           }
0091:         }),
0092:         200,
0093:         headers: {
0094:           Headers.contentTypeHeader: [Headers.jsonContentType],
0095:         },
0096:       ),
0097:     });
0098:   });
0099: 
0100:   testWidgets('Login validators and successful navigation', (tester) async {
0101:     // Minimal app with login and dummy home route.
0102:     await tester.pumpWidget(
0103:       MaterialApp(
0104:         initialRoute: Routes.login,
0105:         routes: {
0106:           Routes.login: (_) => const LoginScreen(),
0107:           Routes.home: (_) => const Scaffold(body: Text('Home')),
0108:         },
0109:       ),
0110:     );
0111: 
0112:     // Tap login with empty fields -> validators trigger.
0113:     await tester.ensureVisible(find.text('Sign In'));
0114:     await tester.tap(find.text('Sign In'));
0115:     await tester.pump();
0116:     expect(find.text('Username is required'), findsOneWidget);
0117:     expect(find.text('Password is required'), findsOneWidget);
0118: 
0119:     // Fill fields and login.
0120:     await tester.enterText(find.byType(TextFormField).at(0), 'user1');
0121:     await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
0122:     await tester.ensureVisible(find.text('Sign In'));
0123:     await tester.tap(find.text('Sign In'));
0124:     await tester.pumpAndSettle();
0125: 
0126:     // Navigation to Home succeeded.
0127:     expect(find.text('Home'), findsOneWidget);
0128:   });
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `auth_interceptor_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_interceptor_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي سلوك interceptor الخاص بالتوكن: refresh عند انتهاء access token، ومسح التخزين عندما يفشل refresh أيضاً.
- **ما الذي يختبره أو يفعّله:** يتحقق من صلابة طبقة networking في frontend عند التعامل مع JWT expiry.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_AuthAdapter`**
- **أبرز السيناريوهات: `refreshes expired access token and retries the request once`, `clears stored tokens when refresh also expires`**
- **ملاحظة:** تم استخدام أسماء السيناريوهات المستخرجة آلياً في التقرير.

```dart
0097:     HttpClient.initForTesting();
0098:     await SecureStorage.clear();
0099:   });
0100: 
0101:   test('refreshes expired access token and retries the request once', () async {
0102:     final adapter = _AuthAdapter(refreshSucceeds: true);
0103:     HttpClient.setTestAdapter(adapter);
0104:     await SecureStorage.saveTokens(
0105:       access: 'expired-access',
0106:       refresh: 'refresh-token',
0107:     );
0108: 
0109:     final response = await HttpClient.dio.get(ApiEndpoints.water);
0110: 
0111:     expect(response.statusCode, 200);
0112:     expect(adapter.refreshCalls, 1);
0113:     expect(adapter.protectedCalls, 2);
0114:     expect(await SecureStorage.readAccessToken(), 'fresh-access');
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `notifications_schedule_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\notifications_schedule_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** اختبار صغير لكنه مهم لطبقة جدولة notifications المحلية.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن NotificationsService تستدعي scheduler المحلي بالمعاملات المتوقعة لخطط التذكير.
- **الأهمية داخل المنظومة:** `supportive`
- **أبرز السيناريوهات: `NotificationsService schedules steps reminder with expected calls`**

```dart
0007: 
0008: void main() {
0009:   TestWidgetsFlutterBinding.ensureInitialized();
0010: 
0011:   test('NotificationsService schedules steps reminder with expected calls',
0012:       () async {
0013:     // Initialize timezone to avoid tz errors.
0014:     tzdata.initializeTimeZones();
0015:     tz.setLocalLocation(tz.getLocation('UTC'));
0016: 
0017:     final calls = <String>[];
0018:     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
0019:         .setMockMethodCallHandler(
0020:       const MethodChannel('dexterous.com/flutter/local_notifications'),
0021:       (call) async {
0022:         calls.add(call.method);
0023:         return null;
0024:       },
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `steps_permission_ui_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\steps_permission_ui_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي سلوك الواجهة عندما تُرفض صلاحية الخطوات.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن المستخدم يرى رسالة طلب الإذن المناسبة بدلاً من انهيار الواجهة أو سلوك صامت.
- **الأهمية داخل المنظومة:** `supportive`
- **الكلاسات: `FakeAdapter`**
- **أبرز السيناريوهات: `Steps screen shows permission request message when denied`**

```dart
0062:     HttpClient.initForTesting();
0063:     HttpClient.dio.httpClientAdapter = FakeAdapter();
0064:   });
0065: 
0066:   testWidgets('Steps screen shows permission request message when denied',
0067:       (tester) async {
0068:     await tester.pumpWidget(
0069:       MaterialApp(
0070:         initialRoute: Routes.steps,
0071:         routes: {Routes.steps: (_) => const StepsScreen()},
0072:       ),
0073:     );
0074: 
0075:     // Allow init to run.
0076:     await tester.pumpAndSettle();
0077: 
0078:     expect(
0079:       find.textContaining('Activity recognition permission is required'),
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `token_storage_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\token_storage_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** اختبار طبقة التخزين الآمن للتوكنات فوق channel الخاص بـ `flutter_secure_storage`.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن save/read/clear تستدعي القناة التحتية بشكل صحيح.
- **الأهمية داخل المنظومة:** `supportive`
- **أبرز السيناريوهات: `SecureStorage save/read/clear calls underlying channel`**

```dart
0005: 
0006: void main() {
0007:   TestWidgetsFlutterBinding.ensureInitialized();
0008: 
0009:   test('SecureStorage save/read/clear calls underlying channel', () async {
0010:     final calls = <String, Map<String, dynamic>>{};
0011:     final store = <String, String>{};
0012: 
0013:     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
0014:         .setMockMethodCallHandler(
0015:       const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
0016:       (call) async {
0017:         calls[call.method] = Map<String, dynamic>.from(call.arguments ?? {});
0018:         switch (call.method) {
0019:           case 'write':
0020:             store[call.arguments['key'] as String] =
0021:                 call.arguments['value'] as String;
0022:             return null;
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `widget_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\widget_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** smoke widget test بسيط للتأكد من أن التطبيق يبدأ من شاشة الدخول.
- **ما الذي يختبره أو يفعّله:** يتحقق من startup UI الأساسي بأقل تكلفة ممكنة.
- **الأهمية داخل المنظومة:** `supportive`
- **أبرز السيناريوهات: `App starts on login screen`**

```dart
0015:   setUpAll(() {
0016:     HttpClient.initForTesting();
0017:   });
0018: 
0019:   testWidgets('App starts on login screen', (WidgetTester tester) async {
0020:     await tester.pumpWidget(const VitaMateApp());
0021: 
0022:     expect(find.byType(LoginScreen), findsOneWidget);
0023:     expect(find.text('Sign In'), findsOneWidget);
0024:     expect(find.text('Username'), findsOneWidget);
0025:   });
0026: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `chronic_conditions_controller_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\chronic_conditions\chronic_conditions_controller_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي controller الخاص بالحالات المزمنة: تحميل catalog والحالات والجرعات وخطط التذكير، ثم عرض أخطاء backend validation للمستخدم.
- **ما الذي يختبره أو يفعّله:** يتحقق من layer الوسيطة بين API وواجهة chronic conditions دون تشغيل network حقيقية.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeChronicConditionsApi`**
- **أبرز السيناريوهات: `controller loads conditions, catalogs, doses, and reminder plans`, `controller exposes backend validation errors on condition creation`**
- **سبب اختيار المقتطف:** المقتطف يوضح أن controller لا يكتفي بالتحميل، بل ينقل أخطاء validation الخلفية أيضاً إلى حالة واجهة قابلة للعرض.

```dart
0042: void main() {
0043:   test(
0044:     'controller loads conditions, catalogs, doses, and reminder plans',
0045:     () async {
0046:       final capturedPlans = <ChronicMedicationReminderPlan>[];
0047:       final api = _FakeChronicConditionsApi(
0048:         conditions: [_sampleCondition()],
0049:         catalog: [_sampleConditionType()],
0050:       );
0051:       final controller = ChronicConditionsController(
0052:         api: api,
0053:         reminderSync: (plans) async {
0054:           capturedPlans
0055:             ..clear()
0056:             ..addAll(plans);
0057:         },
0058:       );
0059: 
0060:       await controller.load();
0061: 
0062:       expect(controller.catalog, hasLength(1));
0063:       expect(controller.conditions, hasLength(1));
0064:       expect(controller.conditionForType(1)?.id, 4);
0065:       expect(controller.todayDoses, hasLength(1));
0066:       expect(controller.pendingSchedules, 1);
0067:       expect(capturedPlans, hasLength(1));
0068:       expect(capturedPlans.single.medicationName, 'Metformin');
0069:       expect(capturedPlans.single.conditionName, 'Diabetes');
0070:     },
0071:   );
0072: 
0073:   test(
0074:     'controller exposes backend validation errors on condition creation',
0075:     () async {
0076:       final request = RequestOptions(path: '/api/chronic/user-conditions/');
0077:       final controller = ChronicConditionsController(
0078:         api: _FakeChronicConditionsApi(
0079:           conditions: const [],
0080:           catalog: [_sampleConditionType()],
0081:           createError: DioException(
0082:             requestOptions: request,
0083:             response: Response(
0084:               requestOptions: request,
0085:               statusCode: 400,
0086:               data: {
0087:                 'severity': ['severity is required.'],
0088:               },
0089:             ),
0090:             type: DioExceptionType.badResponse,
0091:           ),
0092:         ),
0093:         reminderSync: (_) async {},
0094:       );
0095: 
0096:       final success = await controller.createCondition(
0097:         conditionTypeId: 1,
0098:         severityCode: '',
0099:         status: 'active',
0100:       );
0101: 
0102:       expect(success, isFalse);
0103:       expect(controller.error, 'severity is required.');
0104:     },
0105:   );
0106: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `chronic_conditions_screen_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\chronic_conditions\chronic_conditions_screen_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** اختبار واجهة لصفحة `Conditions Center` يثبت وجود البطاقات الصحيحة، واختفاء إدخال global add غير المرغوب، وظهور التفاصيل عند فتح حالة نشطة.
- **ما الذي يختبره أو يفعّله:** يتحقق من UI contract الداخلي للشاشة ومن المحتوى المتوقع في مسار chronic care.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeChronicConditionsApi`**
- **أبرز السيناريوهات: `screen shows supported cards and no global add entry point`, `opening an active card shows summary, readings, and medications`**
- **سبب اختيار المقتطف:** المقتطف المختار يمثل السلوك المرئي الأهم: عرض البطاقات الصحيحة وفتح صفحة التتبع والعناصر التابعة لها.

```dart
0021: void main() {
0022:   testWidgets('screen shows supported cards and no global add entry point', (
0023:     WidgetTester tester,
0024:   ) async {
0025:     final controller = ChronicConditionsController(
0026:       api: _FakeChronicConditionsApi(
0027:         conditions: const [],
0028:         catalog: _sampleCatalog(),
0029:       ),
0030:       reminderSync: (_) async {},
0031:     );
0032: 
0033:     await tester.pumpWidget(
0034:       MaterialApp(home: ChronicConditionsScreen(controller: controller)),
0035:     );
0036:     await tester.pumpAndSettle();
0037: 
0038:     expect(find.text('Conditions Center'), findsOneWidget);
0039:     expect(
0040:       find.textContaining('No chronic conditions added yet'),
0041:       findsOneWidget,
0042:     );
0043:     await tester.scrollUntilVisible(find.text('Diabetes'), 300);
0044:     expect(find.text('Diabetes'), findsOneWidget);
0045:     await tester.scrollUntilVisible(find.text('Hypertension'), 300);
0046:     expect(find.text('Hypertension'), findsOneWidget);
0047:     await tester.scrollUntilVisible(find.text('Cholesterol'), 300);
0048:     expect(find.text('Cholesterol'), findsOneWidget);
0049:     expect(find.text('Add medication'), findsNothing);
0050:     expect(find.byType(FloatingActionButton), findsNothing);
0051:   });
0052: 
0053:   testWidgets(
0054:     'opening an active card shows summary, readings, and medications',
0055:     (WidgetTester tester) async {
0056:       final controller = ChronicConditionsController(
0057:         api: _FakeChronicConditionsApi(
0058:           conditions: [_sampleCondition()],
0059:           catalog: _sampleCatalog(),
0060:         ),
0061:         reminderSync: (_) async {},
0062:       );
0063: 
0064:       await tester.pumpWidget(
0065:         MaterialApp(home: ChronicConditionsScreen(controller: controller)),
0066:       );
0067:       await tester.pumpAndSettle();
0068: 
0069:       final openButton = tester.widget<FilledButton>(
0070:         find.widgetWithText(FilledButton, 'View tracking').first,
0071:       );
0072:       openButton.onPressed!.call();
0073:       await tester.pumpAndSettle();
0074: 
0075:       expect(find.text('Tracking summary'), findsOneWidget);
0076:       expect(find.text('Add reading'), findsOneWidget);
0077:       expect(find.text('Add medication'), findsAtLeastNWidgets(1));
0078: 
0079:       await tester.scrollUntilVisible(find.text('Applied care limits'), 300);
0080:       expect(find.text('Applied care limits'), findsOneWidget);
0081:       await tester.scrollUntilVisible(find.text('Recent alerts'), 300);
0082:       expect(find.text('Recent alerts'), findsOneWidget);
0083:     },
0084:   );
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `dashboard_data_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\home\dashboard_data_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** اختبار parser صغير للتأكد من أن chronic summary في dashboard يتحلل safely حتى عندما تتغير بعض القيم.
- **ما الذي يختبره أو يفعّله:** يتحقق من robustness في طبقة models أمام payloads جزئية أو متغيرة قليلاً.
- **الأهمية داخل المنظومة:** `supportive`
- **أبرز السيناريوهات: `dashboard data parses chronic summary safely`**

```dart
0001: import 'package:flutter_test/flutter_test.dart';
0002: import 'package:vitamate/features/home/models/dashboard_data.dart';
0003: 
0004: void main() {
0005:   test('dashboard data parses chronic summary safely', () {
0006:     final data = DashboardData.fromDashboard({
0007:       'gamification': {'points': 18},
0008:       'activity': {'steps': 4200},
0009:       'hydration': {'current': 1.6},
0010:       'summary': {'calories_consumed': 1400},
0011:       'chronic_conditions': {
0012:         'count': 2,
0013:         'labels': ['Diabetes / Prediabetes', 'Hypertension / High Blood Pressure'],
0014:         'adherence_percent': 75,
0015:         'active_medications_today': 3,
0016:         'pending_doses_today': 1,
0017:         'applied_summaries': ['Daily sodium limit set to 1500 mg.'],
0018:         'disclaimer': 'Supportive self-management only.',
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `medications_controller_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\medications\medications_controller_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي parsing models الدوائية، وإنشاء دواء جديد، ومزامنة reminder plans، وتحديث خطة اليوم بعد dose actions.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن controller ينعكس عليه التغيير backend-first بدلاً من بناء حالة دوائية مستقلة داخل UI.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeMedicationsRepository`**
- **أبرز السيناريوهات: `medication models parse backend payload`, `controller creates medication and syncs reminders`, `controller refreshes today plan after dose action`**
- **سبب اختيار المقتطف:** المقتطف يبين ثلاثة مستويات معاً: parsing، create flow، ثم refresh لخطة اليوم بعد dose action.

```dart
0011: class _FakeMedicationsRepository extends MedicationsRepository {
0012:   _FakeMedicationsRepository();
0013: 
0014:   final createdPayloads = <Map<String, dynamic>>[];
0015:   var medications = <MedicationItem>[];
0016:   var today = <MedicationDoseLog>[];
0017:   var adherence = MedicationAdherenceSummary.empty();
0018: 
0019:   @override
0020:   Future<List<MedicationItem>> getMedications() async => medications;
0021: 
0022:   @override
0023:   Future<List<MedicationDoseLog>> getTodayPlan() async => today;
0024: 
0025:   @override
0026:   Future<MedicationAdherenceSummary> getOverallAdherence() async => adherence;
0027: 
0028:   @override
0029:   Future<MedicationItem> createMedication(Map<String, dynamic> payload) async {
0030:     createdPayloads.add(payload);
0031:     final item = MedicationItem(
0032:       id: 10,
0033:       displayName: payload['display_name'] as String,
0034:       sourceType: payload['source_type'] as String,
0035:       linkedConditionId: payload['user_condition_id'] as int?,
0036:       linkedConditionName: null,
0037:       doseAmount: payload['dose_amount']?.toString() ?? '',
0038:       doseUnit: payload['dose_unit']?.toString() ?? '',
0039:       dosage: '',
0040:       form: payload['form']?.toString() ?? '',
0041:       instructions: payload['instructions']?.toString() ?? '',
0042:       startDate: DateTime(2026, 4, 17),
0043:       endDate: null,
0044:       isActive: true,
0045:       isPrn: false,
0046:       timezone: 'Asia/Damascus',
0047:       nextDue: DateTime(2026, 4, 17, 8),
0048:       adherenceSummaryShort: adherence,
0049:       schedules: const [
0050:         MedicationSchedule(
0051:           id: 5,
0052:           scheduleType: 'daily',
0053:           time: '08:00',
0054:           daysOfWeek: [],
0055:           intervalHours: null,
0056:           mealRelation: 'after_meal',
0057:           gracePeriodMinutes: 60,
0058:           snoozeDefaultMinutes: 15,
0059:           isActive: true,
0060:         ),
0061:       ],
0062:     );
0063:     medications = [item];
0064:     return item;
0065:   }
0066: 
0067:   @override
0068:   Future<MedicationDoseLog> markTaken(
0069:     int logId, {
0070:     DateTime? takenAt,
0071:     String? doseTakenAmount,
0072:   }) async {
0073:     final updated = MedicationDoseLog(
0074:       logId: logId,
0075:       medicationId: 10,
0076:       displayName: 'Metformin',
0077:       linkedConditionId: 2,
0078:       linkedConditionName: 'Diabetes',
0079:       scheduledFor: DateTime(2026, 4, 17, 8),
0080:       status: 'taken',
0081:       snoozedUntil: null,
0082:       doseAmount: '500',
0083:       doseUnit: 'mg',
0084:       form: 'tablet',
0085:     );
0086:     today = [updated];
0087:     return updated;
0088:   }
0089: 
0090:   @override
0091:   Future<ReminderSyncPayload> getReminderSync() async {
0092:     return ReminderSyncPayload.fromJson({
0093:       'items': [
0094:         {
0095:           'medication_id': 10,
0096:           'schedule_id': 5,
0097:           'display_name': 'Metformin',
0098:           'timezone': 'Asia/Damascus',
0099:           'scheduled_times': ['08:00'],
0100:           'days_of_week': [0, 2],
0101:           'meal_relation': 'after_meal',
0102:           'snooze_default_minutes': 15,
0103:           'reminder_lead_minutes': 10,
0104:           'linked_condition': {'id': 2, 'name': 'Diabetes'},
0105:         },
0106:       ],
0107:     });
0108:   }
0109: }
0110: 
0111: void main() {
0112:   test('medication models parse backend payload', () {
0113:     final item = MedicationItem.fromJson({
0114:       'id': 1,
0115:       'display_name': 'Metformin',
0116:       'source_type': 'condition',
0117:       'linked_condition_id': 4,
0118:       'linked_condition_name': 'Diabetes',
0119:       'dose_amount': '500',
0120:       'dose_unit': 'mg',
0121:       'form': 'tablet',
0122:       'instructions': 'After food',
0123:       'start_date': '2026-04-17',
0124:       'next_due': '2026-04-17T08:00:00Z',
0125:       'adherence_summary_short': {
0126:         'expected_doses': 2,
0127:         'taken_doses': 1,
0128:         'missed_doses': 0,
0129:         'skipped_doses': 0,
0130:         'pending_doses': 1,
0131:         'overdue_doses': 0,
0132:         'adherence_percent': 50,
0133:         'streak_days': 1,
0134:         'on_time_percent': 50,
0135:       },
0136:       'schedules': [
0137:         {
0138:           'id': 7,
0139:           'schedule_type': 'daily',
0140:           'time': '08:00',
0141:           'meal_relation': 'after_meal',
0142:         },
0143:       ],
0144:     });
0145: 
0146:     expect(item.displayName, 'Metformin');
0147:     expect(item.linkedConditionName, 'Diabetes');
0148:     expect(item.schedules.single.time, '08:00');
0149:     expect(item.adherenceSummaryShort.expectedDoses, 2);
0150:   });
0151: 
0152:   test('controller creates medication and syncs reminders', () async {
0153:     final repo = _FakeMedicationsRepository();
0154:     final plans = <ChronicMedicationReminderPlan>[];
0155:     final controller = MedicationsController(
0156:       repository: repo,
0157:       reminderSyncer: (value) async => plans.addAll(value),
0158:     );
0159: 
0160:     final saved = await controller.createMedication({
0161:       'display_name': 'Metformin',
0162:       'source_type': 'condition',
0163:       'user_condition_id': 2,
0164:       'dose_amount': '500',
0165:       'dose_unit': 'mg',
0166:       'form': 'tablet',
0167:       'instructions': 'After food',
0168:       'schedules': [
0169:         {'schedule_type': 'daily', 'time': '08:00'},
0170:       ],
0171:     });
0172: 
0173:     expect(saved, isTrue);
0174:     expect(repo.createdPayloads, hasLength(1));
0175:     expect(controller.state.medications.single.displayName, 'Metformin');
0176:     expect(plans.single.medicationName, 'Metformin');
0177:     expect(plans.single.recurrenceDays, [0, 2]);
0178:   });
0179: 
0180:   test('controller refreshes today plan after dose action', () async {
0181:     final repo = _FakeMedicationsRepository()
0182:       ..today = [
0183:         MedicationDoseLog(
0184:           logId: 3,
0185:           medicationId: 10,
0186:           displayName: 'Metformin',
0187:           linkedConditionId: 2,
0188:           linkedConditionName: 'Diabetes',
0189:           scheduledFor: DateTime(2026, 4, 17, 8),
0190:           status: 'pending',
0191:           snoozedUntil: null,
0192:           doseAmount: '500',
0193:           doseUnit: 'mg',
0194:           form: 'tablet',
0195:         ),
0196:       ];
0197:     final controller = MedicationsController(
0198:       repository: repo,
0199:       reminderSyncer: (_) async {},
0200:     );
0201: 
0202:     final ok = await controller.markDoseTaken(3);
0203: 
0204:     expect(ok, isTrue);
0205:     expect(controller.state.todayPlan.single.status, 'taken');
0206:   });
0207: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `nutrition_controller_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\nutrition\nutrition_controller_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي NutritionController مع drinks، points، السكر لمرضى السكري، والتنبيهات عند تجاوز حد السكر.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن controller يحافظ على rows الخاصة بالمشروبات ويحسب breakdowns من snapshots ويربطها بديابيتس guard.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeNutritionApi`, `_FakeDiabetesSugarGuardService`**
- **أبرز السيناريوهات: `nutrition controller keeps drink rows and computes points from snapshots`, `nutrition controller sends warning when sugar crosses diabetes limit`**
- **سبب اختيار المقتطف:** المقتطف المختار يوضح الحالة الغنية التي تجمع food logging وsnapshots وdiabetes guard معاً.

```dart
0108: void main() {
0109:   test(
0110:     'nutrition controller keeps drink rows and computes points from snapshots',
0111:     () async {
0112:       final oats = FoodItem(
0113:         id: 1,
0114:         name: 'Oats',
0115:         calories100g: 380,
0116:         protein100g: 12,
0117:         carbs100g: 64,
0118:         fat100g: 7,
0119:         servingLabel: 'Bowl',
0120:         servingGrams: 80,
0121:       );
0122:       final latte = FoodItem(
0123:         id: 2,
0124:         name: 'Iced Latte',
0125:         itemType: 'beverage',
0126:         category: 'Coffee',
0127:         calories100g: 50,
0128:         protein100g: 2,
0129:         carbs100g: 6,
0130:         fat100g: 1,
0131:         sugars100g: 5,
0132:         caffeineMg: 32,
0133:         servingLabel: 'Cup',
0134:         servingGrams: 250,
0135:       );
0136:       final api = _FakeNutritionApi(
0137:         summary: const NutritionSummary(
0138:           targetCalories: 700,
0139:           consumedCalories: 0,
0140:           burnedCalories: 0,
0141:           remainingCalories: 700,
0142:           points: 0,
0143:         ),
0144:         foods: [oats, latte],
0145:         meals: [
0146:           MealLog(
0147:             id: 1,
0148:             foodId: oats.id,
0149:             foodName: oats.name,
0150:             mealType: 'breakfast',
0151:             quantityGrams: 80,
0152:             quantity: 80,
0153:             unit: 'g',
0154:             caloriesKcal: 304,
0155:             proteinG: 9.6,
0156:             carbsG: 51.2,
0157:             fatG: 5.6,
0158:             sugarsG: 1.2,
0159:           ),
0160:           MealLog(
0161:             id: 2,
0162:             foodId: latte.id,
0163:             foodName: latte.name,
0164:             mealType: 'drink',
0165:             quantityGrams: 200,
0166:             quantity: 200,
0167:             unit: 'ml',
0168:             millilitersConsumed: 200,
0169:             caloriesKcal: 100,
0170:             proteinG: 4,
0171:             carbsG: 12,
0172:             fatG: 2,
0173:             sugarsG: 10,
0174:             caffeineMg: 64,
0175:           ),
0176:         ],
0177:         diabetesActive: true,
0178:       );
0179:       final controller = NutritionController(
0180:         api: api,
0181:         diabetesSugarGuardService: const _FakeDiabetesSugarGuardService(
0182:           DiabetesSugarGuard(limitG: 25, source: 'default_diabetes_limit'),
0183:         ),
0184:         diabetesSugarAlertNotifier: (_) async {},
0185:       );
0186: 
0187:       await controller.load();
0188: 
0189:       expect(controller.meals, hasLength(2));
0190:       expect(controller.meals.last.isDrink, isTrue);
0191:       expect(controller.diabetesActive, isTrue);
0192:       expect(controller.detailBreakdown.sugarsG, closeTo(11.2, 0.001));
0193:       expect(controller.mealPointsToday, 10);
0194: 
0195:       await controller.logMeal(
0196:         foodId: latte.id,
0197:         mealType: 'drink',
0198:         quantity: 300,
0199:         unit: 'ml',
0200:       );
0201: 
0202:       expect(controller.meals, hasLength(3));
0203:       expect(controller.meals.last.foodName, 'Iced Latte');
0204:       expect(controller.meals.last.millilitersConsumed, 300);
0205:       expect(controller.detailBreakdown.sugarsG, closeTo(26.2, 0.001));
0206:       expect(controller.mealPointsToday, 15);
0207:     },
0208:   );
0209: 
0210:   test(
0211:     'nutrition controller sends warning when sugar crosses diabetes limit',
0212:     () async {
0213:       final juice = FoodItem(
0214:         id: 8,
0215:         name: 'Mango Juice',
0216:         itemType: 'beverage',
0217:         category: 'Juice',
0218:         calories100g: 60,
0219:         protein100g: 0,
0220:         carbs100g: 14,
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `water_controller_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\water\water_controller_test.dart`
- **الفئة:** `Frontend Test File`
- **الغرض الأساسي:** يغطي WaterController: البحث في catalog، حفظ مشروب، إعادة التحميل بعد الحفظ، التعامل مع reload failure، والتنبيه عند تجاوز حد السكر لمريض سكري.
- **ما الذي يختبره أو يفعّله:** يتحقق من أن طبقة الترطيب لا تنفصل عن nutrition والdiabetes guard.
- **الأهمية داخل المنظومة:** `critical`
- **الكلاسات: `_FakeWaterApi`, `_NullDiabetesSugarGuardService`, `_FixedDiabetesSugarGuardService`, `_FakeWaterNutritionApi`**
- **أبرز السيناريوهات: `water controller searches catalog and reloads after beverage save`, `water controller surfaces reload failure after save`, `water controller warns when a sugary drink crosses diabetes limit`**
- **سبب اختيار المقتطف:** المقتطف يبين تداخل hydration مع beverage catalog وnutrition preview ثم يختبر فشل إعادة التحميل بعد الكتابة.

```dart
0117: void main() {
0118:   test(
0119:     'water controller searches catalog and reloads after beverage save',
0120:     () async {
0121:       final coffee = FoodItem(
0122:         id: 1,
0123:         name: 'Cold Brew',
0124:         itemType: 'beverage',
0125:         category: 'Coffee',
0126:         calories100g: 4,
0127:         protein100g: 0,
0128:         carbs100g: 0,
0129:         fat100g: 0,
0130:         caffeineMg: 28,
0131:         servingLabel: 'Cup',
0132:         servingGrams: 250,
0133:       );
0134:       final api = _FakeWaterApi(
0135:         logs: [
0136:           WaterLog(
0137:             id: 1,
0138:             amountLiter: 0.25,
0139:             hydrationMl: 250,
0140:             beverageType: 'water',
0141:             beverageName: 'Water',
0142:             date: DateTime(2026, 4, 16),
0143:           ),
0144:         ],
0145:         catalog: [coffee],
0146:       );
0147:       final controller = WaterController(
0148:         api: api,
0149:         diabetesSugarGuardService: const _NullDiabetesSugarGuardService(),
0150:       );
0151: 
0152:       await controller.load(targetMlFromBackend: 2400);
0153:       await controller.searchBeverages('coffee');
0154: 
0155:       expect(controller.consumedMl, 250);
0156:       expect(controller.waterPointsToday, 5);
0157:       expect(controller.beverageCatalog, hasLength(1));
0158: 
0159:       final saved = await controller.addCatalogBeverage(
0160:         foodItemId: coffee.id,
0161:         amountMl: 200,
0162:       );
0163: 
0164:       expect(saved, isTrue);
0165:       expect(controller.logs, hasLength(2));
0166:       expect(controller.consumedMl, 450);
0167:       expect(controller.logs.first.foodItemName, 'Cold Brew');
0168:       expect(controller.logs.first.nutritionPreview?.caffeine, 56);
0169:     },
0170:   );
0171: 
0172:   test('water controller surfaces reload failure after save', () async {
0173:     final tea = FoodItem(
0174:       id: 2,
0175:       name: 'Green Tea',
0176:       itemType: 'beverage',
0177:       category: 'Tea',
0178:       calories100g: 1,
0179:       protein100g: 0,
0180:       carbs100g: 0,
0181:       fat100g: 0,
0182:       caffeineMg: 12,
0183:       servingLabel: 'Cup',
0184:       servingGrams: 250,
0185:     );
0186:     final api = _FakeWaterApi(
0187:       logs: [
0188:         WaterLog(
0189:           id: 1,
0190:           amountLiter: 0.25,
0191:           hydrationMl: 250,
0192:           beverageType: 'water',
0193:           beverageName: 'Water',
0194:           date: DateTime(2026, 4, 16),
0195:         ),
0196:       ],
0197:       catalog: [tea],
0198:       failReadsAfterWrite: true,
0199:     );
0200:     final controller = WaterController(
0201:       api: api,
0202:       diabetesSugarGuardService: const _NullDiabetesSugarGuardService(),
0203:     );
0204: 
0205:     await controller.load(targetMlFromBackend: 2400);
0206:     final saved = await controller.addCatalogBeverage(
0207:       foodItemId: tea.id,
0208:       amountMl: 200,
0209:     );
0210: 
0211:     expect(saved, isFalse);
0212:     expect(controller.error, 'Could not save beverage log.');
0213:     expect(controller.consumedMl, 250);
0214:   });
0215: 
0216:   test(
0217:     'water controller warns when a sugary drink crosses diabetes limit',
0218:     () async {
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### Integration Test File

#### `test_helpers.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\test_helpers.dart`
- **الفئة:** `Integration Test File`
- **الغرض الأساسي:** مجموعة Helpers موحدة لإقلاع التطبيق، الانتظار حتى ظهور عناصر UI، إدخال النصوص، وتنفيذ login باستخدام مفاتيح ثابتة.
- **ما الذي يختبره أو يفعّله:** تقلل flakiness وتوحد سلوك الاختبارات التكاملية بدلاً من تكرار pump/wait logic داخل كل test.
- **الأهمية داخل المنظومة:** `critical`
- **سبب اختيار المقتطف:** المقتطف يوضح كيف يتم تشغيل التطبيق الحقيقي مع تعطيل notifications، وكيف بُنيت primitives ثابتة للانتظار والضغط والإدخال.

```dart
0001: import 'package:flutter/material.dart';
0002: import 'package:flutter_test/flutter_test.dart';
0003: import 'package:integration_test/integration_test.dart';
0004: import 'package:vitamate/bootstrap.dart';
0005: import 'package:vitamate/core/testing/app_test_keys.dart';
0006: 
0007: Future<void> launchIntegrationApp(WidgetTester tester) async {
0008:   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
0009:   await runVitaMateApp(enableNotifications: false);
0010:   await tester.pump();
0011: }
0012: 
0013: Future<void> waitForFinder(
0014:   WidgetTester tester,
0015:   Finder finder, {
0016:   Duration timeout = const Duration(seconds: 20),
0017: }) async {
0018:   final deadline = DateTime.now().add(timeout);
0019:   while (DateTime.now().isBefore(deadline)) {
0020:     await tester.pump(const Duration(milliseconds: 250));
0021:     if (finder.evaluate().isNotEmpty) {
0022:       return;
0023:     }
0024:   }
0025:   throw TestFailure('Timed out waiting for finder: $finder');
0026: }
0027: 
0028: Future<void> waitForText(
0029:   WidgetTester tester,
0030:   String text, {
0031:   Duration timeout = const Duration(seconds: 20),
0032: }) async {
0033:   await waitForFinder(tester, find.text(text), timeout: timeout);
0034: }
0035: 
0036: Future<void> tapByKey(
0037:   WidgetTester tester,
0038:   String key, {
0039:   Duration timeout = const Duration(seconds: 20),
0040: }) async {
0041:   final finder = find.byKey(ValueKey(key));
0042:   await waitForFinder(tester, finder, timeout: timeout);
0043:   await tester.ensureVisible(finder);
0044:   await tester.tap(finder);
0045:   await tester.pump();
0046: }
0047: 
0048: Future<void> enterTextByKey(
0049:   WidgetTester tester,
0050:   String key,
0051:   String value, {
0052:   Duration timeout = const Duration(seconds: 20),
0053: }) async {
0054:   final finder = find.byKey(ValueKey(key));
0055:   await waitForFinder(tester, finder, timeout: timeout);
0056:   await tester.ensureVisible(finder);
0057:   await tester.tap(finder);
0058:   await tester.pump();
0059:   await tester.enterText(finder, value);
0060:   await tester.pump();
0061: }
0062: 
0063: Future<void> loginAsChronicUser(WidgetTester tester) async {
0064:   await waitForFinder(
0065:     tester,
0066:     find.byKey(const ValueKey(AppTestKeys.loginUsernameField)),
0067:   );
0068:   await enterTextByKey(
0069:     tester,
0070:     AppTestKeys.loginUsernameField,
0071:     'e2e_chronic',
0072:   );
0073:   await enterTextByKey(
0074:     tester,
0075:     AppTestKeys.loginPasswordField,
0076:     'Pass123!',
0077:   );
0078:   await tapByKey(tester, AppTestKeys.loginSubmitButton);
0079: }
0080: 
0081: Future<void> waitForHomeScreen(
0082:   WidgetTester tester, {
0083:   Duration timeout = const Duration(seconds: 30),
0084: }) async {
0085:   await waitForText(tester, 'Daily Health Score', timeout: timeout);
0086:   await tester.pump(const Duration(milliseconds: 500));
0087: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `smoke_login_home_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\smoke_login_home_test.dart`
- **الفئة:** `Integration Test File`
- **الغرض الأساسي:** smoke test قصير لقياس أقل مسار حرج: فتح التطبيق، login، ثم التأكد من ظهور عناصر رئيسية في Home.
- **ما الذي يختبره أو يفعّله:** يتحقق من الوصول إلى Home ومن ظهور `Daily Health Score` وزر مركز الحالات.
- **الأهمية داخل المنظومة:** `critical`
- **أبرز السيناريوهات: `smoke login reaches home and loads key sections`**
- **سبب اختيار المقتطف:** المقتطف يوضح كيف عُزل smoke test ليكون تشخيصياً وسريعاً قبل تشغيل السيناريو المزمن الكامل.

```dart
0001: import 'package:flutter/material.dart';
0002: import 'package:flutter_test/flutter_test.dart';
0003: import 'package:integration_test/integration_test.dart';
0004: import 'package:vitamate/core/testing/app_test_keys.dart';
0005: 
0006: import 'test_helpers.dart';
0007: 
0008: void main() {
0009:   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
0010: 
0011:   testWidgets('smoke login reaches home and loads key sections', (
0012:     WidgetTester tester,
0013:   ) async {
0014:     await launchIntegrationApp(tester);
0015:     await loginAsChronicUser(tester);
0016: 
0017:     await waitForText(tester, 'Daily Health Score');
0018:     await tester.scrollUntilVisible(
0019:       find.byKey(const ValueKey(AppTestKeys.homeConditionsCenterAddButton)),
0020:       250,
0021:       scrollable: find.byType(Scrollable).first,
0022:     );
0023:     expect(
0024:       find.byKey(const ValueKey(AppTestKeys.homeConditionsCenterAddButton)),
0025:       findsOneWidget,
0026:     );
0027:   });
0028: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `chronic_flow_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\chronic_flow_test.dart`
- **الفئة:** `Integration Test File`
- **الغرض الأساسي:** السيناريو التكاملـي الرئيسي للمشروع حالياً: login ثم إضافة `Hypertension` ثم إضافة reading ثم التحقق من summary والعودة إلى Home.
- **ما الذي يختبره أو يفعّله:** يتحقق end-to-end من chronic flow الحقيقي على Android emulator وباستخدام backend Django فعلي.
- **الأهمية داخل المنظومة:** `critical`
- **أبرز السيناريوهات: `hypertension chronic flow updates condition detail and home`**
- **سبب اختيار المقتطف:** هذا أهم مقتطف في طبقة E2E الحالية لأنه يمثل رحلة المستخدم الكاملة ذات القيمة الأكاديمية الأعلى في المشروع.

```dart
0001: import 'package:flutter/material.dart';
0002: import 'package:flutter_test/flutter_test.dart';
0003: import 'package:integration_test/integration_test.dart';
0004: import 'package:vitamate/core/testing/app_test_keys.dart';
0005: 
0006: import 'test_helpers.dart';
0007: 
0008: void main() {
0009:   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
0010: 
0011:   testWidgets('hypertension chronic flow updates condition detail and home', (
0012:     WidgetTester tester,
0013:   ) async {
0014:     await launchIntegrationApp(tester);
0015:     await loginAsChronicUser(tester);
0016:     await waitForHomeScreen(tester);
0017: 
0018:     final homeAddButtonFinder = find.byKey(
0019:       const ValueKey(AppTestKeys.homeConditionsCenterAddButton),
0020:     );
0021:     await tester.scrollUntilVisible(
0022:       homeAddButtonFinder,
0023:       250,
0024:       scrollable: find.byType(Scrollable).first,
0025:     );
0026:     await tester.tap(homeAddButtonFinder);
0027:     await tester.pump();
0028:     await waitForFinder(
0029:       tester,
0030:       find.byKey(const ValueKey(AppTestKeys.chronicScreenHeader)),
0031:     );
0032: 
0033:     final addHypertensionFinder = find
0034:         .byKey(ValueKey(AppTestKeys.chronicSupportedAddButton('hypertension')))
0035:         .first;
0036:     await waitForFinder(tester, addHypertensionFinder);
0037:     await tester.ensureVisible(addHypertensionFinder);
0038:     await tester.tap(addHypertensionFinder);
0039:     await tester.pump();
0040: 
0041:     await enterTextByKey(
0042:       tester,
0043:       AppTestKeys.chronicCreateField(
0044:         slug: 'hypertension',
0045:         field: 'systolicField',
0046:       ),
0047:       '138',
0048:     );
0049:     await enterTextByKey(
0050:       tester,
0051:       AppTestKeys.chronicCreateField(
0052:         slug: 'hypertension',
0053:         field: 'diastolicField',
0054:       ),
0055:       '88',
0056:     );
0057:     await enterTextByKey(
0058:       tester,
0059:       AppTestKeys.chronicCreateField(
0060:         slug: 'hypertension',
0061:         field: 'pulseField',
0062:       ),
0063:       '72',
0064:     );
0065:     await tapByKey(tester, AppTestKeys.chronicCreateSaveButton);
0066: 
0067:     await waitForFinder(
0068:       tester,
0069:       find.byKey(const ValueKey(AppTestKeys.chronicDetailAddReadingButton)),
0070:       timeout: const Duration(seconds: 30),
0071:     );
0072: 
0073:     await tapByKey(tester, AppTestKeys.chronicDetailAddReadingButton);
0074:     await enterTextByKey(
0075:       tester,
0076:       AppTestKeys.chronicReadingField(
0077:         slug: 'hypertension',
0078:         field: 'systolicField',
0079:       ),
0080:       '145',
0081:     );
0082:     await enterTextByKey(
0083:       tester,
0084:       AppTestKeys.chronicReadingField(
0085:         slug: 'hypertension',
0086:         field: 'diastolicField',
0087:       ),
0088:       '92',
0089:     );
0090:     await enterTextByKey(
0091:       tester,
0092:       AppTestKeys.chronicReadingField(
0093:         slug: 'hypertension',
0094:         field: 'pulseField',
0095:       ),
0096:       '84',
0097:     );
0098:     await tapByKey(tester, AppTestKeys.chronicReadingSaveButton);
0099: 
0100:     await waitForFinder(
0101:       tester,
0102:       find.byKey(const ValueKey(AppTestKeys.chronicDetailSummaryCard)),
0103:       timeout: const Duration(seconds: 30),
0104:     );
0105:     await waitForFinder(
0106:       tester,
0107:       find.byKey(const ValueKey(AppTestKeys.chronicDetailReadingsList)),
0108:       timeout: const Duration(seconds: 30),
0109:     );
0110:     await waitForText(tester, 'Attention needed');
0111:     await waitForFinder(tester, find.textContaining('145/92'));
0112: 
0113:     await tapByKey(tester, AppTestKeys.chronicDetailBackButton);
0114:     await waitForFinder(
0115:       tester,
0116:       find.byKey(const ValueKey(AppTestKeys.chronicScreenHeader)),
0117:     );
0118:     await tester.pageBack();
0119:     await tester.pump();
0120:     await waitForHomeScreen(tester);
0121: 
0122:     final homeConditionCardFinder = find.byKey(
0123:       ValueKey(AppTestKeys.homeConditionCard('hypertension')),
0124:     );
0125:     await tester.scrollUntilVisible(
0126:       homeConditionCardFinder,
0127:       250,
0128:       scrollable: find.byType(Scrollable).first,
0129:     );
0130:     expect(homeConditionCardFinder, findsOneWidget);
0131:     expect(find.text('No chronic conditions added yet'), findsNothing);
0132:   });
0133: }
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

#### `integration_test.dart`
- **المسار الكامل:** `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test_driver\integration_test.dart`
- **الفئة:** `Integration Test File`
- **الغرض الأساسي:** driver entrypoint المطلوب من `flutter drive` لربط runner مع integration tests.
- **ما الذي يختبره أو يفعّله:** يفعّل تشغيل الاختبارات التكاملية بصيغة `flutter drive` داخل CI ومحلياً.
- **الأهمية داخل المنظومة:** `supportive`
- **سبب اختيار المقتطف:** الملف قصير جداً لكنه ضروري لتشغيل Flutter integration tests فعلياً.

```dart
0001: import 'package:integration_test/integration_test_driver_extended.dart';
0002: 
0003: Future<void> main() => integrationDriver();
```

شرح المقتطف: يوضح هذا الجزء شكل التنفيذ أو التحقق الأكثر دلالة في الملف، سواء كان تعريفاً لسيناريو اختبار، أو تهيئة لأداة، أو جزءاً من وثيقة تشغيل يعتمد عليها العمل اليومي.

### مجموعات الملفات الثانوية المتشابهة

#### ملفات CSV الخام لنتائج الأداء
| الملف | المسار الكامل | الفئة | الدور |
| --- | --- | --- | --- |
| `dashboard_stats.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\dashboard_stats.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_failures.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\dashboard_failures.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_exceptions.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\dashboard_exceptions.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_stats_history.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\dashboard_stats_history.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_stats.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\history_stats.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_failures.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\history_failures.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_exceptions.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\history_exceptions.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_stats_history.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\before\history_stats_history.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_stats.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\dashboard_stats.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_failures.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\dashboard_failures.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_exceptions.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\dashboard_exceptions.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `dashboard_stats_history.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\dashboard_stats_history.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_stats.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\history_stats.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_failures.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\history_failures.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_exceptions.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\history_exceptions.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
| `history_stats_history.csv` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\after\history_stats_history.csv` | Testing Documentation | ملف evidence خام لنتائج الأداء؛ يُستخدم كمدخل تحليلي ولا يحمل منطق تنفيذ. |
هذه المجموعة لم تُشرح فردياً لأن الملفات متشابهة جداً في بنيتها أو دورها، لكنها أُدرجت في الفهرس الكامل وفي هذا الملخص حتى لا تضيع أي evidence مهمة.

#### وثائق frontend المساندة للتشغيل والحوكمة
| الملف | المسار الكامل | الفئة | الدور |
| --- | --- | --- | --- |
| `architecture.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\docs\architecture.md` | Testing Documentation | وثيقة مرجعية أو evidence تشرح سلوك الاختبارات أو التشغيل أو النتائج. |
| `ldplayer_setup.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\docs\ldplayer_setup.md` | Testing Documentation | وثيقة مرجعية أو evidence تشرح سلوك الاختبارات أو التشغيل أو النتائج. |
هذه المجموعة لم تُشرح فردياً لأن الملفات متشابهة جداً في بنيتها أو دورها، لكنها أُدرجت في الفهرس الكامل وفي هذا الملخص حتى لا تضيع أي evidence مهمة.

## 17. مصفوفة ربط متطلبات التكليف بالتنفيذ

تم بناء هذه المصفوفة بالاعتماد على ملف التكليف الخارجي `testing_assignment.pdf` الذي يطلب ستة بنود أساسية وبند bonus اختياري.

| المتطلب | مكان التنفيذ في المشروع | الدليل | الحالة |
| --- | --- | --- | --- |
| CI/CD Pipeline with Security Check | `.github/workflows/ci.yml`, `.pre-commit-config.yaml`, `.gitleaks.toml`, `.gitleaksignore` | وجود jobs صريحة لـ `gitleaks`, `pre-commit`, `backend-tests`, `flutter-analyze`, `flutter-test`, `flutter-integration-test` | مكتمل |
| Unit Testing | `Implementation/vitamate_backend/core/tests`, `users/tests`, `gamification/tests`, `Implementation/vitamate_frontend/test` | وجود 91 سيناريو backend تقريبياً و22 سيناريو frontend تقريبياً | مكتمل |
| Integration Testing | `test_api_contracts.py`, `test_chronic_conditions.py`, `test_medications.py`, Flutter integration files | اختبارات API/DB حقيقية + اختبارات Flutter ضد backend حي | مكتمل |
| Performance Testing | `loadtest/locustfile.py`, `seed_performance_dataset.py`, `docs/performance/*` | before/after CSVs + baseline notes + performance report | مكتمل |
| E2E Testing using Playwright | `Implementation/vitamate_frontend/integration_test/*` | يوجد E2E فعلي باستخدام Flutter `integration_test` وليس Playwright | جزئي |
| In-Session Practical (TDD + AI + MCPs + visual/manual automation) | غير موجود داخل الريبو الحالي | لا توجد artefacts داخل المشروع لهذا الجزء لأنه live requirement | غير موجود في الريبو |
| Bonus: Performance Optimization | `docs/performance/performance_report.md` + ملفات الإنتاج المعدلة + `test_health_state_orchestration.py` | before/after measurable evidence مع تفسير bottlenecks | مكتمل كبونس |

## 18. الفجوات والملاحظات

أهم الفجوات التي ظهرت من المقارنة بين التكليف والريبو:

1. **Playwright غير موجود فعلياً**
   - الموجود هو Flutter `integration_test`.
   - هذا قوي هندسياً، لكنه ليس مطابقاً حرفياً لاسم الأداة في التكليف.

2. **الجزء live داخل الجلسة غير موجود في الريبو**
   - وهذا طبيعي جزئياً، لكنه يعني أن الريبو وحده لا يكفي لإثبات هذا البند.

3. **لا يوجد coverage report ملتزم**
   - توجد اختبارات كثيرة، لكن لا توجد نسبة تغطية رسمية مرفقة.

4. **لا يوجد CI badge أو run evidence ملتزم**
   - يوجد workflow واضح، لكن evidence التنفيذ التاريخي غير ملتزمة داخل repo.

5. **لا توجد Playwright files**
   - نتيجة المسح الحالي: `نعم` بالنسبة لعدم وجود Playwright tests فعلية.

6. **لا يوجد دليل رسمي على آخر حالة CI داخل README**
   - نتيجة المسح الحالي: `لا يوجد badge`.

## 19. الخلاصة والتوصيات

### 19.1 التقييم العام

من منظور هندسي بحت، منظومة الاختبار في VitaMate **جيدة إلى قوية**، وأقواها في:

- backend contracts والتكامل الحقيقي
- Flutter integration flow الحقيقي
- performance evidence قبل/بعد
- CI/security gates الواضحة

### 19.2 نقاط القوة

- تعدد طبقات التحقق وعدم الاكتفاء بمستوى واحد.
- وجود seed commands قابلة لإعادة الاستخدام.
- وجود evidence أداء ملموسة.
- وجود اختبارات انحدار تحمي التحسينات من التراجع.
- وجود فصل واضح بين bootstrap الإنتاجي ووضع الاختبار في Flutter.

### 19.3 أبرز الفجوات

- عدم وجود Playwright فعلياً.
- غياب live-session artifacts داخل الريبو.
- غياب coverage/reporting المركزي لبعض الاختبارات.

### 19.4 توصيات عملية قصيرة

- إذا كان المطلوب الأكاديمي حرفياً، أضيفوا سيناريو Playwright واحداً على واجهة ويب أو واجهة مبسطة بديلة، أو اتفقوا صراحة مع المدرس على قبول Flutter integration test كبديل native.
- أضيفوا badge CI ويفضل screenshot أو link موثق لآخر run ناجح.
- أضيفوا coverage report إن أردتم رفع النضج الرسمي للتقرير.
- أبقوا performance harness كما هو لأنه صار نقطة قوة حقيقية للمشروع.

## 20. الملخص النهائي المتوافق مع ملف الطلبات

هذا القسم موضوع خصيصاً ليطابق طلبك الأخير بشكل مباشر، ويقدم خلاصة تنفيذية سريعة:

- تم تحليل المشروع من الجذر حتى ملفات الاختبار والتشغيل والأداء.
- تم بناء الفهرس على مستوى الملفات، لا على مستوى overview عام فقط.
- تم شرح backend وfrontend والأدوات ومسارات التشغيل بلغة موجهة لشخص خارجي.
- تم توثيق النتائج الفعلية الموجودة فقط، خصوصاً الأداء before/after.
- تم توضيح الفجوات الصريحة: Playwright غير موجود فعلياً، وlive in-session work ليس ضمن artefacts الريبو.
- تم الحفاظ على distinction واضح بين ما هو **موجود فعلياً** وما هو **غير موجود** أو **جزئي**.

| معيار القبول | الحالة |
| --- | --- |
| تم فحص بنية المشروع وتحديد ملفات testing الأساسية | نعم |
| تم إنشاء فهرس CSV للملفات | نعم |
| تم إنشاء تقرير Markdown مصدر غني ومفصل | نعم |
| تم إنشاء ملف Word نهائي `.docx` | نعم بعد خطوة التحويل من HTML إلى Word |
| التقرير يشرح المشروع لشخص خارجي | نعم |
| التقرير يشرح كل أقسام testing الموجودة فعلياً | نعم |
| التقرير يشرح كل ملف testing مهم بشكل موجز وواضح | نعم |
| التقرير يحتوي snippets كود مناسبة | نعم |
| التقرير يشرح الأدوات وطرق التشغيل والتفعيل | نعم |
| التقرير يذكر النتائج والأدلة الفعلية فقط دون تخمين | نعم |
| التقرير يتضمن قسم أداء وتحسينات | نعم |
| التقرير يتضمن خاتمة احترافية ومصفوفة ربط | نعم |

## Appendix: فهرس الملفات المشروحة

| الفئة | الملف | المسار الكامل | الأهمية |
| --- | --- | --- | --- |
| Testing Documentation | `README.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\README.md` | critical |
| CI Workflow File | `ci.yml` | `C:\Users\Salam Ayash\Desktop\VitaMate\.github\workflows\ci.yml` | critical |
| Security/Quality Config | `.pre-commit-config.yaml` | `C:\Users\Salam Ayash\Desktop\VitaMate\.pre-commit-config.yaml` | critical |
| Security/Quality Config | `.gitleaks.toml` | `C:\Users\Salam Ayash\Desktop\VitaMate\.gitleaks.toml` | critical |
| Security/Quality Config | `.gitleaksignore` | `C:\Users\Salam Ayash\Desktop\VitaMate\.gitleaksignore` | supportive |
| Security/Quality Config | `.env.example` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\.env.example` | supportive |
| Testing Documentation | `requirements.txt` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\requirements.txt` | supportive |
| Testing Documentation | `api_contract_baseline.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\docs\api_contract_baseline.md` | critical |
| Test Utility | `helpers.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\test_utils\helpers.py` | critical |
| Test Data / Seed Utility | `seed_integration_user.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\management\commands\seed_integration_user.py` | critical |
| Test Data / Seed Utility | `seed_performance_dataset.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\management\commands\seed_performance_dataset.py` | critical |
| Performance Test File | `locustfile.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\loadtest\locustfile.py` | critical |
| Backend Test File | `test_api_contracts.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_api_contracts.py` | critical |
| Backend Test File | `test_health_state_orchestration.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\orchestration\test_health_state_orchestration.py` | critical |
| Backend Test File | `test_chronic_conditions.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\chronic\test_chronic_conditions.py` | critical |
| Backend Test File | `test_medications.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\medication\test_medications.py` | critical |
| Backend Test File | `test_constraints.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\constraints\test_constraints.py` | critical |
| Backend Test File | `test_water.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\hydration\test_water.py` | critical |
| Backend Test File | `test_nutrition.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\nutrition\test_nutrition.py` | critical |
| Backend Test File | `test_seed_integration_user.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\management\test_seed_integration_user.py` | critical |
| Backend Test File | `test_seed_performance_dataset.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\management\test_seed_performance_dataset.py` | critical |
| Backend Test File | `test_import_paths.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_import_paths.py` | supportive |
| Backend Test File | `test_isolation_and_permissions.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\misc\test_isolation_and_permissions.py` | critical |
| Backend Test File | `test_activity.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_activity.py` | supportive |
| Backend Test File | `test_sleep.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_sleep.py` | supportive |
| Backend Test File | `test_steps.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\core\tests\tracking\test_steps.py` | supportive |
| Backend Test File | `test_auth.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\users\tests\test_auth.py` | critical |
| Backend Test File | `test_profile_metrics.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\users\tests\test_profile_metrics.py` | supportive |
| Backend Test File | `test_points.py` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_backend\gamification\tests\test_points.py` | supportive |
| Testability Support File | `pubspec.yaml` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\pubspec.yaml` | critical |
| Testability Support File | `bootstrap.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\bootstrap.dart` | critical |
| Testability Support File | `main.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\main.dart` | supportive |
| Testability Support File | `app_test_keys.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\lib\core\testing\app_test_keys.dart` | critical |
| Frontend Test File | `auth_controller_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_controller_test.dart` | critical |
| Frontend Test File | `auth_flow_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_flow_test.dart` | critical |
| Frontend Test File | `auth_interceptor_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\auth_interceptor_test.dart` | critical |
| Frontend Test File | `notifications_schedule_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\notifications_schedule_test.dart` | supportive |
| Frontend Test File | `steps_permission_ui_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\steps_permission_ui_test.dart` | supportive |
| Frontend Test File | `token_storage_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\token_storage_test.dart` | supportive |
| Frontend Test File | `widget_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\widget_test.dart` | supportive |
| Frontend Test File | `chronic_conditions_controller_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\chronic_conditions\chronic_conditions_controller_test.dart` | critical |
| Frontend Test File | `chronic_conditions_screen_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\chronic_conditions\chronic_conditions_screen_test.dart` | critical |
| Frontend Test File | `dashboard_data_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\home\dashboard_data_test.dart` | supportive |
| Frontend Test File | `medications_controller_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\medications\medications_controller_test.dart` | critical |
| Frontend Test File | `nutrition_controller_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\nutrition\nutrition_controller_test.dart` | critical |
| Frontend Test File | `water_controller_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test\features\water\water_controller_test.dart` | critical |
| Integration Test File | `test_helpers.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\test_helpers.dart` | critical |
| Integration Test File | `smoke_login_home_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\smoke_login_home_test.dart` | critical |
| Integration Test File | `chronic_flow_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\integration_test\chronic_flow_test.dart` | critical |
| Integration Test File | `integration_test.dart` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\vitamate_frontend\test_driver\integration_test.dart` | supportive |
| Testing Documentation | `baseline_notes.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\baseline_notes.md` | critical |
| Testing Documentation | `performance_report.md` | `C:\Users\Salam Ayash\Desktop\VitaMate\Implementation\docs\performance\performance_report.md` | critical |


الفهرس الكامل الموسع محفوظ أيضاً في الملف المستقل `VitaMate_Testing_File_Index.csv` داخل مجلد `Implementation`.
