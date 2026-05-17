# 🎨 DJTrip - Interface & Component Catalog

This document provides a comprehensive list of all screens, UI components, buttons, and icons within the DJTrip application. This serves as a reference for the AI Assistant and developers to understand the visual and interactive logic of the platform.

---

## 1. 📱 Tourist Application (Flutter)

### 1.1 Core Navigation (TouristMainScreen)
- **Component**: Floating Bottom Navigation Bar
- **Tabs**:
  1. **Home**: `Icons.home_outlined` (active: `Icons.home`)
  2. **Explore**: `Icons.explore_outlined` (active: `Icons.explore`)
  3. **Bookings**: `Icons.confirmation_number_outlined` (active: `Icons.confirmation_number`)
  4. **Messages**: `Icons.chat_bubble_outline` (active: `Icons.chat_bubble`)
  5. **Profile**: `Icons.person_outline` (active: `Icons.person`)
- **Global Elements**:
  - **AI Chatbot FAB**: Floating Action Button located above the navigation bar.
    - **Icon**: `Icons.smart_toy` (Orange circle)
    - **Position**: Bottom-right, offset from navigation bar.
    - **Action**: Opens `AiChatScreen`.

### 1.2 Home Tab (HomeTab)
- **Purpose**: Main discovery dashboard for tourists.
- **Key Sections**:
  - **Hero Section**: Displays Djerba hero image with greeting.
  - **Search Bar**: 
    - **Icon**: `Icons.search`
    - **Placeholder**: "Search destinations, activities..."
    - **Clear Button**: `Icons.clear` (appears when typing)
  - **Djerba Banner**: Large card with title "Djerba" and subtitle "The Pearl of the Mediterranean".
  - **Top Rated Places**: Horizontal list of place cards.
    - **Action**: "View All" button (`Icons.arrow_forward`).
  - **Categories**: Horizontal lists for "Beaches", "Restaurants", "Hotels", etc.
  - **Top Activities**: Horizontal list of activity cards.
    - **Action**: "See all" button (`Icons.arrow_forward`).
- **Icons used**: `Icons.star` (ratings), `Icons.place` (location), `Icons.event` (activities).

### 1.3 Explore Tab (ExploreTab)
- **Purpose**: Advanced search and filtering for all activities.
- **Key Components**:
  - **Search Input**: Large search field at the top.
  - **Filter Chips**: Scrollable row of categories (All, Beach, Desert, Culture, etc.).
  - **Activity Grid/List**: Vertical list of activities.
  - **Map Toggle**: Button to switch between list view and map view.
    - **Icon**: `Icons.map` / `Icons.list`
- **Buttons**:
  - **Filter Button**: Opens filter modal (`Icons.tune`).

### 1.4 Booking Details (BookingDetailScreen)
- **Purpose**: View status and details of a specific booking.
- **Key Components**:
  - **Status Badge**: Colored label (Pending, Approved, Verified, Cancelled).
  - **QR Code Section**: Displays unique QR code for check-in.
    - **Action**: "Download QR" or "Share QR".
  - **Activity Info**: Card with activity photo, title, date, and participants.
  - **Organizer Info**: Profile snippet with "Message" button.
- **Buttons**:
  - **Cancel Booking**: Large red button at the bottom (only if allowed).
  - **Contact Organizer**: `Icons.chat` button.
  - **Write Review**: Appears after activity is verified (`Icons.star_outline`).

---

## 2. 💼 Organizer Application (Flutter)

### 2.1 Core Navigation (OrganizerMainScreen)
- **Tabs**:
  1. **Activities**: `Icons.assignment_outlined` (active: `Icons.assignment`)
  2. **Explore**: `Icons.explore_outlined` (active: `Icons.explore`)
  3. **Network**: `Icons.people_outline` (active: `Icons.people`)
  4. **Messages**: `Icons.chat_bubble_outline` (active: `Icons.chat_bubble`)
  5. **Profile**: `Icons.person_outline` (active: `Icons.person`)
- **Global Elements**:
  - **AI Chatbot FAB**: Floating Action Button above the navigation bar.
    - **Icon**: `Icons.smart_toy` (Orange)

### 2.2 Activity Management (MyActivitiesTab)
- **Purpose**: List and manage activities created by the organizer.
- **Sub-Tabs**:
  - **Active**: Current/Upcoming activities.
  - **Ongoing**: Currently happening.
  - **Past**: Completed activities.
- **Key Buttons**:
  - **Create Activity FAB**: Large "+" button (`Icons.add`).
  - **Verify Booking Button**: Floating button to open scanner (`Icons.qr_code_scanner`).
  - **Edit Activity**: `Icons.edit` on activity card.
  - **Delete Activity**: `Icons.delete` on activity card.

### 2.3 QR Scanner (VerifyBookingScreen)
- **Purpose**: Scan tourist QR codes for check-in.
- **UI Elements**:
  - **Camera View**: Central scanning area.
  - **Flash Toggle**: `Icons.flash_on` / `Icons.flash_off`.
  - **Manual Entry**: Text field to enter booking ID manually.
- **Feedback**:
  - **Success Overlay**: Green checkmark with "Check-in Successful".
  - **Error Overlay**: Red cross with reason (e.g., "Already Checked In").

---

## 3. 💬 Shared Communication Screens

### 3.1 Chat Screen (ChatConversationScreen)
- **Key Buttons/Icons**:
  - **Audio Call**: `Icons.phone` in App Bar.
  - **Video Call**: `Icons.videocam` in App Bar.
  - **Attachment**: `Icons.add` or `Icons.attach_file`.
  - **Camera**: `Icons.camera_alt` for instant photo.
  - **Voice Message**: `Icons.mic` (hold to record).
  - **Send**: `Icons.send`.
- **AI Features**:
  - **AI Magic Wand**: `Icons.auto_awesome` on text field.
    - **Actions**: "Translate", "Improve", "Rewrite".

### 3.2 AI Assistant (AiChatScreen)
- **Key Elements**:
  - **Bot Avatar**: `Icons.smart_toy` (Orange).
  - **Suggestion Chips**: Quick questions like "How to book?".
  - **Sources**: List of documentation files used for the answer.
- **Buttons**:
  - **Clear Chat**: `Icons.refresh`.
  - **Info**: `Icons.info_outline`.

---

## 4. ⚙️ Settings & Profile

### 4.1 Profile Tabs (Tourist/Organizer)
- **Header**: Profile photo, cover photo, name, bio.
- **Statistics**: Followers, Following, Posts, Bookings.
- **Action Menu (App Bar)**:
  - **Popup Menu**: `Icons.more_vert`.
    - **Options**: Edit Profile, Settings, Logout.

### 4.2 Settings Screen
- **Categories**:
  - **Account**: `Icons.person_outline`.
  - **Privacy**: `Icons.lock_outline`.
  - **Notifications**: `Icons.notifications_none`.
  - **Language**: `Icons.language`.
  - **Help**: `Icons.help_outline`.

---

## 5. 🛠️ Admin Dashboard (React)

### 5.1 Sidebar Navigation
- **Dashboard**: `Icons.Dashboard`
- **Users**: `Icons.People`
- **Activities**: `Icons.Event`
- **Bookings**: `Icons.Assignment`
- **Appeals**: `Icons.Gavel`
- **Payments**: `Icons.Payment`

### 5.2 User List Table
- **Columns**: Name, Email, Role, Status, Created At, Actions.
- **Action Buttons**:
  - **View Details**: `Icons.Visibility` (Eye icon).
  - **Suspend**: `Icons.Block`.
  - **Activate**: `Icons.CheckCircle`.
  - **Ban**: `Icons.Gavel`.

---

## 6. 🎨 Visual Consistency & Theme
- **Primary Color**: `#167BFF` (Blue) - Used for primary buttons and active states.
- **Accent Color**: `#FF9800` (Orange) - Used for AI features and warnings.
- **Background**: `#F3F4F6` (Light Grey).
- **Typography**: Inter (Modern sans-serif).
- **Icons**: Material Icons (Outlined for inactive, Filled for active).
