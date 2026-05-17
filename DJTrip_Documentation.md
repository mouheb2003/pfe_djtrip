# DJTrip - Complete Documentation

## 1. 📌 Project Overview

**Project Name**: DJTrip - Djerba Trip Application

**Purpose**: Comprehensive tourism platform for Djerba island connecting tourists with local activity organizers.

**Problem Solved**: 
- Tourists: Difficulty finding authentic local activities
- Organizers: Challenge reaching tourists and managing bookings
- Platform: Centralized management of tourism activities

**Target Users**: Tourists, Activity Organizers, Platform Administrators

**Key Features**:
- Activity discovery and booking system
- Real-time messaging and video/audio calls
- Review and rating system
- Stripe payment processing
- QR code-based check-in system
- Social features (posts, comments, follows)
- Push notification system
- Admin dashboard for platform management
- Multi-language support
- Location-based services with maps

---

## 2. 👥 User Roles & Permissions

### Tourist
**Description**: Travelers who browse activities, make bookings, and share experiences.

**Permissions**:
- Browse all activities, book activities with payment
- View booking details, cancel bookings (within timeframe)
- Write reviews for activities and organizers
- Message organizers, make audio/video calls
- Follow other users, create posts and comments
- Manage profile and privacy settings

**Allowed Actions**: Search/filter activities, create bookings, make payments, rate/review, send messages, share posts, report issues

**Restricted Actions**: Cannot create activities, approve bookings, access admin features, view private user data, modify activities

### Organizer
**Description**: Local activity providers who create and manage experiences.

**Permissions**:
- Create and manage activities, edit details
- Approve/reject booking requests
- Verify bookings with QR code scanner
- Message tourists, make audio/video calls
- Respond to reviews, create posts/comments
- Manage profile and business information
- View booking analytics

**Allowed Actions**: Create activities with photos, set pricing/availability, approve/reject bookings, check-in tourists, communicate with tourists, track booking history

**Restricted Actions**: Cannot delete activities with active bookings, access other organizers' booking data, modify platform settings, view sensitive user data, access admin features

### Admin
**Description**: Platform administrators who manage users, resolve disputes, oversee operations.

**Permissions**:
- Full access to all platform features
- Manage all users (activate, suspend, ban)
- Review and handle appeals
- Monitor all activities and bookings
- Access system logs and analytics
- Manage payment disputes
- Delete inappropriate content
- Configure platform settings
- Send system-wide notifications

**Allowed Actions**: Suspend/ban users, approve/reject organizer applications, handle appeals, delete content, access all user data, view payment transactions, generate reports, configure system settings

**Restricted Actions**: Cannot modify user passwords, access payment processing credentials, delete audit logs

---

## 3. ✨ Features (DETAILED & USER-ORIENTED)

### 3.1 Activity Management

#### Create Activity (Organizer)
**Purpose**: Allow organizers to showcase experiences to tourists.

**Usage**:
1. Navigate to "Activities" tab
2. Tap "+" floating action button
3. Fill required info: title, description, type, location, duration, price, capacity, dates
4. Upload photos (1-10)
5. Add optional details: difficulty, equipment, what to bring
6. Tap "Create Activity"

**UI/UX**: Form validation, photo upload from gallery/camera, interactive map selection, preview card, success message.

**Related Files**: `Front/lib/screens/organizer/create_activity_screen.dart`, `Back/controllers/activite.js`

#### Edit Activity (Organizer)
**Purpose**: Keep activity information up-to-date.

**Usage**:
1. Navigate to "Activities" tab
2. Tap activity → options menu → "Edit Activity"
3. Modify desired fields
4. Tap "Save Changes"

**UI/UX**: Pre-filled form, immediate save, tourists see updates on refresh.

#### Delete Activity (Organizer)
**Purpose**: Remove outdated or cancelled activities.

**Usage**:
1. Navigate to "Activities" tab
2. Tap activity → options menu → "Delete Activity"
3. Provide cancellation reason (required)
4. Confirm deletion

**UI/UX**: Confirmation dialog, reason logged, activity hidden immediately, booked tourists notified.

### 3.2 Activity Discovery

#### Browse Activities (All Users)
**Purpose**: Help tourists find activities matching their interests.

**Usage**:
1. Open "Home" or "Explore"
2. Browse featured activities
3. Use search bar (name, location, type)
4. Apply filters: type, price range, date, rating
5. Tap activity card to view details

**UI/UX**: Beautiful card layout, real-time search, filter chips, pull-to-refresh, cards show photo/title/location/price/rating.

**Related Files**: `Front/lib/screens/tourist/tabs/home_tab.dart`, `Front/lib/screens/organizer/explore_activities_screen.dart`

#### Activity Details (All Users)
**Purpose**: Provide comprehensive details for booking decisions.

**Usage**:
1. Tap activity card
2. View: photo gallery, title/description, location with map, price, duration, capacity, languages, difficulty, equipment, organizer profile, reviews
3. Tap "Book Now" to proceed

**UI/UX**: Full-screen gallery, map integration, organizer profile with rating, reviews section, smooth animations, prominent "Book Now" button.

### 3.3 Booking System

#### Book Activity (Tourist)
**Purpose**: Enable tourists to reserve spots in activities.

**Usage**:
1. View activity details
2. Tap "Book Now"
3. Select participants and date
4. Add optional message to organizer
5. Review summary
6. Tap "Proceed to Payment"
7. Complete payment via Stripe
8. Receive booking confirmation

**UI/UX**: Date picker with available dates, dynamic price updates, secure Stripe integration, loading states, success screen, push notification to organizer.

**Related Files**: `Front/lib/screens/tourist/booking_confirmation_screen.dart`, `Back/controllers/inscription.js`, `Back/controllers/payment.js`

#### Approve Booking (Organizer)
**Purpose**: Confirm tourist participation and generate QR code.

**Usage**:
1. Navigate to "Activities" tab
2. Tap "Verify Booking"
3. Scan tourist's QR code or enter booking ID
4. Review details
5. Tap "Approve"
6. QR code generated for tourist

**UI/UX**: QR scanner, booking details display, approval generates unique QR token, tourist receives notification.

**Related Files**: `Front/lib/screens/organizer/verify_booking_screen.dart`

#### Cancel Booking (Tourist)
**Purpose**: Allow flexibility for tourists while protecting organizers.

**Usage**:
1. Navigate to "Bookings" tab
2. Tap booking → "Cancel Booking"
3. Select cancellation reason
4. Confirm
5. Receive refund confirmation

**UI/UX**: Cancellation policy displayed, refund calculated automatically, confirmation dialog, refund processed via Stripe, organizer notified.

#### Check-in System (Organizer Scan, Tourist Display)
**Purpose**: Secure and efficient check-in process.

**Usage (Organizer)**:
1. Open "Verify Booking"
2. Point camera at tourist's QR code
3. System validates booking
4. If valid: mark as checked-in
5. If invalid: show error reason

**Usage (Tourist)**:
1. Open booking details
2. Display QR code
3. Show to organizer
4. Wait for scan confirmation

**UI/UX**: Fast QR scanning (< 2s), visual feedback, offline mode support, audit log, prevents duplicate check-ins.

**Related Files**: `Front/lib/screens/organizer/verify_booking_screen.dart`, `Back/models/checkinLog.js`

### 3.4 Communication

#### Real-time Messaging (All Users)
**Purpose**: Enable direct communication between tourists and organizers.

**Usage**:
1. Tap user profile or booking
2. Select "Send Message"
3. Type message in text field
4. Tap send
5. Message appears instantly

**UI/UX**: Real-time delivery via Socket.io, typing indicators, read receipts, timestamps, image/audio message support, conversation list with unread badges.

**Related Files**: `Front/lib/services/message_service.dart`, `Back/controllers/message.js`

#### Audio/Video Calls (All Users)
**Purpose**: Provide more personal communication option.

**Usage**:
1. Open chat with desired user
2. Tap phone icon (voice) or camera icon (video)
3. Wait for recipient to answer
4. During call: mute/unmute, toggle camera, switch camera, end call
5. Call history saved

**UI/UX**: Incoming call screen, high-quality audio/video, connection status, call duration timer, smooth termination.

**Related Files**: `Front/lib/services/call_service.dart`

### 3.5 Reviews & Ratings

#### Write Review (Tourist)
**Purpose**: Help other tourists make informed decisions and provide feedback.

**Usage**:
1. After check-in, review prompt appears
2. Tap "Write Review"
3. Select star rating (1-5)
4. Write text review (optional, max 1000 chars)
5. Add tags (optional, max 3)
6. Submit

**UI/UX**: Only available after completion, star rating required, prompt appears 24h after check-in, reviews appear on activity page, organizer notified, cannot review same activity twice.

**Related Files**: `Front/lib/services/review_service.dart`, `Back/controllers/avis.js`

#### View Reviews (All Users)
**Purpose**: Provide social proof and help with decision-making.

**Usage**:
1. Open activity or organizer profile
2. Scroll to reviews section
3. Read reviews with: star rating, text, tourist name, date, tags
4. Filter by rating if desired

**UI/UX**: Sorted by most recent, average rating prominent, rating breakdown, helpful voting, report inappropriate reviews.

### 3.6 Social Features

#### Posts & Feed (All Users)
**Purpose**: Build community and share travel experiences.

**Usage**:
1. Navigate to "Network" tab
2. Tap "+" to create post
3. Add: text (optional, max 1500 chars), photos (up to 10), location tag, hashtags
4. Select audience (public/followers only)
5. Tap "Post"

**UI/UX**: Feed shows posts from followed users, like/comment/share reactions, bookmark posts, image carousel, clickable hashtags, location links to map.

**Related Files**: `Front/lib/screens/shared/feed_screen.dart`, `Back/controllers/post.js`

#### Comments (All Users)
**Purpose**: Enable discussions and engagement.

**Usage**:
1. Tap on a post
2. Scroll to comments section
3. Tap "Add a comment"
4. Type and post
5. To reply: tap "Reply" on a comment

**UI/UX**: Comments load in pages (10 at a time), replies load on-demand, real-time updates, like reactions, delete own comments, nested replies (1 level deep).

**Related Files**: `Front/lib/screens/shared/comments_screen.dart`, `Back/controllers/comment.js`

#### Follow System (All Users)
**Purpose**: Build social connections and discover content.

**Usage**:
1. View user profile
2. Tap "Follow"
3. Button changes to "Following"
4. User's posts appear in feed
5. To unfollow: tap "Following" → "Unfollow"

**UI/UX**: Follower/following counts, notification on follow, lists on profile, can follow tourists/organizers.

**Related Files**: `Front/lib/services/follow_service.dart`, `Back/controllers/follow.js`

### 3.7 Notifications

#### Push Notifications (All Users)
**Purpose**: Keep users informed without opening the app.

**Usage**:
1. Enable notifications in app settings
2. Grant permission when prompted
3. Receive notifications for: booking confirmations, approvals, new messages, new followers, review reminders, activity updates
4. Tap notification to open relevant screen

**UI/UX**: Notification badge on app icon, notification center in app, mark as read with swipe, filter by type, quiet hours, customizable preferences.

**Related Files**: `Front/lib/services/fcm_notification_service.dart`, `Back/services/notificationServiceV2.js`

#### In-App Notifications (All Users)
**Purpose**: Provide history of all notifications and easy access to actions.

**Usage**:
1. Tap bell icon in navigation bar
2. View all notifications
3. Tap notification to view details
4. Swipe to mark as read
5. Tap "Mark all as read"

**UI/UX**: Grouped by date, unread indicator, action buttons, delete individual notifications, pull-to-refresh.

**Related Files**: `Front/lib/screens/notifications_screen.dart`

### 3.8 Payment System

#### Secure Payments (Tourist)
**Purpose**: Enable safe and reliable payment processing.

**Usage**:
1. Select activity and participants
2. Tap "Proceed to Payment"
3. Redirect to Stripe checkout
4. Enter card details or use saved card
5. Complete payment
6. Redirect back with confirmation

**UI/UX**: Secure HTTPS, multiple payment methods (cards, Apple Pay, Google Pay), confirmation screen, email receipt, invoice generated, refund processing available.

**Related Files**: `Front/lib/services/payment_service.dart`, `Back/controllers/payment.js`

#### Refunds (Admin Manual, System Automatic)
**Purpose**: Fair refund policy for tourists.

**Usage (Automatic)**:
1. Tourist cancels within refund period
2. System processes refund automatically
3. Refund credited to original payment method
4. Email confirmation sent

**Usage (Manual by Admin)**:
1. Admin navigates to booking details
2. Selects "Process Refund"
3. Enters refund amount
4. Confirms
5. Stripe processes refund

**UI/UX**: Refund status tracked, partial refunds supported, timeline 5-10 business days, notification to both parties.

### 3.9 Profile Management

#### User Profile (All Users)
**Purpose**: Present user information to others and manage account.

**Usage**:
1. Navigate to "Profile" tab
2. View: photo, name, bio, contact info, statistics
3. Tap "Edit Profile"
4. Update desired fields
5. Save

**UI/UX**: Profile photo upload, cover photo support, privacy settings for contact info, real-time preview, validation.

**Related Files**: `Front/lib/screens/shared/public_profile_screen.dart`, `Back/controllers/user.js`

#### Privacy Settings (All Users)
**Purpose**: Control what information is visible to others.

**Usage**:
1. Navigate to "Settings" → "Privacy"
2. Toggle: profile visibility, online status, last seen, direct messages, phone/email, phone calls, location sharing
3. Save

**UI/UX**: Toggle switches, descriptions, immediate application, some require confirmation.

### 3.10 Admin Features

#### User Management (Admin)
**Purpose**: Maintain platform safety and enforce rules.

**Usage**:
1. Navigate to admin dashboard → "Users"
2. View user list with filters
3. Tap user to view details
4. Select action: activate, suspend (with duration/reason), ban (permanent), view history
5. Confirm

**UI/UX**: User table with search/filters, status indicators, confirmation dialogs, audit log, bulk actions.

**Related Files**: `dashbord/src/pages/dashboard/user-list.jsx`, `Back/controllers/user.js`

#### Appeal System (All Users Submit, Admin Review)
**Purpose**: Provide fair process for account restrictions.

**Usage (User)**:
1. Upon suspension, tap "Appeal"
2. Select type: Ban Appeal, Suspension Appeal, Reclamation, Other
3. Write message (max 2000 chars)
4. Add optional attachments
5. Submit
6. Wait for response

**Usage (Admin)**:
1. Navigate to "Appeals"
2. View pending appeals
3. Review details and user history
4. Select: accept (restore) or reject (keep restriction)
5. Add response message
6. Submit decision

**UI/UX**: Status tracking, notification on decision, history visible, admin can request additional info.

**Related Files**: `Front/lib/services/appeal_service.dart`, `Back/controllers/appeal.js`

#### Activity Moderation (Admin)
**Purpose**: Ensure content quality and policy compliance.

**Usage**:
1. Navigate to "Activities" in admin dashboard
2. View activity list
3. Filter by status or reports
4. Review details
5. Take action: flag, hide, delete, contact organizer

**UI/UX**: Activity cards with key info, report indicators, bulk moderation tools, moderation history.

---

## 4. 🧭 Complete User Guide (STEP-BY-STEP)

### 4.1 Account Creation

#### Tourist Registration
1. Download and install DJTrip app
2. Open app → "Sign Up"
3. Choose method: email/password, Google, or Facebook
4. Fill: name, email, password, phone
5. Verify email (check inbox for code)
6. Complete onboarding: interests, language, notifications
7. Start exploring activities

#### Organizer Registration
1. Follow steps 1-5 from tourist registration
2. Select "I want to be an Organizer" during onboarding
3. Provide: business name, specialties, languages, reason for joining
4. Submit for approval
5. Wait for admin approval (usually 24h)
6. Once approved, create first activity

#### Login
1. Open app → "Sign In"
2. Enter credentials or use social login
3. Dashboard opens based on role

#### Password Recovery
1. On sign-in screen → "Forgot Password?"
2. Enter email
3. Check email for reset code
4. Enter code in app
5. Create new password
6. Sign in

### 4.2 Navigation Overview

#### Tourist Navigation (5 tabs)
- **Home**: Discover activities, featured experiences
- **Explore**: Browse all activities with filters
- **Bookings**: View bookings and status
- **Messages**: Chat with organizers
- **Profile**: Manage account and settings

#### Organizer Navigation (5 tabs)
- **Activities**: Manage activities (Active, Ongoing, Completed)
- **Explore**: Browse marketplace (read-only)
- **Network**: Social feed and connections
- **Messages**: Chat with tourists
- **Profile**: Manage profile and settings

#### Admin Dashboard (Sidebar)
- **Dashboard**: Overview and statistics
- **Users**: User management
- **Activities**: Activity moderation
- **Bookings**: Booking overview
- **Appeals**: Handle appeals
- **Payments**: Payment transactions
- **Reports**: Content reports
- **Settings**: Platform configuration
- **Logs**: System logs

### 4.3 Performing Main Actions

#### Booking an Activity (Tourist)
1. **Find**: Browse Home or Explore, use search/filters
2. **View**: Tap card, review photos/description/pricing/rating
3. **Book**: Tap "Book Now", select participants/date, add message
4. **Pay**: Tap "Proceed to Payment", complete Stripe payment
5. **Confirm**: Receive confirmation with QR code
6. **Attend**: Show QR code to organizer, get checked in
7. **Review**: Rate activity after completion

#### Creating an Activity (Organizer)
1. Navigate to "Activities" tab
2. Tap "+" button
3. Fill: title, description, type, location, duration, price, capacity, languages, dates
4. Upload photos (1-10)
5. Add optional: difficulty, equipment, what to bring
6. Review preview
7. Tap "Create Activity"

#### Managing Bookings (Organizer)
1. Navigate to "Activities" → "Verify Booking"
2. View pending bookings
3. Scan tourist's QR code or enter booking ID
4. Review details
5. Tap "Approve" to generate QR code
6. At activity: scan each tourist's QR code for check-in

#### Messaging
1. Start: From activity page "Message Organizer", profile "Send Message", or booking "Contact"
2. Send: Type message, tap send
3. Send media: Tap attachment, select photo/audio/video
4. Call: In chat, tap phone (voice) or camera (video) icon
5. Manage: View all conversations in Messages tab, unread badges, swipe to archive/delete

### 4.4 Real Usage Scenarios

#### Scenario 1: Tourist Planning a Trip
Sarah downloads app → creates account → selects interests → browses "Guided Tour of Djerba Heritage" → views details → books for 2 participants → pays $60 → receives QR code → attends tour → gets checked in → rates 5 stars with review.

#### Scenario 2: Organizer Managing Business
Ahmed creates organizer account → submits business details → approved → creates "Sunset Camel Trek" ($30, 10 capacity, 3 hours) → uploads photos → activity goes live → receives first booking → approves → checks in 8 tourists → receives 5-star review → creates second activity.

#### Scenario 3: Admin Handling Dispute
Admin receives report → logs into dashboard → navigates to Activities → searches reported activity → reviews content → determines violation → contacts organizer with warning → organizer removes content → admin reinstates → logs action.

### 4.5 Tips for Better Usage

**For Tourists**: Book early, read reviews, message organizer before booking, check location on map, arrive on time, write reviews, enable notifications, save favorites.

**For Organizers**: Use great photos, detailed descriptions, competitive pricing, quick responses, professional check-in, ask for reviews, update availability, respond to feedback.

**For Admin**: Review reports daily, be fair, document actions, communicate clearly, monitor trends, support users.

---

## 5. 🏗️ System Architecture (DEVELOPER SECTION)

### Global Architecture
Three-tier architecture:
- **Client Layer**: Flutter Mobile App, React Admin Dashboard
- **Application Layer**: Node.js/Express Server with REST API, Socket.io, Middleware
- **Data Layer**: MongoDB Atlas with Mongoose ODM
- **External Services**: Cloudinary (images), Stripe (payments), Firebase (push), Google/Facebook (OAuth), Redis (queues)

### Technologies Used

#### Backend
- Node.js v20.x, Express.js v5.2.1
- MongoDB with Mongoose v9.2.2
- JWT authentication, Socket.io v4.8.3
- Multer + Cloudinary (uploads)
- Nodemailer v8.0.1 (email)
- Stripe v22.0.2 (payments)
- BullMQ v5.73.4 + Redis (queues)
- Firebase Admin v13.8.0 (push)
- Helmet, express-rate-limit (security)
- Joi v18.0.2 (validation)
- Winston v3.19.0 (logging)

#### Frontend
- Flutter SDK 3.11.0, Dart 3.11.0
- Provider v6.1.1 (state)
- HTTP v1.2.0, Socket.io Client v2.0.3+1
- flutter_webrtc v1.0.0 (calls)
- google_maps_flutter v2.5.3, geocoding v3.0.0
- shared_preferences v2.2.2, Hive v2.2.3 (storage)
- google_sign_in v6.2.2, flutter_facebook_auth v7.1.5
- cached_network_image v3.3.1, image_picker v1.0.7
- mobile_scanner v5.1.0 (QR)
- firebase_messaging v14.6.0 (push)

#### Admin Dashboard
- React v18.3.1, Vite v6.0.3
- Material-UI v6.1.10, Ant Design v6.3.5
- React Router v7.14.1
- Axios v1.7.9
- React Hook Form v7.53.2
- dayjs v1.11.13

### Design Patterns
- **Repository Pattern**: Services abstract data access
- **Service Layer Pattern**: Business logic separated from controllers
- **Middleware Pattern**: Cross-cutting concerns (auth, rate limit, error handling)
- **Observer Pattern**: Socket.io event-driven real-time updates
- **Factory Pattern**: Model discriminators for user types

### Data Flow

#### Authentication Flow
Client → POST /signin → Server validates → Generate JWT (2h) + refresh token (7d) → Return tokens → Client stores → Include in Authorization header → Verify on each request → Refresh if expired

#### Booking Flow
Tourist browses → Taps "Book Now" → Create Stripe payment intent → Redirect to checkout → Complete payment → Stripe webhook → Verify payment → Create Inscription (PAID_PENDING_CONFIRMATION) → Notify organizer → Organizer approves → Generate QR token → Update to "approuvee" → Notify tourist

#### Real-time Messaging Flow
User A sends message → Emit 'send_message' via Socket.io → Server validates and saves → Emit 'new_message' to User B's room → User B receives instantly → Updates UI → User B marks read → Emit 'mark_read' → Server updates → Emit 'messages_read' to User A

#### Activity Timeline Flow
Server calculates status: UPCOMING (startDate > NOW), ONGOING (startDate <= NOW AND endDate >= NOW), PAST (endDate < NOW) → Return with status → Client filters by tabs → Update badges in real-time

---

## 6. 📁 Project Structure

### Root Directory
```
DJTrip/
├── DJTrip_Documentation.md  # Main Documentation
├── DJTrip_Interface_Catalog.md # Detailed UI/Component Catalog
├── AI_CHATBOT_INTEGRATION_GUIDE.md # AI System & Integration Guide
├── Back/                    # Backend API (Node.js/Express)
├── Front/                   # Mobile App (Flutter)
├── dashbord/                # Admin Dashboard (React/Vite)
├── documentation/           # Existing documentation
├── logs/                    # Application logs
├── node_modules/            # Backend dependencies
└── uploads/                 # Uploaded files
```

### 🎨 Visual & Interface Guide
For a detailed list of all screens, buttons, and icons, please refer to the [Interface & Component Catalog](DJTrip_Interface_Catalog.md).

### Backend (Back/)
```
Back/
├── config/                  # Database, Cloudinary, BullMQ config
├── controllers/             # 22 controllers (activite, inscription, user, etc.)
├── models/                  # 20 models (user, activite, inscription, etc.)
├── routes/                  # 24 route files
├── services/                # 25 services (cache, email, notification, etc.)
├── middleware/              # 16 middleware (auth, rate limit, etc.)
├── validators/              # 7 validators
├── jobs/                    # Scheduled jobs (payment expiration, reminders)
├── workers/                 # 5 background workers
├── queues/                  # Queue definitions
├── websocket/               # Socket.io setup
├── scripts/                 # Utility scripts (seed-admin)
├── .env                     # Environment variables
├── server.js                # Entry point
└── package.json
```

### Frontend (Front/)
```
Front/
├── lib/
│   ├── main.dart           # App entry
│   ├── api/                # API client
│   ├── base/               # Base classes
│   ├── config/             # Configuration
│   ├── models/             # 12 data models
│   ├── services/           # 37 API services
│   ├── screens/            # 105+ screens
│   │   ├── auth/           # Authentication
│   │   ├── tourist/        # Tourist screens (24)
│   │   ├── organizer/      # Organizer screens (17)
│   │   ├── shared/         # Shared screens (28)
│   │   ├── settings/       # Settings (11)
│   │   └── onboarding/     # Onboarding (9)
│   ├── widgets/            # 10 reusable widgets
│   ├── providers/          # State providers
│   ├── theme/              # App theme
│   └── utils/              # Utility functions
├── assets/                 # Logos, sounds
└── pubspec.yaml
```

### Admin Dashboard (dashbord/)
```
dashbord/
├── src/
│   ├── main.jsx            # Entry
│   ├── auth/               # Authentication
│   ├── pages/              # 23 pages (dashboard, user-list, etc.)
│   ├── components/         # 285 components
│   ├── layouts/            # 40 layouts
│   ├── routes/             # 11 route files
│   ├── services/           # 4 API services
│   └── theme/              # 66 theme files
├── public/                 # Assets
└── package.json
```

### Important Components
**Backend**: server.js, config/db.js, middleware/auth.js, services/cache.js, controllers/inscription.js, controllers/activite.js

**Frontend**: lib/main.dart, lib/services/api_service.dart, lib/screens/tourist/tourist_main_screen.dart, lib/screens/organizer/organizer_main_screen.dart, lib/models/activity_model.dart

**Admin**: src/main.jsx, src/pages/dashboard/user-list.jsx

---

## 7. ⚙️ Installation & Setup

### Requirements
**Backend**: Node.js v20.x, MongoDB, Redis, npm/yarn

**Frontend**: Flutter SDK 3.11.0, Dart 3.11.0, Android Studio/Xcode, CocoaPods

**Admin Dashboard**: Node.js v20.x, npm/yarn

**External Services**: Cloudinary, Stripe, Firebase, Google Cloud, Facebook Developer

### Installation Steps

#### 1. Clone Repository
```bash
git clone https://github.com/your-repo/DJTrip.git
cd DJTrip
```

#### 2. Backend Setup
```bash
cd Back
npm install
cp .env.example .env
# Edit .env with your values
npm run seed:admin  # Seed admin user
npm run dev         # Start development server
```

#### 3. Frontend Setup
```bash
cd Front
flutter pub get
# Edit lib/config/app_config.dart with API URL
flutter run
```

#### 4. Admin Dashboard Setup
```bash
cd dashbord
npm install
# Create .env with VITE_API_BASE_URL
npm run dev
```

#### 5. Verify Installation
```bash
# Backend health check
curl http://localhost:3000/api/health
```

### Environment Variables

**Backend (.env)**:
- PORT, NODE_ENV, MONGODB_URI
- JWT_SECRET, REFRESH_TOKEN_SECRET
- CLOUD_NAME, API_KEY, API_SECRET
- EMAIL_USER, EMAIL_PASSWORD
- GOOGLE_CLIENT_ID
- FIREBASE_KEY_BASE64
- REDIS_HOST, REDIS_PORT
- STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
- GEMINI_API_KEY, STABILITY_API_KEY

**Frontend (lib/config/app_config.dart)**:
- apiBaseUrl, stripePublishableKey

**Admin Dashboard (.env)**:
- VITE_API_BASE_URL

---

## 8. 🚀 Usage (Technical)

### Commands

**Backend**:
```bash
npm start              # Production
npm run dev            # Development with nodemon
npm run seed:admin     # Seed admin
```

**Frontend**:
```bash
flutter run            # Debug mode
flutter build apk      # Android APK
flutter build ios      # iOS app
flutter clean          # Clean artifacts
flutter pub get        # Install dependencies
```

**Admin Dashboard**:
```bash
npm run dev            # Development
npm run build          # Production build
npm start              # Preview production
```

### Development vs Production

**Backend**: Development allows all CORS, detailed logging, hot reload. Production restricts CORS, minimal logging, PM2 process management.

**Frontend**: Debug mode with hot reload, detailed errors. Release build optimized, obfuscated code.

**Admin Dashboard**: Vite dev server with HMR, source maps. Production build optimized, minified.

---

## 9. 🔌 API Documentation

### Base URL
- Development: `http://localhost:3000/api/v1`
- Production: `https://your-domain.com/api/v1`

### Authentication
Include JWT token in Authorization header:
```
Authorization: Bearer <access_token>
```

Refresh token:
```
POST /api/v1/auth/refresh
```

### Key Endpoints

#### Authentication
- POST /api/v1/users/signup - Register user
- POST /api/v1/users/signin - Login
- POST /api/v1/auth/refresh - Refresh token
- POST /api/v1/users/forgot-password - Request reset
- POST /api/v1/users/reset-password - Reset password

#### Users
- GET /api/v1/users/:id - Get user profile
- PUT /api/v1/users/:id - Update profile
- GET /api/v1/users/me - Get current user
- PUT /api/v1/users/me - Update current user

#### Activities
- GET /api/v1/activites - Get all activities
- GET /api/v1/activites/:id - Get activity details
- POST /api/v1/activites - Create activity (organizer)
- PUT /api/v1/activites/:id - Update activity (organizer)
- DELETE /api/v1/activites/:id - Delete activity (organizer)
- GET /api/v1/activites/timeline - Get activities by timeline status

#### Bookings (Inscriptions)
- GET /api/v1/inscriptions - Get user bookings
- POST /api/v1/inscriptions - Create booking
- GET /api/v1/inscriptions/:id - Get booking details
- PUT /api/v1/inscriptions/:id/approve - Approve booking (organizer)
- PUT /api/v1/inscriptions/:id/cancel - Cancel booking
- GET /api/v1/inscriptions/organizer - Get organizer bookings

#### Messages
- GET /api/v1/messages - Get conversations
- GET /api/v1/messages/:userId - Get conversation with user
- POST /api/v1/messages - Send message
- PUT /api/v1/messages/:id/read - Mark as read

#### Reviews (Avis)
- GET /api/v1/avis - Get reviews
- POST /api/v1/avis - Create review
- GET /api/v1/avis/activite/:id - Get activity reviews
- GET /api/v1/avis/organisateur/:id - Get organizer reviews

#### Payments
- POST /api/payments/create-checkout-session - Create Stripe session
- POST /api/payments/webhook - Stripe webhook
- GET /api/payments/:id - Get payment details
- POST /api/payments/:id/refund - Process refund

#### Posts
- GET /api/v1/posts - Get feed
- POST /api/v1/posts - Create post
- GET /api/v1/posts/:id - Get post details
- PUT /api/v1/posts/:id - Update post
- DELETE /api/v1/posts/:id - Delete post
- POST /api/v1/posts/:id/like - Like post
- DELETE /api/v1/posts/:id/like - Unlike post

#### Comments
- GET /api/v1/comments/:postId - Get post comments
- POST /api/v1/comments - Create comment
- GET /api/v1/comments/:id/replies - Get replies
- DELETE /api/v1/comments/:id - Delete comment

#### Notifications
- GET /api/v1/notifications - Get user notifications
- PUT /api/v1/notifications/:id/read - Mark as read
- PUT /api/v1/notifications/read-all - Mark all as read

#### Appeals
- GET /api/v1/appeals - Get user appeals
- POST /api/v1/appeals - Submit appeal
- GET /api/v1/appeals/admin - Get all appeals (admin)
- PUT /api/v1/appeals/:id/status - Update appeal status (admin)

### Response Format
Success:
```json
{
  "success": true,
  "data": { ... }
}
```

Error:
```json
{
  "success": false,
  "message": "Error message",
  "error": "Detailed error"
}
```

---

## 10. 🗃️ Database Documentation

### Collections (MongoDB)

#### users
Base user collection with discriminators for touriste and organisator.

**Fields**:
- _id, fullname, email, mot_de_passe, age, num_tel
- avatar, cover_photo, bio, pays_origine
- langue_preferee, centres_interet, pays_telephone
- profileVisibility, showOnlineStatus, showLastSeen
- allowDirectMessages, showPhone, showEmail
- allowPhoneCalls, allowLocationSharing
- blockedUsers, isOnline, accountStatus
- suspendedUntil, suspendReason, suspendedAt
- banReason, bannedAt, derniere_connexion
- notifications_email, notifications_sms
- emailVerified, verificationCode, verificationCodeExpiry
- googleId, facebookId, passwordResetCode
- loginAttempts, lockUntil, tokenVersion
- wallet_balance, favorites
- archivedConversationPartners, deletedConversationPartners
- mutedConversationPartners, fcmTokens
- specialites_activites, langues_proposees
- reasonToJoin, is_onboarded, is_approved
- signup_method, profile_completed, onboarding_step

**Indexes**: accountStatus, userType, createdAt, favorites, is_onboarded, is_approved

#### activites
Activity listings with location types (fixed, custom, itinerary).

**Fields**:
- _id, titre, description, type_activite, categorie
- organisateur_id, lieu, coordonnees (lat/lng)
- location_type, itineraire (array of stops)
- duree, prix, capacite_max
- langues_disponibles, photos
- niveau_difficulte, equipements_inclus, a_apporter
- dates_disponibles, date_debut, date_fin
- statut (active/inactive/archived/completed)
- note_moyenne, nombre_avis, nombre_reservations
- bookmarked_by, bookmarks_count

**Indexes**: organisateur_id, text search (lieu/titre/description), geospatial (coordinates)

#### inscriptions
Bookings linking tourists to activities.

**Fields**:
- _id, touriste_id, activite_id, organisateur_id
- statut (approuvee/annulee/verifie/PAID_PENDING_CONFIRMATION)
- payment_id, nombre_participants
- message_touriste, message_organisateur
- date_demande, date_reponse, prix_total
- qr_token, qr_token_generated_at, qr_token_expires_at, qr_used_at
- hasReviewed, reviewDate, reviewReminder, bookingReminder

**Indexes**: touriste_id+statut, activite_id+statut, organisateur_id+statut, qr_token

#### avis
Reviews and ratings for activities and organizers.

**Fields**:
- _id, touriste_id, activite_id, organisateur_id
- type (activite/organisateur), note (1-5)
- commentaire, tags (max 3), inscription_id

**Indexes**: Unique on touriste_id+activite_id, touriste_id+organisateur_id

#### messages
Real-time messages between users.

**Fields**:
- _id, sender_id, receiver_id, content
- message_type (text/image/audio/video/warning)
- media_url, media_duration
- is_read, read_at, is_edited, edited_at

**Indexes**: sender_id+receiver_id+createdAt, receiver_id+is_read

#### notifications
Push and in-app notifications.

**Fields**:
- _id, user_id, type, title, message, data
- is_read, priority, action_url, action_text
- expires_at, related_entity_type, related_entity_id
- target_role (tourist/organizer/admin/all)

**Indexes**: user_id+is_read+createdAt, type+createdAt, target_role+createdAt, expires_at

#### posts
Social media posts.

**Fields**:
- _id, author_id, content, image_url, image_urls
- post_type (post/activity), audience (public/followers)
- location_label, trip_link, hashtags
- likes_count, liked_by, reactions, total_reactions
- comments_count, bookmarked_by, bookmarks_count
- is_active

**Indexes**: createdAt, author_id+createdAt

#### comments
Comments on posts with nested replies.

**Fields**:
- _id, post_id, author_id, content
- parent_comment_id, is_active
- likes_count, liked_by, reactions

**Indexes**: post_id+is_active, parent_comment_id

#### payments
Stripe payment transactions.

**Fields**:
- _id, stripe_session_id, stripe_payment_intent_id
- token, order_id, user_id, inscription_id
- activity_id, activity_title, nombre_participants
- amount, currency, description, status
- payment_url, success_url, cancel_url
- webhook_response, payment_method
- paid_at, failed_at, refunded_at

**Indexes**: stripe_session_id, order_id, user_id+status, inscription_id

#### appeals
Account suspension/ban appeals.

**Fields**:
- _id, user_id, subject, message
- status (pending/reviewed/accepted/rejected)
- admin_response, admin_id, attachments
- metadata (account_status, original_reason, ip, user_agent)

**Indexes**: user_id+createdAt, status+createdAt

#### checkinLogs
Check-in audit trail.

**Fields**:
- _id, bookingId, organiserId, touristId, activityId
- status (success/failed/already_verified/unauthorized/expired/not_approved)
- failureReason, qrData, ipAddress, userAgent
- location (coordinates), timestamp, duration

**Indexes**: timestamp+status, organiserId+timestamp, activityId+timestamp

#### follow
User following relationships.

**Fields**:
- _id, follower_id, following_id

**Indexes**: Unique on follower_id+following_id

### Relationships
- User (touriste/organisator) → Activities (organisateur_id)
- User (touriste) → Inscriptions (touriste_id)
- Activity → Inscriptions (activite_id)
- Inscription → Payment (payment_id)
- User → Messages (sender_id/receiver_id)
- User → Posts (author_id)
- Post → Comments (post_id)
- Comment → Comments (parent_comment_id)
- User → Reviews (touriste_id)
- Activity → Reviews (activite_id)
- User → Notifications (user_id)
- User → Appeals (user_id)

---

## 11. 🧠 Core Logic & Algorithms

### Activity Timeline Status
```javascript
// Backend (activite.js controller)
if (activity.date_debut > now) {
  status = 'UPCOMING';
} else if (activity.date_debut <= now && activity.date_fin >= now) {
  status = 'ONGOING';
} else {
  status = 'PAST';
}
```

### Booking Status Flow
```
PAID_PENDING_CONFIRMATION (after payment)
  ↓ Organizer approves
approuvee (approved)
  ↓ Check-in
verifie (verified/used)
  ↓ Tourist cancels
annulee (cancelled)
```

### QR Token Generation
```javascript
// Generate unique signed token
const qrToken = jwt.sign(
  { bookingId: inscription._id, activityId: inscription.activite_id },
  JWT_SECRET,
  { expiresIn: activity.date_fin }
);
```

### Check-in Validation
```javascript
// Validate QR token
const decoded = jwt.verify(qrToken, JWT_SECRET);
const booking = await Inscription.findById(decoded.bookingId);
if (booking.statut !== 'approuvee') {
  return { valid: false, reason: 'Booking not approved' };
}
if (booking.qr_used_at) {
  return { valid: false, reason: 'Already checked in' };
}
if (new Date() > booking.qr_token_expires_at) {
  return { valid: false, reason: 'QR token expired' };
}
```

### Comment Pagination & Lazy Loading
```javascript
// Backend: Return only root comments
const comments = await Comment.find({
  post_id: postId,
  parent_comment_id: null,
  is_active: true
})
.skip((page - 1) * limit)
.limit(limit)
.sort({ createdAt: -1 });

// Frontend: Load replies on demand
void _loadReplies(String commentId) async {
  final replies = await PostService.getCommentReplies(commentId);
  setState(() {
    _repliesMap[commentId] = replies;
  });
}
```

### Notification Priority Queue
```javascript
// BullMQ worker processes notifications by priority
const processor = async (job) => {
  const { userId, type, title, message, data } = job.data;
  await Notification.createNotification({ userId, type, title, message, data });
  await notificationService.sendPushNotification({ userId, title, body: message, data });
};

// High priority notifications processed first
queue.add('notification', data, { priority: jobPriority });
```

### Payment Refund Calculation
```javascript
// Calculate refund based on cancellation policy
const hoursBeforeActivity = (activity.date_debut - now) / (1000 * 60 * 60);
let refundPercentage = 0;

if (hoursBeforeActivity >= 48) {
  refundPercentage = 100; // Full refund
} else if (hoursBeforeActivity >= 24) {
  refundPercentage = 50; // Half refund
} else {
  refundPercentage = 0; // No refund
}

const refundAmount = booking.prix_total * (refundPercentage / 100);
```

### Real-time Messaging (Socket.io)
```javascript
// Backend: Handle message emission
socket.on('send_message', async (data) => {
  const message = await Message.create(data);
  const receiverRoom = `user_${data.receiver_id}`;
  io.to(receiverRoom).emit('new_message', message);
  
  // Also send push notification if receiver is offline
  if (!isUserOnline(data.receiver_id)) {
    notificationService.sendPush(data.receiver_id, 'New Message', data.content);
  }
});
```

### AI Model Fallback Logic
```javascript
// Backend: tryModels (aiText.js)
const tryModels = async (prompt, models) => {
  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      return result.response.text();
    } catch (error) {
      console.warn(`Model ${modelName} failed, trying next...`);
      if (error.status === 403) throw error; // Stop if API key is leaked
    }
  }
  throw new Error("All AI models failed.");
};
```

---

## 12. 🧪 Testing

### How to Test the App

#### Backend Testing
```bash
cd Back
npm test  # Run test suite (if configured)
```

Manual API testing with curl/Postman:
```bash
# Health check
curl http://localhost:3000/api/health

# Register user
curl -X POST http://localhost:3000/api/v1/users/signup \
  -H "Content-Type: application/json" \
  -d '{"fullname":"Test","email":"test@example.com","mot_de_passe":"Test123!","userType":"touriste"}'

# Login
curl -X POST http://localhost:3000/api/v1/users/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","mot_de_passe":"Test123!"}'
```

#### Frontend Testing
```bash
cd Front
flutter test  # Run unit tests
flutter drive --target=test_driver/app.dart  # Integration tests
```

#### Admin Dashboard Testing
```bash
cd dashbord
npm test  # Run test suite (if configured)
```

### Example Test Cases

#### Booking Flow Test
1. Tourist creates account
2. Tourist browses activities
3. Tourist books activity
4. Tourist completes payment
5. Organizer receives notification
6. Organizer approves booking
7. QR code generated
8. Tourist receives confirmation
9. Tourist attends activity
10. Organizer scans QR code
11. Check-in successful
12. Tourist writes review

#### Real-time Messaging Test
1. User A sends message to User B
2. User B receives notification
3. User B opens chat
4. User B sees message
5. User B replies
6. User A sees reply
7. Both see typing indicators
8. Both see read receipts

#### Check-in System Test
1. Create booking with approval
2. Generate QR code
3. Scan valid QR code → success
4. Scan same QR code again → fail (already checked in)
5. Scan invalid QR code → fail
6. Scan expired QR code → fail
7. Check audit log

---

## 13. ⚠️ Limitations & Known Issues

### Current Limitations
1. **Offline Mode**: Limited offline functionality for organizers (check-in only)
2. **Video Call Quality**: Depends on network conditions
3. **Payment Currencies**: Currently limited to USD/EUR (TND support planned)
4. **Multi-language**: UI supports multiple languages but content not fully translated
5. **Activity Types**: Fixed list of activity types, cannot add custom types
6. **Search**: Full-text search limited to title, description, location
7. **Analytics**: Basic analytics only, advanced reporting in development
8. **Group Bookings**: No group booking functionality (individual bookings only)
9. **Activity Bundles**: No bundle/package deals
10. **Dynamic Pricing**: No surge pricing or dynamic pricing

### Known Issues
1. **Comment Loading**: Initial load may be slow for posts with many comments (lazy loading implemented to mitigate)
2. **Notification Delay**: Push notifications may have 1-2 second delay due to queue processing
3. **QR Scanner**: May have issues in low light conditions
4. **Map Performance**: Loading many markers on map can be slow
5. **Image Upload**: Large image uploads (>10MB) may timeout
6. **Socket Reconnection**: Occasionally requires app restart after network issues
7. **Payment Webhook**: Stripe webhook retries may cause duplicate processing (idempotency in development)

### Planned Fixes
1. Improve offline mode with full data sync
2. Optimize comment loading with cursor-based pagination
3. Implement webhook idempotency keys
4. Add image compression before upload
5. Improve socket reconnection logic
6. Add map marker clustering for performance

---

## 14. 🔮 Future Improvements

### Short-term (Next 3 months)
- **Multi-currency Support**: Add TND and other currencies
- **Advanced Search**: Add filters for price range, duration, difficulty
- **Booking Calendar**: Visual calendar for activity availability
- **Wishlist**: Save activities for later
- **Activity Recommendations**: AI-powered suggestions based on user preferences
- **In-app Chat Improvements**: Add voice messages, file sharing
- **Review Photos**: Allow tourists to add photos to reviews
- **Organizer Dashboard**: Enhanced analytics and reporting

### Mid-term (Next 6 months)
- **Group Bookings**: Allow booking for groups with discounts
- **Activity Bundles**: Create package deals with multiple activities
- **Dynamic Pricing**: Surge pricing during peak times
- **Loyalty Program**: Points system for frequent users
- **Referral System**: Invite friends and earn credits
- **Multi-language Content**: Translate activity descriptions
- **Video Previews**: Add short video previews for activities
- **Advanced Analytics**: Heat maps, booking trends, revenue tracking

### Long-term (Next 12 months)
- **Virtual Tours**: VR/AR experiences for activities
- **Live Streaming**: Organizers can stream activities live
- **AI Chatbot**: Automated customer support
- **Integration with Travel Services**: Flights, hotels, car rentals
- **Corporate Accounts**: B2B solutions for companies
- **White-label Solution**: Platform as a service for other destinations
- **Mobile Web**: Progressive web app for desktop users
- **Blockchain**: Immutable review system, smart contract payments

### Technical Improvements
- **Microservices Architecture**: Split backend into microservices
- **GraphQL**: Replace REST API with GraphQL for better query efficiency
- **Server-side Rendering**: Improve SEO for web version
- **CDN Integration**: Global content delivery for faster load times
- **Database Sharding**: Scale for millions of users
- **AI/ML Integration**: Predictive analytics, fraud detection
- **Enhanced Security**: Biometric authentication, 2FA
- **Performance Optimization**: Reduce app size, improve load times

---

## 📞 Support & Contact

### For Users
- **Email**: support@djtrip.com
- **In-app Help**: Settings → Help & Support
- **FAQ**: Available in app

### For Developers
- **Documentation**: This file + code comments
- **GitHub**: https://github.com/your-repo/DJTrip
- **Issues**: GitHub Issues page

### For Organizers
- **Onboarding Guide**: Available after approval
- **Support Email**: organizers@djtrip.com
- **Video Tutorials**: Coming soon

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 🙏 Acknowledgments

- **Flutter Team**: For the amazing cross-platform framework
- **MongoDB**: For the flexible database solution
- **Stripe**: For secure payment processing
- **Cloudinary**: For image hosting
- **Firebase**: For push notifications
- **Socket.io**: For real-time features

---

**Document Version**: 1.0.0  
**Last Updated**: January 2025  
**Maintained By**: DJTrip Development Team
