# DJTrip — Backend API

A RESTful backend API powering **DJTrip**, a tourism activity booking platform for Djerba, Tunisia. It enables tourists to discover and book local activities, and organizers to manage their offerings — with real-time messaging and WebRTC call signaling built in.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 18+ |
| Framework | Express |
| Database | MongoDB + Mongoose |
| Auth | JWT (access + refresh tokens) |
| Real-time | Socket.io |
| File storage | Cloudinary |
| Validation | Joi |
| Security | Helmet, mongo-sanitize, express-rate-limit |

---

## Getting Started

### Prerequisites

- Node.js 18+
- MongoDB (local or Atlas)

### Installation

```bash
npm install
```

### Environment Setup

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

Key variables to configure:

```
PORT=5000
MONGODB_URI=mongodb://localhost:27017/djtrip
JWT_SECRET=your_jwt_secret
REFRESH_TOKEN_SECRET=your_refresh_secret
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
EMAIL_USER=your_email@example.com
EMAIL_PASS=your_email_password
CLIENT_URL=http://localhost:3000
```

### Running

```bash
# Development (with nodemon)
npm run dev

# Production
npm start
```

---

## API Routes

| Prefix | Description |
|---|---|
| `/api/v1/users` | User management & authentication (sign up, sign in, refresh token, profile) |
| `/api/v1/auth` | Email verification |
| `/api/v1/touristes` | Tourist profile management (complete profile, interests, language) |
| `/api/v1/organisators` | Organizer profile management (complete profile, business info) |
| `/api/v1/activites` | Activity CRUD (create, read, update, delete, search, archive) |
| `/api/v1/inscriptions` | Booking management (create, approve, reject, cancel, stats) |
| `/api/v1/avis` | Reviews & ratings (submit, fetch by organizer or activity) |
| `/api/v1/messages` | Messaging (conversations, send message, mark as read) |
| `/api/v1/lieux` | Places of interest (CRUD, top destinations, categories) |

---

## Features

- **JWT auth with refresh token rotation** — short-lived access tokens paired with rotating refresh tokens stored securely
- **Email verification** — new accounts must verify their email before accessing protected resources
- **Brute-force protection** — login attempts are rate-limited and tracked per IP
- **Rate limiting** — global and per-route rate limits via `express-rate-limit`
- **Cloudinary image storage** — activity photos and user avatars are uploaded directly to Cloudinary with automatic resizing
- **Real-time messaging via Socket.io** — live chat between tourists and organizers with online presence tracking
- **WebRTC call signaling** — Socket.io-based signaling layer for peer-to-peer audio/video calls

---

## Security

- **`helmet`** — sets secure HTTP headers on every response
- **`mongo-sanitize`** — strips `$` and `.` operators from user input to prevent NoSQL injection
- **Rate limiting** — configurable limits on auth endpoints to mitigate credential-stuffing attacks
- **Token versioning** — a `tokenVersion` field on each user allows instant invalidation of all issued tokens (e.g., on password change or logout-all)