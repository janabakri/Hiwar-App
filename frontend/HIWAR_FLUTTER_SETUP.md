# Hiwar Flutter + Speak UI

تمت إعادة بناء الواجهة داخل `frontend/lib/screens/home_screen.dart` مع الحفاظ على تطبيق Flutter الموجود. أضيفت أربع وجهات في الشريط السفلي: الرئيسية، استكشف، تقدّمي، وحسابي. كما أضيف مسار المحادثة الصوتية والملاحظات بعد إنهاء المحادثة.

## ربط الحساب

تستخدم شاشة «حسابي» المسار:

```text
GET /api/v1/stats/{user_id}
```

ويُحفظ `user_id` عبر `shared_preferences`. إذا لم يوجد ملف بيئة، يستخدم التطبيق العنوان الافتراضي `http://10.0.2.2:8000` المناسب لمحاكي Android مع Backend يعمل على جهاز التطوير.

لجهاز حقيقي أو iOS، أنشئي ملف `.env` داخل `frontend` وأضيفيه إلى assets في `pubspec.yaml`، ثم ضعي:

```env
API_BASE_URL=http://YOUR_COMPUTER_IP:8000
```

أما Flutter Web فيمكن استخدام `http://localhost:8000` عند تشغيل Backend محليًا، مع تفعيل CORS.

## التشغيل

من داخل مجلد `frontend`:

```bash
flutter pub get
flutter run
```

بيئة التنفيذ الحالية لا تحتوي على Flutter SDK، لذلك لم أتمكن من تشغيل `flutter analyze` أو بناء APK داخل هذه الجلسة. تم فحص الملفات والتعديلات نصيًا، ويجب تنفيذ الأمرين على جهازك أو بيئة Flutter للتحقق النهائي.
