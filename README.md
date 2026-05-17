# DJTrip — Plateforme Tourisme Djerba

Application mobile full-stack dédiée au tourisme à Djerba, développée dans le cadre d'un projet de fin d'études (PFE).

---

## 🗂️ Structure du Projet

```
pfe_djtrip/
├── Front/          # Application mobile Flutter (iOS / Android)
├── Back/           # API REST Node.js + Express + MongoDB
├── ai-docs-chatbot/ # Chatbot IA de documentation (RAG + Gemini)
└── documentation/  # Diagrammes UML, cas d'utilisation, classe
```

---

## 🛠️ Stack Technique

### Mobile (Front)
- **Flutter** — Framework UI cross-platform
- **Provider** — Gestion d'état
- **Hive** — Stockage local offline
- **Socket.IO Client** — Temps réel
- **Google Maps Flutter** — Cartographie

### Backend (Back)
- **Node.js / Express** — API REST
- **MongoDB / Mongoose** — Base de données
- **Firebase Admin** — Push notifications FCM
- **Socket.IO** — WebSocket temps réel
- **Cloudinary** — Stockage médias
- **Nodemailer** — Emails transactionnels

### IA / Chatbot
- **Google Gemini** — Modèle de langage
- **RAG (Retrieval-Augmented Generation)** — Indexation documentation

---

## 🚀 Lancer le projet

### Backend
```bash
cd Back
npm install
npm start
```

### Frontend
```bash
cd Front
flutter pub get
flutter run
```

---

## 📅 Dernière mise à jour
Mai 2026 — Version finale PFE
