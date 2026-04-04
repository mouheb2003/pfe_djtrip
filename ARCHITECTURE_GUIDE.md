# Flutter Performance Architecture - Complete Refactoring Guide

## 🎯 Overview

This guide documents the complete refactoring of the DJTrip Flutter app to eliminate performance issues, prevent API call spam, and ensure stable caching behavior.

---

## 📦 New Architecture Components

### 1. **CacheManager** (`cache_manager.dart`)
**Purpose**: Advanced memory + persistent Hive cache with smart TTL management

**Key Features**:
- ✅ Memory cache for fast access (< 1ms)
- ✅ Persistent Hive storage for offline support
- ✅ Smart TTL (Time To Live) with auto-expiration
- ✅ Prevents cache overwriting with empty/null data
- ✅ Pattern-based cache invalidation
- ✅ Access counting for analytics

**Usage**:
```dart
// Get cached data
final data = CacheManager.instance.get<List>('posts');

// Set with TTL
await CacheManager.instance.set(
  'posts',
  postsList,
  ttl: Duration(minutes: 5),
  overwriteIfExists: false, // Don't overwrite valid cache
);

// Invalidate by pattern
await CacheManager.instance.removeByPattern('GET:/posts/*');
```

---

### 2. **NetworkHelper** (`network_helper.dart`)
**Purpose**: Automatic retry logic with exponential backoff

**Key Features**:
- ✅ Automatic retry on server errors (500+)
- ✅ Exponential backoff: 500ms → 1s → 2s
- ✅ Timeout protection (15s default)
- ✅ Distinguishes between retryable and non-retryable errors
- ✅ Detailed attempt logging

**Usage**:
```dart
final result = await NetworkHelper.executeWithRetry(
  () => http.get(uri),
  parseSuccess: (body) => jsonDecode(body),
  endpoint: '/posts/feed',
  maxRetries: 2,
);

if (result.success) {
  print('Data: ${result.data}');
  print('Attempts: ${result.attemptNumber}');
} else {
  print('Error: ${result.error}');
}
```

---

### 3. **EnhancedApiService** (`enhanced_api_service.dart`)
**Purpose**: Unified API service with cache-first strategy and automatic invalidation

**Key Features**:
- ✅ Cache-first approach for GET requests
- ✅ Smart cache invalidation for POST/PUT/PATCH/DELETE
- ✅ Integrated retry logic
- ✅ Comprehensive logging
- ✅ Unified response wrapper

**Usage**:
```dart
// GET with caching
final response = await EnhancedApiService.instance.getCached(
  '/posts/feed',
  cacheTtl: Duration(minutes: 5),
);

if (response.isSuccess) {
  final posts = response.data;
}

// POST with automatic cache invalidation
final response = await EnhancedApiService.instance.post(
  '/posts',
  {'content': 'My post', 'images': []},
);
// ✅ Automatically invalidates: GET:/posts/*
```

---

### 4. **BaseDataScreen** (`base_data_screen.dart`)
**Purpose**: Foundation class for all data-loading screens with standard patterns

**Key Features**:
- ✅ Prevents multiple simultaneous API calls via `_isFetching` flag
- ✅ Automatic loading/error/empty state handling
- ✅ Pull-to-refresh support
- ✅ Error retry mechanism
- ✅ Standard UI patterns

**Usage**:
```dart
class PostsListScreen extends BaseDataScreen<List<Post>> {
  @override
  Future<List<Post>> loadData() async {
    final response = await EnhancedApiService.instance.getCached('/posts');
    return response.data?['posts'] ?? [];
  }

  @override
  Widget buildDataWidget(BuildContext context, List<Post> posts) {
    return ListView(
      children: posts.map((p) => PostCard(post: p)).toList(),
    );
  }
}
```

---

## 🔧 Migration Guide

### Before (❌ BAD):
```dart
class OldScreen extends StatefulWidget {
  @override
  State<OldScreen> createState() => _OldScreenState();
}

class _OldScreenState extends State<OldScreen> {
  late Future<List> posts; // ❌ Recreated on every rebuild!

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: posts, // ❌ PROBLEM: Future recreated each build
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListView(children: _buildPosts(snapshot.data));
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

**Problems**:
- 🔴 Future recreated on every rebuild
- 🔴 Possible multiple simultaneous API calls
- 🔴 No caching layer
- 🔴 No retry logic
- 🔴 No cache invalidation

---

### After (✅ GOOD):
```dart
class NewScreen extends BaseDataScreen<List> {
  @override
  Future<List> loadData() async {
    // Called only ONCE in initState
    final resp = await EnhancedApiService.instance.getCached('/posts');
    return resp.data?['posts'] ?? [];
  }

  @override
  Widget buildDataWidget(BuildContext context, List data) {
    return ListView(children: data.map(_buildItem).toList());
  }
}
```

**Improvements**:
- ✅ Data loads only once (in initState)
- ✅ Automatic caching with 5min TTL
- ✅ Automatic retry (2 attempts)
- ✅ State management handled by base class
- ✅ No FutureBuilder rebuilding issues
- ✅ Prevents simultaneous API calls

---

## 📋 Checklist for Refactoring Existing Screens

### For GET endpoints (load data):
- [ ] Extend `BaseDataScreen<T>`
- [ ] Implement `loadData()` - call `EnhancedApiService.getCached()`
- [ ] Implement `buildDataWidget()`
- [ ] Remove manual `FutureBuilder`
- [ ] Remove manual `isEmpty` checks
- [ ] Remove manual error handling

### For POST/PUT/PATCH/DELETE endpoints (mutate data):
- [ ] Use `EnhancedApiService.post()` instead of `ApiClient.post()`
- [ ] ✅ Cache is automatically invalidated
- [ ] Show loading indicator during mutation
- [ ] Handle errors with user-friendly messages
- [ ] Refresh dependent data after successful mutation

### For complex screens with multiple data sources:
- [ ] Keep separate state per data source
- [ ] Use different cache keys
- [ ] Coordinate refresh operations
- [ ] Show loading state only for new data, not cached data

---

## 🛡️ Cache Strategy

### GET Requests:
```
1. Check memory cache
2. If found & not expired → return immediately
3. If not found/expired → fetch from network
4. On success → cache result (5 min TTL)
5. On error → return cached data if available (fallback)
```

### POST/PUT/PATCH/DELETE:
```
1. Execute mutation
2. On success → automatically invalidate related GET caches
3. Example: POST /posts → clears cache for GET:/posts/*
```

### Cache Invalidation Rules:
```
- GET requests: DO NOT invalidate (read-only)
- POST: Invalidates /collection/* cache
- PUT: Invalidates /resource/* and /collection/* cache
- DELETE: Invalidates /resource/* and /collection/* cache
```

---

## 📊 Debug Logging

All services log important events prefixed by type:

```
[API] ✅ EnhancedApiService initialized
[API] [API CACHE HIT] /posts/feed
[API] [API FETCH] GET /posts/feed
[API] [API SUCCESS] GET /posts/feed (attempt 1)
[NETWORK] [RETRY] START attempt 1/3 - /posts/feed
[NETWORK] [RETRY] SUCCESS after 1 attempt(s) - /posts/feed
[CACHE] 💾 [CACHE SAVED] GET:/posts/feed (TTL: 300s)
[CACHE] 🗑️ [CACHE REMOVED PATTERN] GET:/posts/* (5 entries)
[BaseDataScreen] ✅ Data loaded successfully
[BaseDataScreen] ❌ Error loading data: TimeoutException
```

---

## 🚀 Quick Start

1. **Initialize services in main.dart or app.dart**:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.instance.initialize();
  await EnhancedApiService.instance.initialize();
  runApp(const MyApp());
}
```

2. **Refactor a simple screen** (e.g., PostsListScreen):
```dart
class PostsListScreen extends BaseDataScreen<List> {
  @override
  Future<List> loadData() async {
    final res = await EnhancedApiService.instance.getCached('/posts');
    return res.data?['posts'] ?? [];
  }

  @override
  Widget buildDataWidget(BuildContext context, List posts) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(children: posts.map(_buildPost).toList()),
    );
  }
}
```

3. **Test with network throttling** (in DevTools):
   - Check that data loads from cache on second visit
   - Verify retry works on network errors
   - Confirm no duplicate API calls

---

## ✅ Expected Results

### Before Refactoring:
- ❌ Multiple API calls for same data
- ❌ Flickering UI (empty → loaded → empty cycles)
- ❌ No recovery on network errors
- ❌ Slow first load (no cache)

### After Refactoring:
- ✅ Zero duplicate API calls
- ✅ Stable UI with cached data on revisit
- ✅ Automatic retry on server errors
- ✅ Fast loads from cache
- ✅ Offline support (shows cached data)
- ✅ Smart cache invalidation

---

## 🎯 Summary

| Metric | Before | After |
|--------|--------|-------|
| API calls on screen visit #2 | 1-3× | 0 (cached) |
| Rebuild cycles | 3-5 | 1 |
| First load time | Slow | Fast |
| Network error recovery | None | Auto-retry 2× |
| Offline support | None | Shows cache |
| Maintenance | Complex | Simple (BaseDataScreen) |

---

## 📚 File Locations

- `services/cache_manager.dart` - Cache layer
- `services/network_helper.dart` - Retry logic
- `services/enhanced_api_service.dart` - Unified API
- `base/base_data_screen.dart` - Screen foundation
- `config/api_config.dart` - API configuration

---

**Last Updated**: 2026-04-04  
**Version**: 1.0-beta  
**Status**: Ready for implementation
