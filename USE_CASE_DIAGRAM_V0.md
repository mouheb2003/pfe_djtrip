# DJTrip Use Case Diagram - Version 0

## Project Overview
DJTrip is a comprehensive tourism platform for Djerba island connecting tourists with activity organizers.

## Actors (Primary and Secondary)

### Primary Actors
1. **Tourist (Touriste)**
   - Role: End user who discovers and books activities
   - Can browse activities, make bookings, leave reviews, message organizers

2. **Organizer (Organisator)**
   - Role: Activity provider who creates and manages activities
   - Can create activities, manage bookings, verify check-ins, view analytics

3. **Admin**
   - Role: Platform administrator
   - Can manage users, moderate content, handle appeals, view system logs

### Secondary Actors
4. **Unauthenticated User**
   - Role: Visitor who needs to register/login
   - Can sign up, authenticate, recover password

5. **Payment System (Stripe)**
   - External system for processing payments
   - Handles checkout sessions, refunds, webhooks

6. **Email Service**
   - External system for sending notifications
   - Handles booking confirmations, password resets, appeal notifications

---

## Use Case Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DJTrip System                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Tourist    │     │  Organizer   │     │    Admin      │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Authentication System                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-01: Sign Up (Email/Google)                                         │  │
│  │  UC-02: Sign In (Email/Google)                                        │  │
│  │  UC-03: Verify Email                                                   │  │
│  │  UC-04: Forgot Password                                                │  │
│  │  UC-05: Reset Password                                                 │  │
│  │  UC-06: Complete Onboarding                                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Activity Management                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-07: Browse Activities (Tourist)                                   │  │
│  │  UC-08: Search Activities (Tourist)                                   │  │
│  │  UC-09: Filter Activities by Category/Location/Price (Tourist)         │  │
│  │  UC-10: View Activity Details (Tourist)                                │  │
│  │  UC-11: Create Activity (Organizer)                                    │  │
│  │  UC-12: Edit Activity (Organizer)                                      │  │
│  │  UC-13: Delete Activity (Organizer)                                    │  │
│  │  UC-14: Upload Activity Photos (Organizer)                             │  │
│  │  UC-15: Generate AI Activity Image (Organizer)                         │  │
│  │  UC-16: View My Activities (Organizer)                                 │  │
│  │  UC-17: View Archived Activities (Organizer)                           │  │
│  │  UC-18: Manage Activity Timeline (Organizer)                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Booking System                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-19: Book Activity (Tourist)                                       │  │
│  │  UC-20: Book with Payment (Tourist)                                   │  │
│  │  │  └─ UC-20.1: Create Stripe Checkout Session                        │  │
│  │  │  └─ UC-20.2: Complete Payment                                      │  │
│  │  │  └─ UC-20.3: Handle Payment Webhook                                │  │
│  │  UC-21: Book without Payment (Tourist)                                 │  │
│  │  UC-22: View My Bookings (Tourist)                                     │  │
│  │  UC-23: View Booking Details (Tourist)                                 │  │
│  │  UC-24: Cancel Booking (Tourist)                                       │  │
│  │  │  └─ UC-24.1: Apply Cancellation Policy                              │  │
│  │  │  └─ UC-24.2: Process Refund (if applicable)                         │  │
│  │  UC-25: View Booking Requests (Organizer)                              │  │
│  │  UC-26: Approve Booking (Organizer) - [DEPRECATED: Auto-approval]      │  │
│  │  UC-27: Reject Booking (Organizer) - [DEPRECATED: Auto-approval]       │  │
│  │  UC-28: View Booking Details (Organizer)                               │  │
│  │  UC-29: Verify Check-in QR Code (Organizer)                            │  │
│  │  │  └─ UC-29.1: Scan QR Code                                           │  │
│  │  │  └─ UC-29.2: Validate Booking Token                                 │  │
│  │  │  └─ UC-29.3: Mark as Used                                          │  │
│  │  UC-30: View Booking Statistics (Organizer)                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Review & Rating System                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-31: Submit Activity Review (Tourist)                              │  │
│  │  UC-32: Submit Organizer Rating (Tourist)                             │  │
│  │  UC-33: View Activity Reviews (Tourist/Organizer)                     │  │
│  │  UC-34: View Organizer Ratings (Tourist/Organizer)                    │  │
│  │  UC-35: Update Own Review (Tourist)                                    │  │
│  │  UC-36: Delete Own Review (Tourist)                                   │  │
│  │  UC-37: Delete Any Review (Admin)                                     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Messaging System                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-38: View Conversations (Tourist/Organizer)                        │  │
│  │  UC-39: Send Text Message (Tourist/Organizer)                         │  │
│  │  UC-40: Send Image Message (Tourist/Organizer)                        │  │
│  │  UC-41: Send Audio Message (Tourist/Organizer)                        │  │
│  │  UC-42: Send Video Message (Tourist/Organizer)                        │  │
│  │  UC-43: View Message History (Tourist/Organizer)                      │  │
│  │  UC-44: Edit Message (Tourist/Organizer)                              │  │
│  │  UC-45: Delete Message (Tourist/Organizer)                            │  │
│  │  UC-46: Clear Chat (Tourist/Organizer)                                │  │
│  │  UC-47: Archive Conversation (Tourist/Organizer)                      │  │
│  │  UC-48: Block User (Tourist/Organizer)                                │  │
│  │  UC-49: Unblock User (Tourist/Organizer)                              │  │
│  │  UC-50: Mute Conversation (Tourist/Organizer)                          │  │
│  │  UC-51: Unmute Conversation (Tourist/Organizer)                        │  │
│  │  UC-52: Get Unread Message Count (Tourist/Organizer)                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Social Feed System                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-53: View Feed Posts (Tourist/Organizer)                           │  │
│  │  UC-54: Create Post (Tourist/Organizer)                               │  │
│  │  UC-55: Upload Post Image (Tourist/Organizer)                          │  │
│  │  UC-56: Edit Own Post (Tourist/Organizer)                             │  │
│  │  UC-57: Delete Own Post (Tourist/Organizer)                           │  │
│  │  UC-58: React to Post (Tourist/Organizer)                              │  │
│  │  UC-59: View Post Comments (Tourist/Organizer)                         │  │
│  │  UC-60: Add Comment to Post (Tourist/Organizer)                        │  │
│  │  UC-61: Reply to Comment (Tourist/Organizer)                           │  │
│  │  UC-62: React to Comment (Tourist/Organizer)                           │  │
│  │  UC-63: Edit Own Comment (Tourist/Organizer)                           │  │
│  │  UC-64: Delete Own Comment (Tourist/Organizer)                         │  │
│  │  UC-65: Mention User in Comment (Tourist/Organizer)                    │  │
│  │  UC-66: Search Users for Mention (Tourist/Organizer)                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Social Follow System                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-67: Follow User (Tourist/Organizer)                               │  │
│  │  UC-68: Unfollow User (Tourist/Organizer)                             │  │
│  │  UC-69: Check Follow Status (Tourist/Organizer)                        │  │
│  │  UC-70: View Followers Count (Tourist/Organizer)                       │  │
│  │  UC-71: View Following Count (Tourist/Organizer)                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Notification System                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-72: View Notifications (Tourist/Organizer)                        │  │
│  │  UC-73: Mark Notification as Read (Tourist/Organizer)                  │  │
│  │  UC-74: Mark All Notifications as Read (Tourist/Organizer)            │  │
│  │  UC-75: Get Unread Count (Tourist/Organizer)                           │  │
│  │  UC-76: Delete Notification (Tourist/Organizer)                        │  │
│  │  UC-77: Configure Notification Preferences (Tourist/Organizer)         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      User Profile Management                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-78: View Own Profile (Tourist/Organizer)                          │  │
│  │  UC-79: Edit Profile (Tourist/Organizer)                              │  │
│  │  UC-80: Upload Avatar (Tourist/Organizer)                             │  │
│  │  UC-81: View Public Profile (Tourist/Organizer)                       │  │
│  │  UC-82: View User Overview (Admin)                                    │  │
│  │  UC-83: Manage Privacy Settings (Tourist/Organizer)                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Appeal System                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-84: Submit Appeal (Tourist/Organizer)                             │  │
│  │  UC-85: Submit Anonymous Appeal (Unauthenticated)                      │  │
│  │  UC-86: View Own Appeals (Tourist/Organizer)                          │  │
│  │  UC-87: View All Appeals (Admin)                                      │  │
│  │  UC-88: View Appeal Details (Admin)                                   │  │
│  │  UC-89: Update Appeal Status (Admin)                                  │  │
│  │  │  └─ UC-89.1: Accept Appeal (Restore Account)                       │  │
│  │  │  └─ UC-89.2: Reject Appeal (Keep Status)                           │  │
│  │  UC-90: View Appeal Statistics (Admin)                                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Admin Management System                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-91: View All Users (Admin)                                        │  │
│  │  UC-92: View User Details (Admin)                                     │  │
│  │  UC-93: Suspend User Account (Admin)                                   │  │
│  │  UC-94: Ban User Account (Admin)                                      │  │
│  │  UC-95: Restore User Account (Admin)                                   │  │
│  │  UC-96: View All Activities (Admin)                                    │  │
│  │  UC-97: Create Activity (Admin)                                       │  │
│  │  UC-98: Edit Activity (Admin)                                         │  │
│  │  UC-99: Delete Activity (Admin)                                       │  │
│  │  UC-100: View All Posts (Admin)                                       │  │
│  │  UC-101: Create Post (Admin)                                          │  │
│  │  UC-102: Edit Post (Admin)                                            │  │
│  │  UC-103: Delete Post (Admin)                                          │  │
│  │  UC-104: View All Comments (Admin)                                    │  │
│  │  UC-105: Delete Comment (Admin)                                       │  │
│  │  UC-106: View System Logs (Admin)                                     │  │
│  │  UC-107: View Activity Logs (Admin)                                   │  │
│  │  UC-108: View Payment Records (Admin)                                 │  │
│  │  UC-109: View Invoice Records (Admin)                                 │  │
│  │  UC-110: Manage System Settings (Admin)                                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Location & Map System                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-111: View All Places (Tourist)                                     │  │
│  │  UC-112: View Place Details (Tourist)                                 │  │
│  │  UC-113: View Map of Activities (Tourist)                              │  │
│  │  UC-114: Pick Location on Map (Organizer)                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Settings & Preferences                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  UC-115: Manage Account Settings (Tourist/Organizer)                  │  │
│  │  UC-116: Manage Reminder Preferences (Tourist)                         │  │
│  │  UC-117: Change Password (Tourist/Organizer)                           │  │
│  │  UC-118: Delete Account (Tourist/Organizer)                           │  │
│  │  UC-119: Manage Language Settings (Tourist/Organizer)                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Use Case Descriptions

### Authentication System (UC-01 to UC-06)

**UC-01: Sign Up**
- **Actor**: Unauthenticated User
- **Description**: Register a new account using email/password or Google OAuth
- **Preconditions**: None
- **Postconditions**: User account created, email verification required, onboarding pending
- **Flow**: 
  1. User enters registration details
  2. System validates input
  3. System creates user account
  4. System sends verification email
  5. System returns tokens for onboarding

**UC-02: Sign In**
- **Actor**: Unauthenticated User
- **Description**: Authenticate using email/password or Google OAuth
- **Preconditions**: User account exists and is active
- **Postconditions**: User authenticated, tokens issued, online status updated
- **Flow**:
  1. User enters credentials
  2. System validates credentials
  3. System checks account status (active/suspended/banned)
  4. System issues access and refresh tokens
  5. System updates last connection and online status

**UC-03: Verify Email**
- **Actor**: User
- **Description**: Verify email address using verification code
- **Preconditions**: User has verification code
- **Postconditions**: Email verified, account fully active
- **Flow**:
  1. User enters verification code
  2. System validates code
  3. System marks email as verified
  4. System sends confirmation

**UC-04: Forgot Password**
- **Actor**: Unauthenticated User
- **Description**: Request password reset code via email
- **Preconditions**: User account exists
- **Postconditions**: Reset code sent to email
- **Flow**:
  1. User enters email
  2. System finds user account
  3. System generates reset code
  4. System sends code via email

**UC-05: Reset Password**
- **Actor**: Unauthenticated User
- **Description**: Reset password using verification code
- **Preconditions**: Valid reset code
- **Postconditions**: Password updated
- **Flow**:
  1. User enters email, code, new password
  2. System validates code
  3. System updates password
  4. System sends confirmation

**UC-06: Complete Onboarding**
- **Actor**: User
- **Description**: Complete profile setup after registration
- **Preconditions**: User registered but not onboarded
- **Postconditions**: User profile complete, userType selected
- **Flow**:
  1. User selects user type (Tourist/Organizer)
  2. User fills profile information
  3. System saves profile
  4. System marks user as onboarded

---

### Activity Management (UC-07 to UC-18)

**UC-07: Browse Activities**
- **Actor**: Tourist
- **Description**: View list of available activities with filters
- **Preconditions**: User authenticated
- **Postconditions**: Activities displayed
- **Flow**:
  1. User requests activities
  2. System applies filters (category, location, price, date)
  3. System returns paginated activities

**UC-08: Search Activities**
- **Actor**: Tourist
- **Description**: Search activities by text query
- **Preconditions**: User authenticated
- **Postconditions**: Matching activities displayed
- **Flow**:
  1. User enters search query
  2. System searches title, description, location
  3. System returns matching activities

**UC-09: Filter Activities**
- **Actor**: Tourist
- **Description**: Filter activities by various criteria
- **Preconditions**: Activities available
- **Postconditions**: Filtered activities displayed
- **Flow**:
  1. User selects filters (category, price range, date range, difficulty)
  2. System applies filters
  3. System returns filtered results

**UC-10: View Activity Details**
- **Actor**: Tourist
- **Description**: View detailed information about an activity
- **Preconditions**: Activity exists
- **Postconditions**: Activity details displayed
- **Flow**:
  1. User selects activity
  2. System retrieves activity with organizer info
  3. System displays full details

**UC-11: Create Activity**
- **Actor**: Organizer
- **Description**: Create a new activity
- **Preconditions**: Organizer authenticated, approved
- **Postconditions**: Activity created, added to organizer's list
- **Flow**:
  1. Organizer enters activity details
  2. Organizer uploads photos or generates AI image
  3. System validates activity start date (24h minimum)
  4. System creates activity
  5. System notifies followers

**UC-12: Edit Activity**
- **Actor**: Organizer
- **Description**: Modify existing activity
- **Preconditions**: Activity exists, user is owner, activity not completed
- **Postconditions**: Activity updated
- **Flow**:
  1. Organizer modifies activity details
  2. System validates changes
  3. System updates activity
  4. System notifies booked users

**UC-13: Delete Activity**
- **Actor**: Organizer
- **Description**: Delete an activity
- **Preconditions**: Activity exists, user is owner, cancellation message provided
- **Postconditions**: Activity deleted, bookings cancelled, users notified
- **Flow**:
  1. Organizer provides cancellation message
  2. System cancels all bookings
  3. System deletes activity
  4. System notifies booked users

**UC-14: Upload Activity Photos**
- **Actor**: Organizer
- **Description**: Upload photos for activity
- **Preconditions**: Activity exists
- **Postconditions**: Photos uploaded to Cloudinary
- **Flow**:
  1. Organizer selects photos
  2. System uploads to Cloudinary
  3. System updates activity with photo URLs

**UC-15: Generate AI Activity Image**
- **Actor**: Organizer
- **Description**: Generate AI image for activity
- **Preconditions**: Activity details provided
- **Postconditions**: AI image generated and attached
- **Flow**:
  1. Organizer requests AI image
  2. System generates image using AI service
  3. System attaches image to activity

**UC-16: View My Activities**
- **Actor**: Organizer
- **Description**: View organizer's active activities
- **Preconditions**: Organizer authenticated
- **Postconditions**: Active activities displayed
- **Flow**:
  1. Organizer requests activities
  2. System filters by end date >= now
  3. System returns ongoing and upcoming activities

**UC-17: View Archived Activities**
- **Actor**: Organizer
- **Description**: View organizer's past activities
- **Preconditions**: Organizer authenticated
- **Postconditions**: Archived activities displayed
- **Flow**:
  1. Organizer requests archived activities
  2. System filters by end date < now
  3. System returns past activities

**UC-18: Manage Activity Timeline**
- **Actor**: Organizer
- **Description**: View activities by timeline status (UPCOMING/ONGOING/PAST)
- **Preconditions**: Activities exist
- **Postconditions**: Activities grouped by timeline
- **Flow**:
  1. System calculates timeline status based on dates
  2. System groups activities by status
  3. System displays timeline view

---

### Booking System (UC-19 to UC-30)

**UC-19: Book Activity**
- **Actor**: Tourist
- **Description**: Book an activity
- **Preconditions**: User authenticated, activity available, capacity available
- **Postconditions**: Booking created, status depends on payment requirement
- **Flow**:
  1. Tourist selects activity
  2. Tourist enters participant count
  3. System checks capacity
  4. System creates booking
  5. System notifies organizer

**UC-20: Book with Payment**
- **Actor**: Tourist
- **Description**: Book activity with Stripe payment
- **Preconditions**: Activity requires payment
- **Postconditions**: Payment processed, booking approved
- **Flow**:
  1. **UC-20.1**: System creates Stripe checkout session
  2. User completes payment
  3. **UC-20.2**: System marks payment as complete
  4. **UC-20.3**: Stripe webhook confirms payment
  5. System approves booking, generates QR code
  6. System sends confirmation email

**UC-21: Book without Payment**
- **Actor**: Tourist
- **Description**: Book activity without payment (skip_payment flag)
- **Preconditions**: Activity allows free booking
- **Postconditions**: Booking auto-approved, QR code generated
- **Flow**:
  1. Tourist books with skip_payment=true
  2. System auto-approves booking
  3. System generates QR code
  4. System sends confirmation email

**UC-22: View My Bookings**
- **Actor**: Tourist
- **Description**: View all bookings grouped by status
- **Preconditions**: User authenticated
- **Postconditions**: Bookings displayed by status
- **Flow**:
  1. Tourist requests bookings
  2. System groups by status (pending, confirmed, cancelled, used)
  3. System returns grouped bookings

**UC-23: View Booking Details**
- **Actor**: Tourist
- **Description**: View detailed booking information
- **Preconditions**: Booking exists
- **Postconditions**: Booking details displayed
- **Flow**:
  1. Tourist selects booking
  2. System retrieves booking with activity details
  3. System displays booking with QR code

**UC-24: Cancel Booking**
- **Actor**: Tourist
- **Description**: Cancel a booking with refund policy
- **Preconditions**: Booking exists, cancellable
- **Postconditions**: Booking cancelled, refund processed if applicable
- **Flow**:
  1. **UC-24.1**: System applies cancellation policy
  2. System calculates refund amount
  3. **UC-24.2**: System processes refund
  4. System updates booking status
  5. System notifies organizer

**UC-25: View Booking Requests**
- **Actor**: Organizer
- **Description**: View incoming booking requests
- **Preconditions**: Organizer authenticated
- **Postconditions**: Bookings displayed
- **Flow**:
  1. Organizer requests bookings
  2. System returns bookings for organizer's activities
  3. System groups by status

**UC-26: Approve Booking [DEPRECATED]**
- **Actor**: Organizer
- **Description**: Approve a booking request
- **Status**: DEPRECATED - Auto-approval system enabled
- **Note**: All bookings are now automatically approved

**UC-27: Reject Booking [DEPRECATED]**
- **Actor**: Organizer
- **Description**: Reject a booking request
- **Status**: DEPRECATED - Auto-approval system enabled
- **Note**: Rejections handled through cancellation by tourist

**UC-28: View Booking Details (Organizer)**
- **Actor**: Organizer
- **Description**: View booking details with tourist info
- **Preconditions**: Booking exists for organizer's activity
- **Postconditions**: Booking details displayed
- **Flow**:
  1. Organizer selects booking
  2. System retrieves booking with tourist info
  3. System displays full details

**UC-29: Verify Check-in QR Code**
- **Actor**: Organizer
- **Description**: Scan and validate QR code for check-in
- **Preconditions**: Booking approved, QR code valid
- **Postconditions**: Booking marked as used
- **Flow**:
  1. **UC-29.1**: Organizer scans QR code
  2. **UC-29.2**: System validates booking token
  3. System checks activity not started (15min grace)
  4. **UC-29.3**: System marks booking as used
  5. System logs check-in

**UC-30: View Booking Statistics**
- **Actor**: Organizer
- **Description**: View booking statistics and revenue
- **Preconditions**: Organizer authenticated
- **Postconditions**: Statistics displayed
- **Flow**:
  1. Organizer requests statistics
  2. System calculates total bookings, revenue
  3. System returns statistics

---

### Review & Rating System (UC-31 to UC-37)

**UC-31: Submit Activity Review**
- **Actor**: Tourist
- **Description**: Submit review for participated activity
- **Preconditions**: Tourist has approved booking for activity
- **Postconditions**: Review created, activity stats updated
- **Flow**:
  1. Tourist selects activity
  2. Tourist enters rating (1-5) and comment
  3. System validates participation
  4. System creates review
  5. System updates activity rating
  6. System notifies organizer

**UC-32: Submit Organizer Rating**
- **Actor**: Tourist
- **Description**: Rate organizer based on experience
- **Preconditions**: Tourist participated in organizer's activity
- **Postconditions**: Rating created, organizer stats updated
- **Flow**:
  1. Tourist selects organizer
  2. Tourist enters rating and comment
  3. System validates participation
  4. System creates rating
  5. System updates organizer rating

**UC-33: View Activity Reviews**
- **Actor**: Tourist, Organizer
- **Description**: View reviews for an activity
- **Preconditions**: Activity exists
- **Postconditions**: Reviews displayed
- **Flow**:
  1. User requests activity reviews
  2. System returns reviews with tourist info
  3. System displays reviews

**UC-34: View Organizer Ratings**
- **Actor**: Tourist, Organizer
- **Description**: View ratings for an organizer
- **Preconditions**: Organizer exists
- **Postconditions**: Ratings displayed
- **Flow**:
  1. User requests organizer ratings
  2. System returns direct and activity-based ratings
  3. System displays ratings

**UC-35: Update Own Review**
- **Actor**: Tourist
- **Description**: Modify own review/rating
- **Preconditions**: Review exists, user is owner
- **Postconditions**: Review updated, stats recalculated
- **Flow**:
  1. Tourist modifies review
  2. System validates ownership
  3. System updates review
  4. System recalculates stats

**UC-36: Delete Own Review**
- **Actor**: Tourist
- **Description**: Delete own review/rating
- **Preconditions**: Review exists, user is owner
- **Postconditions**: Review deleted, stats recalculated
- **Flow**:
  1. Tourist requests deletion
  2. System validates ownership
  3. System deletes review
  4. System recalculates stats

**UC-37: Delete Any Review**
- **Actor**: Admin
- **Description**: Delete any review (moderation)
- **Preconditions**: Admin authenticated
- **Postconditions**: Review deleted, stats recalculated
- **Flow**:
  1. Admin selects review
  2. System deletes review
  3. System recalculates stats

---

### Messaging System (UC-38 to UC-52)

**UC-38: View Conversations**
- **Actor**: Tourist, Organizer
- **Description**: View list of conversations
- **Preconditions**: User authenticated
- **Postconditions**: Conversations displayed with unread counts
- **Flow**:
  1. User requests conversations
  2. System retrieves conversations
  3. System calculates unread counts
  4. System displays conversations

**UC-39: Send Text Message**
- **Actor**: Tourist, Organizer
- **Description**: Send text message to user
- **Preconditions**: User authenticated, not blocked
- **Postconditions**: Message sent, notification triggered
- **Flow**:
  1. User enters message
  2. System checks block status
  3. System saves message
  4. System emits real-time update
  5. System sends notification

**UC-40: Send Image Message**
- **Actor**: Tourist, Organizer
- **Description**: Send image message
- **Preconditions**: User authenticated, image provided
- **Postconditions**: Image uploaded, message sent
- **Flow**:
  1. User selects image
  2. System uploads to Cloudinary
  3. System creates message
  4. System emits real-time update

**UC-41: Send Audio Message**
- **Actor**: Tourist, Organizer
- **Description**: Send voice message
- **Preconditions**: User authenticated, audio provided
- **Postconditions**: Audio uploaded, message sent
- **Flow**:
  1. User records audio
  2. System uploads to Cloudinary
  3. System creates message with duration
  4. System emits real-time update

**UC-42: Send Video Message**
- **Actor**: Tourist, Organizer
- **Description**: Send video message
- **Preconditions**: User authenticated, video provided
- **Postconditions**: Video uploaded, message sent
- **Flow**:
  1. User selects video
  2. System uploads to Cloudinary
  3. System creates message
  4. System emits real-time update

**UC-43: View Message History**
- **Actor**: Tourist, Organizer
- **Description**: View message history with a user
- **Preconditions**: Conversation exists
- **Postconditions**: Messages displayed, marked as read
- **Flow**:
  1. User selects conversation
  2. System retrieves messages
  3. System marks as read
  4. System displays messages

**UC-44: Edit Message**
- **Actor**: Tourist, Organizer
- **Description**: Edit own message
- **Preconditions**: Message exists, user is sender
- **Postconditions**: Message updated
- **Flow**:
  1. User modifies message
  2. System validates ownership
  3. System updates message
  4. System marks as edited

**UC-45: Delete Message**
- **Actor**: Tourist, Organizer
- **Description**: Delete own message
- **Preconditions**: Message exists, user is sender
- **Postconditions**: Message deleted
- **Flow**:
  1. User requests deletion
  2. System validates ownership
  3. System deletes message

**UC-46: Clear Chat**
- **Actor**: Tourist, Organizer
- **Description**: Clear chat history (one-sided)
- **Preconditions**: Conversation exists
- **Postconditions**: Chat cleared for user
- **Flow**:
  1. User requests clear
  2. System adds partner to deleted list
  3. System hides messages for user

**UC-47: Archive Conversation**
- **Actor**: Tourist, Organizer
- **Description**: Archive conversation
- **Preconditions**: Conversation exists
- **Postconditions**: Conversation archived
- **Flow**:
  1. User archives conversation
  2. System adds to archived list
  3. System hides from main view

**UC-48: Block User**
- **Actor**: Tourist, Organizer
- **Description**: Block user from messaging
- **Preconditions**: User authenticated
- **Postconditions**: User blocked
- **Flow**:
  1. User blocks another user
  2. System adds to blocked list
  3. System prevents messages

**UC-49: Unblock User**
- **Actor**: Tourist, Organizer
- **Description**: Unblock user
- **Preconditions**: User blocked
- **Postconditions**: User unblocked
- **Flow**:
  1. User unblocks
  2. System removes from blocked list
  3. System allows messages

**UC-50: Mute Conversation**
- **Actor**: Tourist, Organizer
- **Description**: Mute conversation notifications
- **Preconditions**: Conversation exists
- **Postconditions**: Conversation muted
- **Flow**:
  1. User mutes conversation
  2. System adds to muted list
  3. System suppresses notifications

**UC-51: Unmute Conversation**
- **Actor**: Tourist, Organizer
- **Description**: Unmute conversation
- **Preconditions**: Conversation muted
- **Postconditions**: Conversation unmuted
- **Flow**:
  1. User unmutes
  2. System removes from muted list
  3. System restores notifications

**UC-52: Get Unread Message Count**
- **Actor**: Tourist, Organizer
- **Description**: Get count of unread messages
- **Preconditions**: User authenticated
- **Postconditions**: Unread count returned
- **Flow**:
  1. User requests unread count
  2. System counts unread messages
  3. System returns count

---

### Social Feed System (UC-53 to UC-66)

**UC-53: View Feed Posts**
- **Actor**: Tourist, Organizer
- **Description**: View social feed posts
- **Preconditions**: User authenticated
- **Postconditions**: Posts displayed
- **Flow**:
  1. User requests feed
  2. System returns active posts
  3. System includes like status

**UC-54: Create Post**
- **Actor**: Tourist, Organizer
- **Description**: Create a new post
- **Preconditions**: User authenticated
- **Postconditions**: Post created
- **Flow**:
  1. User enters content
  2. User optionally adds images
  3. System creates post
  4. System logs activity

**UC-55: Upload Post Image**
- **Actor**: Tourist, Organizer
- **Description**: Upload image for post
- **Preconditions**: Image provided
- **Postconditions**: Image uploaded
- **Flow**:
  1. User selects image
  2. System uploads to Cloudinary
  3. System returns image URL

**UC-56: Edit Own Post**
- **Actor**: Tourist, Organizer
- **Description**: Edit own post
- **Preconditions**: Post exists, user is author
- **Postconditions**: Post updated
- **Flow**:
  1. User modifies post
  2. System validates ownership
  3. System updates post

**UC-57: Delete Own Post**
- **Actor**: Tourist, Organizer
- **Description**: Delete own post
- **Preconditions**: Post exists, user is author
- **Postconditions**: Post deactivated
- **Flow**:
  1. User requests deletion
  2. System validates ownership
  3. System deactivates post

**UC-58: React to Post**
- **Actor**: Tourist, Organizer
- **Description**: React to post (like, love, laugh, etc.)
- **Preconditions**: Post exists
- **Postconditions**: Reaction added/removed
- **Flow**:
  1. User selects reaction type
  2. System toggles reaction
  3. System updates counts
  4. System notifies author

**UC-59: View Post Comments**
- **Actor**: Tourist, Organizer
- **Description**: View comments on a post
- **Preconditions**: Post exists
- **Postconditions**: Comments displayed (paginated)
- **Flow**:
  1. User requests comments
  2. System returns root comments (paginated)
  3. System includes reaction counts

**UC-60: Add Comment to Post**
- **Actor**: Tourist, Organizer
- **Description**: Add comment to post
- **Preconditions**: Post exists, user authenticated
- **Postconditions**: Comment added
- **Flow**:
  1. User enters comment
  2. System validates user profile
  3. System creates comment
  4. System extracts mentions
  5. System notifies post author
  6. System notifies mentioned users

**UC-61: Reply to Comment**
- **Actor**: Tourist, Organizer
- **Description**: Reply to a comment
- **Preconditions**: Comment exists
- **Postconditions**: Reply added
- **Flow**:
  1. User enters reply
  2. System validates parent comment
  3. System calculates depth
  4. System creates reply
  5. System notifies parent author

**UC-62: React to Comment**
- **Actor**: Tourist, Organizer
- **Description**: React to comment
- **Preconditions**: Comment exists
- **Postconditions**: Reaction added/removed
- **Flow**:
  1. User selects reaction type
  2. System toggles reaction
  3. System updates counts
  4. System notifies comment author

**UC-63: Edit Own Comment**
- **Actor**: Tourist, Organizer
- **Description**: Edit own comment
- **Preconditions**: Comment exists, user is author
- **Postconditions**: Comment updated
- **Flow**:
  1. User modifies comment
  2. System validates ownership
  3. System updates comment
  4. System extracts mentions

**UC-64: Delete Own Comment**
- **Actor**: Tourist, Organizer
- **Description**: Delete own comment
- **Preconditions**: Comment exists, user is author or post owner
- **Postconditions**: Comment deactivated
- **Flow**:
  1. User requests deletion
  2. System validates permissions
  3. System deactivates comment
  4. System updates counts

**UC-65: Mention User in Comment**
- **Actor**: Tourist, Organizer
- **Description**: Mention user using @username
- **Preconditions**: User exists
- **Postconditions**: User mentioned, notified
- **Flow**:
  1. User types @username
  2. System validates user
  3. System adds to mentions
  4. System notifies mentioned user

**UC-66: Search Users for Mention**
- **Actor**: Tourist, Organizer
- **Description**: Search users to mention
- **Preconditions**: Query provided
- **Postconditions**: Matching users returned
- **Flow**:
  1. User types search query
  2. System searches username/fullname
  3. System returns matching users

---

### Social Follow System (UC-67 to UC-71)

**UC-67: Follow User**
- **Actor**: Tourist, Organizer
- **Description**: Follow another user
- **Preconditions**: User authenticated, not already following
- **Postconditions**: Follow created, notification sent
- **Flow**:
  1. User requests to follow
  2. System checks existing follow
  3. System creates follow
  4. System notifies followed user

**UC-68: Unfollow User**
- **Actor**: Tourist, Organizer
- **Description**: Unfollow a user
- **Preconditions**: Following exists
- **Postconditions**: Follow deleted
- **Flow**:
  1. User requests to unfollow
  2. System deletes follow
  3. System confirms unfollow

**UC-69: Check Follow Status**
- **Actor**: Tourist, Organizer
- **Description**: Check if following a user
- **Preconditions**: User authenticated
- **Postconditions**: Follow status returned
- **Flow**:
  1. User checks follow status
  2. System queries follow relationship
  3. System returns boolean

**UC-70: View Followers Count**
- **Actor**: Tourist, Organizer
- **Description**: Get count of followers
- **Preconditions**: User exists
- **Postconditions**: Count returned
- **Flow**:
  1. User requests followers count
  2. System counts followers
  3. System returns count

**UC-71: View Following Count**
- **Actor**: Tourist, Organizer
- **Description**: Get count of following
- **Preconditions**: User exists
- **Postconditions**: Count returned
- **Flow**:
  1. User requests following count
  2. System counts following
  3. System returns count

---

### Notification System (UC-72 to UC-77)

**UC-72: View Notifications**
- **Actor**: Tourist, Organizer
- **Description**: View user notifications
- **Preconditions**: User authenticated
- **Postconditions**: Notifications displayed
- **Flow**:
  1. User requests notifications
  2. System returns notifications (paginated)
  3. System includes pagination info

**UC-73: Mark Notification as Read**
- **Actor**: Tourist, Organizer
- **Description**: Mark single notification as read
- **Preconditions**: Notification exists, user is owner
- **Postconditions**: Notification marked read
- **Flow**:
  1. User marks notification
  2. System updates read status
  3. System confirms update

**UC-74: Mark All Notifications as Read**
- **Actor**: Tourist, Organizer
- **Description**: Mark all notifications as read
- **Preconditions**: User authenticated
- **Postconditions**: All notifications marked read
- **Flow**:
  1. User marks all as read
  2. System updates all notifications
  3. System returns count

**UC-75: Get Unread Count**
- **Actor**: Tourist, Organizer
- **Description**: Get count of unread notifications
- **Preconditions**: User authenticated
- **Postconditions**: Unread count returned
- **Flow**:
  1. User requests unread count
  2. System counts unread
  3. System returns count

**UC-76: Delete Notification**
- **Actor**: Tourist, Organizer
- **Description**: Delete a notification
- **Preconditions**: Notification exists, user is owner
- **Postconditions**: Notification deleted
- **Flow**:
  1. User deletes notification
  2. System validates ownership
  3. System deletes notification

**UC-77: Configure Notification Preferences**
- **Actor**: Tourist, Organizer
- **Description**: Manage notification settings
- **Preconditions**: User authenticated
- **Postconditions**: Preferences saved
- **Flow**:
  1. User configures preferences
  2. System saves preferences
  3. System confirms update

---

### User Profile Management (UC-78 to UC-83)

**UC-78: View Own Profile**
- **Actor**: Tourist, Organizer
- **Description**: View own profile information
- **Preconditions**: User authenticated
- **Postconditions**: Profile displayed
- **Flow**:
  1. User requests profile
  2. System returns profile data
  3. System displays profile

**UC-79: Edit Profile**
- **Actor**: Tourist, Organizer
- **Description**: Edit profile information
- **Preconditions**: User authenticated
- **Postconditions**: Profile updated
- **Flow**:
  1. User modifies profile
  2. System validates changes
  3. System updates profile

**UC-80: Upload Avatar**
- **Actor**: Tourist, Organizer
- **Description**: Upload profile picture
- **Preconditions**: Image provided
- **Postconditions**: Avatar uploaded
- **Flow**:
  1. User selects image
  2. System uploads to Cloudinary
  3. System updates avatar URL

**UC-81: View Public Profile**
- **Actor**: Tourist, Organizer
- **Description**: View another user's public profile
- **Preconditions**: User exists
- **Postconditions**: Public profile displayed
- **Flow**:
  1. User requests profile
  2. System returns public data
  3. System displays profile

**UC-82: View User Overview**
- **Actor**: Admin
- **Description**: View comprehensive user data
- **Preconditions**: Admin authenticated
- **Postconditions**: User overview displayed
- **Flow**:
  1. Admin requests user overview
  2. System fetches user + related data
  3. System displays overview

**UC-83: Manage Privacy Settings**
- **Actor**: Tourist, Organizer
- **Description**: Configure privacy settings
- **Preconditions**: User authenticated
- **Postconditions**: Privacy settings updated
- **Flow**:
  1. User configures privacy
  2. System saves settings
  3. System confirms update

---

### Appeal System (UC-84 to UC-90)

**UC-84: Submit Appeal**
- **Actor**: Tourist, Organizer
- **Description**: Submit appeal for account suspension/ban
- **Preconditions**: User suspended/banned or submitting reclamation
- **Postconditions**: Appeal submitted, emails sent
- **Flow**:
  1. User enters appeal details
  2. System validates account status
  3. System creates appeal
  4. System sends email to admin
  5. System sends confirmation to user

**UC-85: Submit Anonymous Appeal**
- **Actor**: Unauthenticated User
- **Description**: Submit appeal without authentication
- **Preconditions**: Email provided, account exists
- **Postconditions**: Appeal submitted
- **Flow**:
  1. User enters email and appeal
  2. System finds account by email
  3. System creates appeal
  4. System sends emails

**UC-86: View Own Appeals**
- **Actor**: Tourist, Organizer
- **Description**: View own appeal history
- **Preconditions**: User authenticated
- **Postconditions**: Appeals displayed
- **Flow**:
  1. User requests appeals
  2. System returns user's appeals
  3. System displays appeals

**UC-87: View All Appeals**
- **Actor**: Admin
- **Description**: View all appeals
- **Preconditions**: Admin authenticated
- **Postconditions**: Appeals displayed
- **Flow**:
  1. Admin requests appeals
  2. System returns appeals with filters
  3. System normalizes account status
  4. System sorts by priority

**UC-88: View Appeal Details**
- **Actor**: Admin
- **Description**: View detailed appeal information
- **Preconditions**: Appeal exists
- **Postconditions**: Appeal details displayed
- **Flow**:
  1. Admin selects appeal
  2. System returns full details
  3. System displays details

**UC-89: Update Appeal Status**
- **Actor**: Admin
- **Description**: Update appeal status (reviewed/accepted/rejected)
- **Preconditions**: Appeal exists, admin authenticated
- **Postconditions**: Status updated, account restored if accepted
- **Flow**:
  1. Admin selects new status
  2. **UC-89.1**: If accepted, restore account to active
  3. **UC-89.2**: If rejected, keep current status
  4. System sends decision email
  5. System notifies user

**UC-90: View Appeal Statistics**
- **Actor**: Admin
- **Description**: View appeal statistics
- **Preconditions**: Admin authenticated
- **Postconditions**: Statistics displayed
- **Flow**:
  1. Admin requests stats
  2. System calculates counts by status
  3. System returns statistics

---

### Admin Management System (UC-91 to UC-110)

**UC-91: View All Users**
- **Actor**: Admin
- **Description**: View all platform users
- **Preconditions**: Admin authenticated
- **Postconditions**: Users displayed (paginated)
- **Flow**:
  1. Admin requests users
  2. System returns users with filters
  3. System displays users

**UC-92: View User Details**
- **Actor**: Admin
- **Description**: View detailed user information
- **Preconditions**: User exists
- **Postconditions**: User details displayed
- **Flow**:
  1. Admin selects user
  2. System returns full user data
  3. System displays details

**UC-93: Suspend User Account**
- **Actor**: Admin
- **Description**: Temporarily suspend user account
- **Preconditions**: User exists
- **Postconditions**: Account suspended with reason and duration
- **Flow**:
  1. Admin enters suspension details
  2. System suspends account
  3. System sets expiry date
  4. System notifies user

**UC-94: Ban User Account**
- **Actor**: Admin
- **Description**: Permanently ban user account
- **Preconditions**: User exists
- **Postconditions**: Account banned with reason
- **Flow**:
  1. Admin enters ban reason
  2. System bans account
  3. System notifies user

**UC-95: Restore User Account**
- **Actor**: Admin
- **Description**: Restore suspended/banned account
- **Preconditions**: Account suspended/banned
- **Postconditions**: Account restored to active
- **Flow**:
  1. Admin restores account
  2. System resets status
  3. System notifies user

**UC-96: View All Activities**
- **Actor**: Admin
- **Description**: View all platform activities
- **Preconditions**: Admin authenticated
- **Postconditions**: Activities displayed
- **Flow**:
  1. Admin requests activities
  2. System returns all activities
  3. System displays activities

**UC-97: Create Activity (Admin)**
- **Actor**: Admin
- **Description**: Create activity as admin
- **Preconditions**: Admin authenticated
- **Postconditions**: Activity created
- **Flow**:
  1. Admin enters activity details
  2. System creates activity
  3. System logs activity

**UC-98: Edit Activity (Admin)**
- **Actor**: Admin
- **Description**: Edit any activity
- **Preconditions**: Activity exists
- **Postconditions**: Activity updated
- **Flow**:
  1. Admin modifies activity
  2. System updates activity
  3. System logs activity

**UC-99: Delete Activity (Admin)**
- **Actor**: Admin
- **Description**: Delete any activity
- **Preconditions**: Activity exists
- **Postconditions**: Activity deleted
- **Flow**:
  1. Admin deletes activity
  2. System removes activity
  3. System logs activity

**UC-100: View All Posts**
- **Actor**: Admin
- **Description**: View all social posts
- **Preconditions**: Admin authenticated
- **Postconditions**: Posts displayed
- **Flow**:
  1. Admin requests posts
  2. System returns all posts
  3. System displays posts

**UC-101: Create Post (Admin)**
- **Actor**: Admin
- **Description**: Create post as admin
- **Preconditions**: Admin authenticated
- **Postconditions**: Post created
- **Flow**:
  1. Admin creates post
  2. System saves post
  3. System logs activity

**UC-102: Edit Post (Admin)**
- **Actor**: Admin
- **Description**: Edit any post
- **Preconditions**: Post exists
- **Postconditions**: Post updated
- **Flow**:
  1. Admin modifies post
  2. System updates post
  3. System logs activity

**UC-103: Delete Post (Admin)**
- **Actor**: Admin
- **Description**: Delete any post
- **Preconditions**: Post exists
- **Postconditions**: Post deactivated
- **Flow**:
  1. Admin deletes post
  2. System deactivates post
  3. System logs activity

**UC-104: View All Comments**
- **Actor**: Admin
- **Description**: View all comments
- **Preconditions**: Admin authenticated
- **Postconditions**: Comments displayed
- **Flow**:
  1. Admin requests comments
  2. System returns comments
  3. System displays comments

**UC-105: Delete Comment (Admin)**
- **Actor**: Admin
- **Description**: Delete any comment
- **Preconditions**: Comment exists
- **Postconditions**: Comment deleted
- **Flow**:
  1. Admin deletes comment
  2. System deletes comment and replies
  3. System updates counts

**UC-106: View System Logs**
- **Actor**: Admin
- **Description**: View system operation logs
- **Preconditions**: Admin authenticated
- **Postconditions**: Logs displayed
- **Flow**:
  1. Admin requests logs
  2. System returns logs
  3. System displays logs

**UC-107: View Activity Logs**
- **Actor**: Admin
- **Description**: View user activity logs
- **Preconditions**: Admin authenticated
- **Postconditions**: Activity logs displayed
- **Flow**:
  1. Admin requests activity logs
  2. System returns logs
  3. System displays logs

**UC-108: View Payment Records**
- **Actor**: Admin
- **Description**: View all payment records
- **Preconditions**: Admin authenticated
- **Postconditions**: Payments displayed
- **Flow**:
  1. Admin requests payments
  2. System returns payments
  3. System displays payments

**UC-109: View Invoice Records**
- **Actor**: Admin
- **Description**: View invoice records
- **Preconditions**: Admin authenticated
- **Postconditions**: Invoices displayed
- **Flow**:
  1. Admin requests invoices
  2. System returns invoices
  3. System displays invoices

**UC-110: Manage System Settings**
- **Actor**: Admin
- **Description**: Configure system-wide settings
- **Preconditions**: Admin authenticated
- **Postconditions**: Settings updated
- **Flow**:
  1. Admin modifies settings
  2. System saves settings
  3. System confirms update

---

### Location & Map System (UC-111 to UC-114)

**UC-111: View All Places**
- **Actor**: Tourist
- **Description**: View all places/locations
- **Preconditions**: User authenticated
- **Postconditions**: Places displayed
- **Flow**:
  1. User requests places
  2. System returns places
  3. System displays places

**UC-112: View Place Details**
- **Actor**: Tourist
- **Description**: View detailed place information
- **Preconditions**: Place exists
- **Postconditions**: Place details displayed
- **Flow**:
  1. User selects place
  2. System returns place details
  3. System displays details

**UC-113: View Map of Activities**
- **Actor**: Tourist
- **Description**: View activities on map
- **Preconditions**: Activities exist with coordinates
- **Postconditions**: Map displayed with activity markers
- **Flow**:
  1. User opens map view
  2. System loads activities with coordinates
  3. System displays on map

**UC-114: Pick Location on Map**
- **Actor**: Organizer
- **Description**: Select activity location on map
- **Preconditions**: Creating/editing activity
- **Postconditions**: Location coordinates selected
- **Flow**:
  1. Organizer opens map picker
  2. Organizer selects location
  3. System returns coordinates
  4. System saves to activity

---

### Settings & Preferences (UC-115 to UC-119)

**UC-115: Manage Account Settings**
- **Actor**: Tourist, Organizer
- **Description**: Manage account preferences
- **Preconditions**: User authenticated
- **Postconditions**: Settings updated
- **Flow**:
  1. User modifies settings
  2. System saves settings
  3. System confirms update

**UC-116: Manage Reminder Preferences**
- **Actor**: Tourist
- **Description**: Configure activity reminders
- **Preconditions**: User authenticated
- **Postconditions**: Preferences saved
- **Flow**:
  1. User configures reminders
  2. System saves preferences
  3. System confirms update

**UC-117: Change Password**
- **Actor**: Tourist, Organizer
- **Description**: Change account password
- **Preconditions**: User authenticated
- **Postconditions**: Password changed
- **Flow**:
  1. User enters current and new password
  2. System validates current password
  3. System updates password
  4. System confirms change

**UC-118: Delete Account**
- **Actor**: Tourist, Organizer
- **Description**: Delete own account
- **Preconditions**: User authenticated
- **Postconditions**: Account deleted
- **Flow**:
  1. User requests deletion
  2. System confirms deletion
  3. System deletes account
  4. System notifies user

**UC-119: Manage Language Settings**
- **Actor**: Tourist, Organizer
- **Description**: Change application language
- **Preconditions**: User authenticated
- **Postconditions**: Language updated
- **Flow**:
  1. User selects language
  2. System saves preference
  3. System applies language

---

## Summary Statistics

- **Total Use Cases**: 119
- **Tourist Use Cases**: ~60
- **Organizer Use Cases**: ~45
- **Admin Use Cases**: ~25
- **Shared Use Cases**: ~30

## Key System Features

1. **Authentication**: Multi-provider auth (Email, Google)
2. **Activity Management**: Full CRUD with AI image generation
3. **Booking System**: Auto-approval with Stripe payment integration
4. **QR Code Check-in**: Secure token-based verification
5. **Real-time Messaging**: Socket.io with media support
6. **Social Feed**: Posts, comments, reactions, mentions
7. **Review System**: Activity and organizer ratings
8. **Notification System**: Comprehensive notification types
9. **Appeal System**: Account suspension/ban appeals
10. **Admin Dashboard**: Full platform management

## Technology Stack

### Backend
- Node.js, Express, MongoDB
- JWT Authentication
- Socket.io (Real-time)
- Cloudinary (Media storage)
- Stripe (Payments)
- Nodemailer (Email)

### Frontend (Mobile)
- Flutter
- Provider (State management)
- Hive (Caching)
- WebRTC (Calls)
- Google Maps

### Admin Dashboard
- React, Vite
- Material-UI, Ant Design

---

**Document Version**: 0.1  
**Last Updated**: 2026-04-28  
**Status**: Initial Release - Comprehensive Use Case Analysis
