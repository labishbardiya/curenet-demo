# CureNet

Senior-friendly, rural-first Flutter app (patient-owned ABHA Personal Health Record). Matches v5 HTML prototype; supports 22 Indian languages via Bhashini TTS.

## Run with Bhashini TTS (22 Indian languages)

Use your **Inference API Key** from [Bhashini Dashboard](https://dashboard.bhashini.co.in) (List of API Keys → Inference API Key Value):

```bash
flutter run --dart-define=BHASHINI_API_KEY=your_inference_api_key_here
```

Optional: **Udyam Key** for other Bhashini APIs:

```bash
flutter run --dart-define=BHASHINI_API_KEY=... --dart-define=BHASHINI_UDYAM_KEY=...
```

Without these, the app falls back to device TTS (flutter_tts). Speaker icons appear on Chat, Records, Profile, QR Share, and Notifications.

## ABDM integration

ABDM service layer is in `lib/services/abdm_service.dart`, following the **ABDM ABHA V3 APIs** guide and AyushmanNHA YouTube workflows:

- **M1**: Session, get public key, Aadhaar OTP request/verify, ABHA address suggestion/confirm, profile, ABHA card, scan & share (bridge URL).
- Base URL (sandbox): `https://dev.ndhm.gov.in/devservice/gateway`

Use the attached **ABDM_ABHA_V3_AP_Is_V1_31_07_2025** PDF and sandbox Postman collection for exact endpoint paths and request bodies. Register your app on the [ABDM Sandbox](https://sandbox.abdm.gov.in) to get Client ID and Client Secret for `AbdmService.createSession()`.

## Getting Started

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
