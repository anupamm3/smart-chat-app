# 🚀 SmartChat App

**SmartChat** is a modern, responsive Flutter chat application built with Firebase, Riverpod, and Material 3.  
It supports secure authentication, real-time 1-on-1 and group messaging, and scheduled messages — all in a clean, WhatsApp-inspired UI.

---

## 🌟 Features

### 🔐 Authentication
- ✅ Google Sign-In with Firestore user creation
- ✅ Phone number sign-in with OTP verification
- ✅ Secure login flows — no unverified emails or numbers

### 📇 Contact Integration
- 🔄 Syncs device contacts and matches them with registered users
- 📱 Displays contact names for known users, falls back to phone number otherwise

### 🏠 Home Screen
- 🎨 Soft gradient background (adapts to light/dark mode)
- 🔍 Search bar to filter chats
- 📁 Bottom navigation bar (Chats, Groups, Calls, Profile)
- 💬 "Start New Chat" FAB navigates to filtered contact list
- 🧾 Scrollable recent chat list with previews and timestamps

### 💬 One-to-One Chat
- 📡 Real-time messaging with Firebase Firestore
- ✅ Message delivery ticks and timestamps
- 🎈 Modern chat UI with styled bubbles

### 👥 Group Chat
- ➕ Create groups by selecting contacts
- 🗨️ Real-time group messaging with all members
- 🧑‍🤝‍🧑 Group info (name, photo, members) shown in chat screen
- 🧩 Group creator can delete group; others can leave it
- 🔁 Group list shows previews of last messages

### ⏰ Scheduled Messages
- 🗓️ Send messages at a future time in both personal and group chats
- 💬 Messages stored in Firestore with delivery scheduled client-side
- 🚀 Sent automatically when due (checks every 30 seconds)

### ⚙️ Group Management
- ✅ View group members and creator
- ➕ Add members to group (admin only)
- ❌ Leave or delete group based on user role

### 🖼️ UI and Design
- 📱 Responsive layout for all screen sizes
- 🎨 Built with Material 3 and Google Fonts
- 🌘 Supports light and dark modes
- ✨ Rounded cards, smooth padding, and floating buttons

---

## 🧱 Architecture

- 🎯 **Riverpod** for scalable and testable state management
- 🧼 Modular structure with clean separation of concerns
  - `AuthService` handles Google/Phone login
  - `FirestoreService` handles user, chat, group, and message data
- 🔄 Real-time data updates using Firestore streams
- 📁 Models for `User`, `Message`, and `Group` ensure type safety

---

## 🧪 Code Quality

- 📦 Firestore and authentication logic abstracted into service classes
- 🔐 Typed models for safer and clearer data usage
- 🧹 No deprecated APIs used
  - Uses `.withAlpha((opacity * 255).toInt())` instead of deprecated `.withOpacity()`
- 💡 Code is structured for maintainability and future expansion

---

## 🛠️ Getting Started

### 🔧 Prerequisites
- Flutter (latest stable version)
- Firebase project (with Firestore and Auth enabled)
- Android device/emulator

### 🧪 Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project and add an Android app
3. Add your SHA-1 key (use `.\gradlew signingReport`)
4. Download `google-services.json` and place it in `android/app/`
5. Enable **Google Sign-In** and **Phone Authentication** under Firebase → Authentication → Sign-in method

### ▶️ Run Locally

```bash
flutter pub get
flutter run
