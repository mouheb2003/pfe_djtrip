# Detailed Feature Reference (For AI & Developers)

This document provides deep context on how specific features function within DJTrip, enabling accurate responses to user questions.

## 1. The Booking Flow (Enrollment)
When a tourist wants to join an activity:
- They tap the activity in the **Explore** tab to view the `ActivityDetailScreen`.
- They tap the **"Book Now"** (or similar) button.
- The app checks if there are available spots (`places_disponibles`).
- The app calls the backend `InscriptionService.createInscription(activityId)`.
- If successful, the activity is added to the user's **My Activities** tab. The organizer is notified via real-time sockets.

## 2. Notification System
DJTrip uses a unified notification system:
- **Types of Notifications**: New messages, booking confirmations, new followers, new posts from followed users, and system alerts.
- **Delivery**: Notifications are delivered in real-time via Socket.io when the app is open. If closed, push notifications (FCM) are triggered.
- **Settings**: Users can customize their notification preferences in the `SettingsScreen`, toggling Push, Email, or SMS notifications.

## 3. Social Elements (Posts & Reviews)
- **Posts**: Users can create posts sharing images and text about their experiences. Posts appear in the global feed. Users can like and comment on these posts.
- **Following System**: Tourists can follow Organizers (or other Tourists) to prioritize their content in the feed.
- **Reviews & Ratings**: After an activity ends, tourists can leave a review (1 to 5 stars) and a written comment. This rating heavily impacts the Organizer's overall score displayed on their public profile.

## 4. Maps & Geolocation
- The `ExploreTab` includes an interactive map. 
- Organizers define the exact latitude/longitude when creating an activity.
- The map automatically centers on Djerba but allows users to explore. Markers indicate activity types (e.g., using different icons for sports vs. culture).
- Tourists can filter the map by category to find exactly what they are looking for.

## 5. Security & Privacy
- **JWT Tokens**: All API communication is secured using JSON Web Tokens.
- **Profile Privacy**: Organizers cannot see the "Leave a Review" button on other public profiles. Certain actions are restricted by role.
- **Data Protection**: User passwords are encrypted (bcrypt) in the database.

## Answering Questions Effectively
*Note to AI Assistant: When a user asks how to do something, use this knowledge to guide them to the correct screen. For example, if they ask how to change their bio, tell them to go to the Profile Tab -> Settings -> Edit Profile. If they ask how to cancel a booking, tell them to go to the My Activities tab, select the activity, and look for the cancel option.*
