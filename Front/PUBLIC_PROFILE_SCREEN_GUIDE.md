# Public Profile Screen - Implementation Guide

## Overview

A modern, unified public profile screen for DJTrip that supports both Tourist and Organizer profiles with premium UI/UX design inspired by Airbnb, Instagram, and Booking.com.

## Features

### ✅ Implemented Features

#### Common Features (Both User Types)
- **Profile Header**
  - Large circular profile picture with shadow
  - Full name display
  - Bio/description
  - Cover image (optional)
  - Online status indicator (green dot = online, grey dot = offline)
  - "Contact Me" primary button
  - Secondary action button (Follow for tourists, Book Now for organizers)

- **Stats Bar**
  - Tourist: Posts, Reviews Given, Participated Activities
  - Organizer: Total Activities, Total Bookings, Rating (⭐)

- **UI/UX**
  - Rounded cards with soft shadows
  - Clean spacing and modern typography
  - Skeleton loaders during data fetch
  - Pull-to-refresh functionality
  - Lazy loading for posts/activities
  - Image caching with CachedNetworkImage
  - Smooth scroll behavior
  - Empty state handling
  - Error state handling

#### Tourist-Specific Features
- **Interests Section**
  - Displayed as colorful chips
  - Auto-fetched from user profile
  - Empty state when no interests

- **Posts Section**
  - Social feed style cards
  - Image, content, likes, comments
  - Relative time display (e.g., "2h ago")
  - Lazy loading with pagination support
  - Empty state when no posts

#### Organizer-Specific Features
- **Specialties Section**
  - Auto-extracted from activities
  - Displayed as blue-themed chips
  - Shows activity types and equipment
  - Empty state when no specialties

- **Languages Section**
  - Spoken languages display
  - Gold-themed chips
  - Fetched from user profile
  - Empty state when no languages

- **Activities Section**
  - Activity cards with image, title, location, rating, price
  - Tap to view activity details
  - Shows first 6 activities with "View All" option
  - Empty state when no activities

## File Structure

```
Front/lib/screens/shared/
├── public_profile_screen.dart          # New unified screen
├── public_organizer_profile_screen.dart  # Old organizer screen (can be deprecated)
└── public_tourist_profile_screen.dart    # Old tourist screen (can be deprecated)
```

## Usage

### Basic Usage

```dart
import 'package:flutter/material.dart';
import '../screens/shared/public_profile_screen.dart';

// Navigate to user's profile
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicProfileScreen(
      userId: 'user_id_here',
    ),
  ),
);

// View own profile (no userId needed)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicProfileScreen(),
  ),
);
```

### Integration Example

```dart
// In an activity card, when user clicks on organizer's avatar
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: activity.organisateur?['_id'],
        ),
      ),
    );
  },
  child: CircleAvatar(
    backgroundImage: NetworkImage(organizerAvatar),
  ),
);

// In a post card, when user clicks on author's name
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: post.authorId,
        ),
      ),
    );
  },
  child: Text(post.authorName),
);
```

## Dependencies

### Added to pubspec.yaml

```yaml
cached_network_image: ^3.3.1
```

### Required Dependencies (Already in project)

- `flutter`
- `cupertino_icons`
- `provider`
- `http`
- `share_plus`
- `google_maps_flutter`
- `socket_io_client`
- `hive`, `hive_flutter`

## API Requirements

The screen uses existing API endpoints:

### User Data
- `GET /users/:id` - Fetch user profile data
  - Returns: `{ user: { id, fullname, avatar, bio, isOnline, centresInteret, languePreferee, noteMoyenne, nombreAvis, userType, ... } }`

### Activities (Organizer)
- `GET /activites` - Fetch all activities (filtered client-side by organizer ID)

### Posts (Tourist)
- `GET /posts/feed` - Fetch feed posts (filtered client-side by author ID)

### Bookings (Tourist - Own Profile)
- `GET /inscriptions/me` - Fetch user's bookings (for participated activities count)

## Data Models Used

### UserModel
```dart
class UserModel {
  final String id;
  final String fullname;
  final String email;
  final String userType; // 'Touriste' | 'Organisator'
  final String? avatar;
  final String? bio;
  final bool isOnline;
  final List<String> centresInteret;
  final String languePreferee;
  final double noteMoyenne;
  final int nombreAvis;
  
  bool get isTouriste => userType == 'Touriste';
  bool get isOrganisator => userType == 'Organisator';
}
```

### ActivityModel
```dart
class ActivityModel {
  final String id;
  final String titre;
  final String description;
  final String typeActivite;
  final String lieu;
  final double prix;
  final List<String> photos;
  final List<String> equipementsInclus;
  final double noteMoyenne;
  final int nombreAvis;
  final int nombreReservations;
  final Map<String, dynamic>? organisateur;
}
```

### PostModel
```dart
class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? imageUrl;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
}
```

## Customization

### Theme Colors

The screen uses `AppColors` from `app_theme.dart`:

```dart
// Modify in lib/theme/app_theme.dart
class AppColors {
  static const Color primary = Color(0xFF0066CC);
  static const Color secondary = Color(0xFFFF6B1A);
  static const Color accent = Color(0xFFFFB31B);
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  // ... more colors
}
```

### Text Styles

Uses `AppTextStyles` from `app_theme.dart` for consistent typography.

## Performance Optimizations

1. **Image Caching**: Uses `CachedNetworkImage` for efficient image loading and caching
2. **Lazy Loading**: Posts and activities are loaded on-demand with pagination support
3. **Skeleton Loaders**: Prevents UI flicker during data fetch
4. **Pull-to-Refresh**: Efficient data refresh without full page reload
5. **Scroll Controller**: Optimized scroll detection for loading more content

## Migration from Old Screens

### Replacing Old Profile Screens

1. **Update Navigation Calls**

```dart
// OLD
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicOrganizerProfileScreen(
      organizerId: organizerId,
    ),
  ),
);

// NEW
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicProfileScreen(
      userId: organizerId,
    ),
  ),
);
```

2. **Update Tourist Profile Navigation**

```dart
// OLD
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicUserProfileScreen(
      userId: userId,
    ),
  ),
);

// NEW
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PublicProfileScreen(
      userId: userId,
    ),
  ),
);
```

3. **Optional: Deprecate Old Screens**
   - Keep old screens temporarily for backward compatibility
   - Add deprecation warnings
   - Gradually migrate all navigation calls
   - Remove old screens after migration is complete

## Testing Checklist

Before deploying, verify:

- [ ] Profile loads correctly for tourists
- [ ] Profile loads correctly for organizers
- [ ] Online status indicator displays correctly
- [ ] Stats bar shows correct numbers
- [ ] Tourist interests display as chips
- [ ] Organizer specialties display as chips
- [ ] Organizer languages display as chips
- [ ] Posts load and display correctly
- [ ] Activities load and display correctly
- [ ] Pull-to-refresh works
- [ ] Lazy loading works for scroll
- [ ] Empty states display correctly
- [ ] Contact Me button opens chat
- [ ] Share functionality works
- [ ] Images cache properly
- [ ] Skeleton loaders display during load
- [ ] No console errors
- [ ] Navigation works from other screens

## Future Enhancements

### Optional Features (Not Yet Implemented)

1. **Verification Badge**
   - Add verified badge for organizers
   - Display checkmark icon next to name

2. **Reviews Preview**
   - Show top 3 reviews
   - Link to full reviews page

3. **Map Preview**
   - Show map of activity locations
   - Interactive map for organizers

4. **Follow System**
   - Implement follow/unfollow functionality
   - Show follower/following counts

5. **WebSocket Integration**
   - Real-time online status updates
   - Live notification of new posts/activities

6. **Advanced Filtering**
   - Filter activities by date, price, rating
   - Filter posts by date, likes

7. **Analytics**
   - Profile view count
   - Engagement metrics

## Troubleshooting

### Common Issues

**Issue: Images not loading**
- Check if `cached_network_image` is installed: `flutter pub get`
- Verify image URLs are correct
- Check network connectivity

**Issue: Online status always offline**
- Verify backend returns `isOnline` field
- Check if WebSocket integration is needed

**Issue: Empty states not showing**
- Verify data fetch is working
- Check console for errors
- Ensure API endpoints are accessible

**Issue: Pull-to-refresh not working**
- Verify `RefreshIndicator` is properly wrapped
- Check if `_onRefresh` method is called

## Support

For issues or questions:
1. Check this guide
2. Review the code in `public_profile_screen.dart`
3. Check API endpoints in backend
4. Verify data models match API responses

## Summary

The new `PublicProfileScreen` provides a modern, unified solution for displaying user profiles in DJTrip. It handles both Tourist and Organizer profiles with role-specific content, premium UI/UX, and performance optimizations.

Key benefits:
- ✅ Single screen for both user types
- ✅ Modern, premium design
- ✅ Efficient data fetching with caching
- ✅ Smooth user experience with loaders
- ✅ Easy to integrate and customize
- ✅ Production-ready code
