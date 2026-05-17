# 🤖 DJTrip - AI Chatbot Integration Guide

This guide explains how the AI Documentation Assistant is integrated into the DJTrip platform, the changes made to automate its operation, and how to manage it.

---

## 1. 🧠 System Overview

The AI Chatbot is a specialized micro-service designed to answer user questions based on the project's documentation. It uses **RAG (Retrieval-Augmented Generation)** to provide accurate and context-aware answers.

### How it works:
1. **Knowledge Indexing**: The system parses documentation files (`.md`, `.txt`) and converts them into "embeddings" (vector representations).
2. **Vector Search**: When a user asks a question, the system searches for the most relevant parts of the documentation.
3. **AI Reasoning**: These relevant parts are sent to **Google Gemini (1.5 Flash)** along with a specialized "Expert Persona" prompt.
4. **Contextual Response**: The AI provides an answer strictly based on the project's logic, UI, and business rules.

---

## 2. 🚀 Automated Integration Logic

To simplify development and deployment (especially for **Render**), the chatbot is now fully integrated into the main backend lifecycle.

### Key Automation Features:
- **Auto-Launch**: When you start the main server (`Back/server.js`), it automatically spawns the chatbot service as a background process.
- **Reverse Proxy**: The main server (port 3000) acts as a gateway. Requests to `/chatbot/*` are forwarded to the chatbot (port 3001). This allows everything to run through a single public port (essential for Render).
- **API Key Sync**: The `GEMINI_API_KEY` is automatically shared from the main `.env` to the chatbot during launch.
- **Dependency Management**: A `postinstall` script ensures that chatbot dependencies are installed automatically during deployment.

---

## 3. 📁 Modified Files & Changes

### Backend (`Back/`)
- **[server.js](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/Back/server.js)**: 
    - Added `child_process.spawn` to launch the chatbot.
    - Configured `http-proxy-middleware` to route `/chatbot` requests.
    - Synced environment variables (`GEMINI_API_KEY`).
- **[package.json](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/Back/package.json)**:
    - Added `postinstall` script: `cd ../ai-docs-chatbot && npm install`.
    - Added `http-proxy-middleware` dependency.

### Frontend (`Front/`)
- **[app_config.dart](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/Front/lib/config/app_config.dart)**:
    - Updated `aiChatUrl` to use the proxied path `$apiBaseUrl/chatbot`.

### AI Chatbot (`ai-docs-chatbot/`)
- **[reindex-docs.js](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/ai-docs-chatbot/src/scripts/reindex-docs.js)**:
    - Added support for **local files** (merging project root docs with GitHub docs).
- **[localDocService.js](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/ai-docs-chatbot/src/services/localDocService.js)**:
    - New service to read `DJTrip_Documentation.md` and other root files.
- **[geminiChatService.js](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/ai-docs-chatbot/src/services/geminiChatService.js)**:
    - Enhanced "Expert Persona" prompt for better accuracy on UI/UX and logic.
- **[.env](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/ai-docs-chatbot/.env)**:
    - Created/Updated with current API keys and local configuration.

---

## 🛠️ Management Commands

### Start the entire system
From the `Back/` folder:
```bash
npm run dev
```
*(This will start the API on 3000 AND the Chatbot on 3001 automatically)*

### Update the AI Knowledge (Reindexing)
Whenever you modify `DJTrip_Documentation.md` or add new documentation files, you must update the AI's memory:
```bash
cd ai-docs-chatbot
npm run reindex
```

### Test the Chatbot Logic
To test the AI response in the terminal without opening the mobile app:
```bash
cd ai-docs-chatbot
npm test
```

---

## 📖 Best Practices for Documentation

To keep the AI "smart", always document new features in **`DJTrip_Documentation.md`**. 
The AI is now specifically instructed to look for:
- **Screens**: Their purpose and path.
- **Buttons**: Their labels and icons (e.g., `Icons.add`).
- **Business Logic**: How statuses change (e.g., Pending -> Approved).
- **Icons**: The exact Material Icon names.

For a detailed catalog of the current interface, see [DJTrip_Interface_Catalog.md](file:///c:/Users/ASUS/Desktop/pfe_djtrip-github/DJTrip_Interface_Catalog.md).
