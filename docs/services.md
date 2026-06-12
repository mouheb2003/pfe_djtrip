# DJTrip Services Architecture

This document outlines the API service layer used in the DJTrip Flutter mobile application.

## Overview
All services in `lib/services/` act as wrappers around HTTP calls to the Node.js backend. They handle data fetching, token injection (via `ApiClient`), and error parsing.

## Core Services

### 1. `AuthService` (`lib/services/auth_service.dart`)
- **Purpose**: Handles authentication flows (Login, Register, Password Reset).
- **Key Methods**: 
  - `login(email, password)`
  - `register(userData)`
  - `logout()`
  - `getToken()` / `setToken()` using `SharedPreferences`.

### 2. `UserService` (`lib/services/user_service.dart`)
- **Purpose**: Manages the current user's profile and data.
- **Key Methods**:
  - `getProfile()`: Fetches the logged-in user's data.
  - `updateProfile(data)`: Updates bio, avatars, and settings.
  - `getUserById(id)`: Fetches a public profile of another user.

### 3. `ActivityService` (`lib/services/activity_service.dart`)
- **Purpose**: Central hub for fetching and managing activities (events/trips).
- **Key Methods**:
  - `getAllActivities()`: Fetches the explore feed.
  - `getActivityById(id)`: Fetches detailed info.
  - `createActivity(data)`: Used by organizers to post a new activity.
  - `getMyActivities()`: Fetches activities related to the current user.

### 4. `PostService` (`lib/services/post_service.dart`)
- **Purpose**: Manages social feed posts.
- **Key Methods**:
  - `getFeedPosts()`: Gets posts for the Social Tab.
  - `createPost(content, media)`: Publishes a new post.
  - `likePost(id)`: Toggles a like on a post.

### 5. `ReviewService` (`lib/services/review_service.dart`)
- **Purpose**: Handles reviews for activities and organizers.
- **Key Methods**:
  - `addReview(activityId, rating, comment)`
  - `getActivityReviews(activityId)`

### 6. `ApiClient` (`lib/services/api_client.dart`)
- **Purpose**: The foundational HTTP client using `http` package or `dio`. 
- **Features**: 
  - Automatically attaches the `Authorization: Bearer <token>` header to all outgoing requests.
  - Handles global API error catching and formats exceptions.
  - Reads the base URL from `ApiConfig`.

## Error Handling
When a service method fails, it throws a standard Dart `Exception` containing the backend's error message. UI components should wrap service calls in `try/catch` blocks and display errors using `ScaffoldMessenger.of(context).showSnackBar()`.
