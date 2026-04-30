# CureNet

India's first ABDM-native health intelligence platform. CureNet integrates with the Ayushman Bharat Digital Mission (ABDM) to provide a unified, secure, and intelligent healthcare experience.

## Features

- **ABDM Integration:** Full support for ABHA creation, linking, and secure health data exchange (M1 & M2 compliant).
- **ABHAy AI Assistant:** An intelligent health assistant that uses RAG (Retrieval-Augmented Generation) with your health records to provide personalized insights.
- **Smart Health Locker:** Secure, biometrically protected storage for your medical documents.
- **Clinical Data Extraction (OCR):** Automatically extract structured clinical data (FHIR R4) from photos of prescriptions and lab reports.
- **Multilingual Support:** Accessible in English, Hindi, and Bengali with Bhashini translation and text-to-speech.
- **Emergency Snapshot:** A quick, comprehensive view of critical health information for emergency situations.

## Prerequisites

- Flutter SDK `^3.11.0`
- Access to ABDM Sandbox credentials
- API keys for Groq, Tavily, and Bhashini

## Setup

1. **Clone the repository.**
2. **Install dependencies:**
   ```bash
   cd curenet
   flutter pub get
   ```
3. **Run the app:**
   You must provide the required API keys via `dart-define` or an environment configuration file:
   ```bash
   flutter run \
     --dart-define=GROQ_API_KEY=your_groq_key \
     --dart-define=TAVILY_API_KEY=your_tavily_key \
     --dart-define=ABDM_CLIENT_ID=your_abdm_client_id \
     --dart-define=ABDM_CLIENT_SECRET=your_abdm_client_secret \
     --dart-define=BHASHINI_API_KEY=your_bhashini_key \
     --dart-define=BHASHINI_USER_ID=your_bhashini_user \
     --dart-define=BHASHINI_AUTH=your_bhashini_auth
   ```

## Development Mode Toggle

The app includes a hidden development toggle to switch between demo data (hardcoded persona) and live local data:
- On the **Home Screen**, **long-press** the greeting text ("Good morning, Priya") to open the toggle menu.