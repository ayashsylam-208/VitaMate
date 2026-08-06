# دليل ربط خدمة تحليل الوجبات بالذكاء الاصطناعي

## البنية المعتمدة

```text
Flutter -> Django -> AI Service على 127.0.0.1:8010
```

تطبيق Flutter لا يتصل بخدمة AI مباشرة. خدمة AI تقترح الطبق والمكونات فقط،
والمستخدم يؤكد الاختيار والأوزان. بعدها يحسب Django القيم الغذائية من
`NutritionFacts` ويحفظ الوجبة والنقاط والترطيب والعادات.

لا نستخدم نتيجة `/finalize` الموجودة داخل الحزمة كمصدر غذائي، ولا نعتمد على
جلسة الحزمة الموجودة في الذاكرة لحفظ الوجبة. جلسة VitaMate محفوظة في قاعدة
بيانات Django ضمن `ai_meals`.

## التثبيت والتشغيل

من مجلد `vitamate_backend`:

```powershell
$env:AI_MEALS_SERVICE_TOKEN='ضع-هنا-token-عشوائي-بطول-32-محرف-على-الأقل'
.\scripts\install_ai_service.ps1
.\scripts\run_ai_service.ps1
```

ثم شغّل Django في نافذة ثانية بنفس الـ token:

```powershell
$env:DJANGO_SETTINGS_MODULE='vitamate_project.settings_dev'
$env:AI_MEALS_BASE_URL='http://127.0.0.1:8010'
$env:AI_MEALS_SERVICE_TOKEN='ضع-هنا-نفس-token-المستخدم-في-خدمة-AI'
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000 --noreload
```

اختبار الجاهزية:

```powershell
curl.exe http://127.0.0.1:8010/healthz
curl.exe http://127.0.0.1:8010/readyz
```

`healthz` يعني أن العملية تعمل. `readyz` يحمّل pipeline فعلياً ويعيد `503`
إذا فشل تحميل الموديلات.

## قواعد إلزامية

- `auto_weight_mode=skip` هو الافتراضي في المرحلة الحالية.
- كل صورة تمر بالتحقق من النوع والحجم والأبعاد وإزالة EXIF داخل Django.
- كل component مفعّل يحتاج FoodItem صالحاً ووزناً مؤكداً من المستخدم.
- إعادة finalize تستخدم نفس `Idempotency-Key` ولا تنشئ وجبة أو نقاطاً ثانية.
- token الخدمة داخلي، ولا يوضع أبداً داخل Flutter.

للتفاصيل المعمارية والعقود والاختبارات راجع
`docs/nutrition_ai_integration.md`.
