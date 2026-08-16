# تسجيل الدخول وملف المستخدم في حوار App

أضيف إلى Flutter تدفقًا يبدأ بشاشة تسجيل دخول Google أو دخول يدوي، ثم onboarding يجمع الاسم والعمر والمرحلة والشهادات وسبب تعلم الإنجليزية. بعد الحفظ تظهر البيانات في «حسابي»، ويستخدم الاسم الحقيقي في الصفحة الرئيسية بدل الاسم التجريبي.

## مسارات Backend الجديدة

```text
POST /api/v1/auth/sign-in
GET  /api/v1/profile/{user_id}
PUT  /api/v1/profile
```

يقوم Backend بترحيل أعمدة users الجديدة تلقائيًا عند الإقلاع: `age`, `education_level`, `certificates`, `learning_reason`, `profile_complete`, وحقول مزود المصادقة.

## Google Sign-In

أضيفت حزمة `google_sign_in` إلى Flutter. يلزم إعداد OAuth في Google Cloud وربط Client ID للمنصة المستخدمة. على Android يجب إضافة SHA-1/SHA-256 وملف `google-services.json` عند استخدام Firebase، وعلى iOS إضافة Client ID وURL scheme، وعلى Web تمرير Client ID في إعداد Google Sign-In الخاص بالويب.

المسار الحالي يرسل `user_id` و`email` واسم المستخدم إلى Backend. قبل النشر العام يجب إضافة تحقق الخادم من Google ID token بدل الوثوق بالقيم القادمة من العميل؛ endpoint الحالي مناسب للتطوير المحلي فقط.

## التشغيل بعد التحديث

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

شغّلي Backend من مجلد `Backend`:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

إذا لم تُضبط Google credentials بعد، استخدمي «دخول» اليدوي مؤقتًا لاختبار onboarding وحفظ الملف الشخصي.
