# تفعيل Sign in with Apple في Hiwar

تمت إضافة زر Apple إلى Flutter، وتمت إضافة تحقق `identityToken` في Backend. لكي يعمل تسجيل الدخول الحقيقي على iPhone، يجب إكمال إعدادات Apple Developer على حساب المطور.

## إعداد Apple Developer

أنشئ أو استخدم App ID لتطبيق iOS، واجعل Bundle ID مطابقًا لقيمة `PRODUCT_BUNDLE_IDENTIFIER` في مشروع Flutter، مثل `com.hiwar.app`. فعّل capability باسم **Sign in with Apple** لهذا App ID.

ضع Bundle ID نفسه في Backend المحلي:

```env
APPLE_CLIENT_ID=com.hiwar.app
```

لا تضع Apple Team Secret أو private key داخل Flutter أو GitHub.

## إعداد Flutter iOS

من مجلد frontend نفّذ:

```powershell
flutter create .
flutter pub get
```

افتح المشروع في Xcode، ثم افتح Runner، واختر Target باسم Runner، ثم **Signing & Capabilities → + Capability → Sign in with Apple**. تأكد أن Team وBundle Identifier صحيحان.

## تشغيل Backend

ثبّت المتطلبات ثم شغّل Backend:

```powershell
cd Backend
..\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## ملاحظات Apple

Apple قد يعيد البريد والاسم في أول تسجيل فقط. لذلك يعتمد Backend على `sub` الثابت من Apple لربط الحساب، ولا يعتمد على البريد وحده. وقد يكون البريد من نوع Apple Private Relay، وهذا طبيعي.

زر Apple مخصص عمليًا لـ iOS. تشغيله على Chrome يحتاج إعداد Service ID وReturn URL مختلفًا، أما اختبار App Store فيكون على iPhone أو Simulator مدعوم.
