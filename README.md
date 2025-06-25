# 🚀 SmartChat App

**SmartChat** is a modern, responsive Flutter chat application featuring secure authentication and real-time messaging.  
Built with clean architecture, Firebase backend, and elegant UI — it demonstrates best practices in mobile app development using Flutter.

---

## 🌟 Features

### 🔐 Authentication
- ✅ Google Sign-In with Firestore user creation
- ✅ Phone number sign-in with OTP verification
- ✅ Secure login flows — no unverified emails or numbers

### 🏠 Home Screen
- 🎨 Soft gradient background (adapts to light/dark mode)
- 👤 User’s name and profile picture at the top
- 💬 "Start New Chat" button (FAB)
- 🧾 Scrollable list of recent chats with styled cards
- ⚙️ AppBar with app name and logout/settings icon

### 💬 Chat Screen
- 📡 Real-time messaging using Firebase Firestore
- 💬 Message bubbles styled for sender/receiver
- ⏱️ Timestamps for all messages
- 🗓️ Support for **scheduled messages** (automatically sent at the scheduled time)

---

## 🧱 Architecture

- 🎯 Uses **Riverpod** for scalable state management
- 🧼 Clean service-layered code:
  - `AuthService` – handles Google/Phone login
  - `FirestoreService` – chat and user operations
- 🎨 Adapts to system light/dark mode using **Material 3** and `GoogleFonts.poppins`
- 📱 Fully responsive layout — works on small and large screens

---

## 🧪 Code Quality

- 📦 Firestore & Auth logic abstracted into service classes
- 🔒 `UserModel`, `MessageModel` used for safe and structured data handling
- ✅ No deprecated Flutter APIs
  - All opacities use `.withAlpha((opacity * 255).toInt())`
- ✨ UI follows modern standards with clean spacing, padding, and accessibility

---

## 🚧 Roadmap

- [ ] Upload & view media (images, docs)
- [ ] Profile screen (edit display name, status, photo)
- [ ] AI-powered message assistant
- [ ] Notification system
- [ ] Group chat support
- [ ] Deploy to Play Store

---

## 🛠️ Getting Started

### 🔧 Prerequisites
- Flutter (latest stable)
- Firebase project configured
- `google-services.json` added under `android/app`

### 🧪 Firebase Setup
1. Enable Google and Phone auth in Firebase Console
2. Add your Android app with the SHA1 key
3. Download and place `google-services.json` into `android/app`
4. Run:

```bash
flutter pub get
flutter run