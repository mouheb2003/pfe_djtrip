# DJTrip Screens Architecture

This document outlines the screen architecture in the DJTrip Flutter mobile application.

## 1. Authentication Screens (`lib/screens/auth/`)
- `LoginScreen`: Handles user login (email/password). Includes a toggle between Tourist and Organizer roles.
- `RegisterScreen`: Handles new user registration. Supports collecting role-specific information.
- `ForgotPasswordScreen`: Initiates the password recovery process.

## 2. Tourist Screens (`lib/screens/tourist/`)
The Tourist interface is centered around the `TouristMainScreen` which uses a Bottom Navigation Bar to switch between tabs:
- **ExploreTab**: The main discovery feed for activities and places. Displays categories, map with markers, and a list of upcoming activities.
- **MyActivitiesTab**: Shows activities the tourist has booked or saved. Segmented into "Upcoming" and "Past".
- **SocialTab**: A feed of posts from organizers and other tourists. Supports liking and commenting.
- **TouristProfileTab**: The user's personal profile showing their avatar, cover photo, bio, and settings access.

## 3. Organizer Screens (`lib/screens/organizer/`)
The Organizer interface uses `OrganizerMainScreen` with tabs tailored for activity management:
- **OrganizerExploreTab**: A feed of activities similar to the tourist view but optimized for organizers to see what else is happening.
- **ManageActivitiesTab**: Allows the organizer to view, edit, and manage their own created activities and see participant lists.
- **CreateActivityScreen**: A multi-step form to create a new activity (Title, Description, Date, Price, Location, Photos).
- **OrganizerProfileTab**: Shows the organizer's public persona, their created activities, ratings, and reviews.

## 4. Shared Screens (`lib/screens/shared/`)
- `ActivityDetailScreen`: Shows detailed information about an activity, including a map, pricing, and a "Book Now" button.
- `PublicProfileScreen`: A generalized profile screen to view other users (tourists or organizers).
- `SettingsScreen`: General app settings (Language, Theme, Notifications).
- `ChatConversationScreen`: Private messaging interface between users.
- `CommentsScreen`: For viewing and posting comments on activities or social posts.

## User Interface Guidelines
- Use the central `AppTheme` for colors and typography to maintain consistency.
- Implement responsive design using `flutter_screenutil`.
- Ensure all screens properly handle loading states (`CircularProgressIndicator`) and error states using `SnackBar`.
