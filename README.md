# study_sync_planner & Reminder

📚 Study Sync — Modern Study & Collaboration App (Flutter + Firebase)

Study Sync is a modern, productivity-focused mobile application designed for students to study, collaborate, track progress, and manage personal learning goals.
The app is built using Flutter, Firebase, and Material 3, providing a seamless, fast, and visually polished experience.


---

🚀 Features

🔹 1. Group Study

Create and join study groups

Real-time chats

Group announcements

Member list with online/offline indicators

Manage group tasks and activities


🔹 2. Personal Study

Add goals and assignments

Sub-tasks / checklist

Track deadlines

Auto-save with Firestore

Simple UI for fast task entry

Clean timeline-based layout


🔹 3. Private Messaging (DMs)

Real-time one-to-one chat

List of active users

Tap on a username → open private chat

Live message sync (WebSockets / Firebase listeners)

Smooth UI with chat bubbles


🔹 4. Authentication

Firebase Auth

Email/Password Login

Multi-user support

Google login (optional)


🔹 5. Material 3 UI

Full M3 widgets

Dynamic color scheme

Responsive layout

Smooth animations


🔹 6. Notifications

Group notifications

Personal chat notifications

Goal/task reminders (optional)



---

🏗️ Tech Stack

Technology	Purpose

Flutter	Mobile UI
Firebase Auth	User authentication
Firebase Firestore	Real-time database
Firebase Storage	Image/file uploads
Material 3	Modern UI
Provider / Riverpod (optional)	State management



---

📁 Project Structure

lib/
 ├── authentication/
 ├── home/
 ├── personal_study/
 ├── group_study/
 ├── private_chat/
 ├── widgets/
 ├── models/
 └── main.dart


---

⚙️ Configuration Setup

🔧 1. Add Firebase to Flutter

Add your google-services.json inside:

android/app/

Add the dependency:

classpath 'com.google.gms:google-services:4.4.2'

And inside app/build.gradle:

apply plugin: 'com.google.gms.google-services'


---

📦 Dependencies (pubspec.yaml)

dependencies:
  flutter:
    sdk: flutter

  firebase_core: ^3.7.0
  cloud_firestore: ^5.4.4
  firebase_auth: ^5.3.2
  firebase_storage: ^12.1.0

  intl: ^0.19.0
  flutter_slidable: ^3.1.1
  uuid: ^4.5.1
  google_fonts: ^6.2.1


---

▶️ Run the Project

flutter pub get
flutter run


---

🧩 Key Modules Overview

📘 Personal Study Module

Handles:

Goals

Tasks

Deadlines

Progress tracking


All saved in Firestore under user ID.

👥 Group Study Module

Features:

Groups

Real-time chat

Members

Group tasks


💬 Private Chat Module

One-to-one messaging

Real-time sync

Message persistence


All implemented in PrivateChatView.


---

📸 App Logo

(Generated using your preferred tool — nanopapaya/geminai prompt included)

Suggested Prompt:

> “Design a modern, minimal, gradient-based logo for an education and study app named Study Sync. Use a book + sync/connection icon integrated. Colors: purple, blue, teal gradients. Flat Material-3 style. Clean, professional, simple.”




---

🧪 Future Enhancements

Dark mode

AI study assistant

Timetable generator

Better analytics dashboard

Advanced group management



---

🤝 Contributing

Pull requests are welcome.
For major changes, please open an issue first to discuss what you would like to change.



