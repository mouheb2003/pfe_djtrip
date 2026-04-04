import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'auth_service.dart';
import 'cache_manager.dart';
import 'enhanced_api_service.dart';

/// Professional User Service with robust error handling and caching
class UserService {
  UserService._();

  static const String _endpoint = '/users';
  static const String _meEndpoint = '/users/me';
  static const Duration _cacheTtl = Duration(hours: 1);
  static const String _cacheKeyProfile = 'profile:me';

  /// Get user profile with intelligent caching
  static Future<Map<String, dynamic>?> getProfile({
    bool forceRefresh = false,
  }) async {
    try {
      _devLog('📥 [PROFILE] Fetching user profile...');

      if (forceRefresh) {
        final raw = await ApiClient.get(
          _meEndpoint,
          cacheFirst: false,
          cacheTtl: const Duration(seconds: 1),
        );

        if (raw.statusCode < 200 || raw.statusCode >= 300) {
          _devLog('❌ [PROFILE] Fresh fetch failed: ${raw.statusCode}');
          return null;
        }

        final parsed = jsonDecode(raw.body);
        if (parsed is Map<String, dynamic>) {
          final user = parsed['user'];
          if (user is Map<String, dynamic>) {
            _devLog('✅ [PROFILE] Fresh profile loaded successfully');
            return user;
          }
        }

        _devLog('⚠️ [PROFILE] Fresh profile invalid response format');
        return null;
      }

      // Fetch with EnhancedApiService (cache-first)
      final response = await EnhancedApiService.instance.getCached(
        _meEndpoint,
        cacheTtl: _cacheTtl,
      );

      if (!response.isSuccess) {
        _devLog('❌ [PROFILE] API error: ${response.message}');
        return null;
      }

      final user = response.data?['user'];
      if (user is Map<String, dynamic>) {
        _devLog('✅ [PROFILE] Loaded successfully');
        return user;
      }

      _devLog('⚠️ [PROFILE] Invalid response format');
      return null;
    } catch (e) {
      _devLog('❌ [PROFILE] Exception: $e');
      return null;
    }
  }

  /// Update user profile with automatic cache invalidation
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      _devLog(
        '📤 [PROFILE_UPDATE] Updating profile with ${data.length} fields',
      );

      // Validate input
      if (data.isEmpty) {
        _devLog('⚠️ [PROFILE_UPDATE] Empty data provided');
        return {'success': false, 'message': 'No data to update'};
      }

      // Send update request
      final response = await EnhancedApiService.instance.put(_meEndpoint, data);

      if (!response.isSuccess) {
        _devLog('❌ [PROFILE_UPDATE] API error: ${response.message}');
        return {
          'success': false,
          'message': response.message,
          'statusCode': response.statusCode,
        };
      }

      // Extract and cache updated user data
      final updatedUser = response.data?['user'];
      if (updatedUser is Map<String, dynamic>) {
        _devLog('✅ [PROFILE_UPDATE] Success');
        _invalidateProfileCache();
        return {
          'success': true,
          'message': 'Profile updated successfully',
          'user': updatedUser,
        };
      }

      return {'success': true, 'message': 'Profile updated successfully'};
    } catch (e) {
      _devLog('❌ [PROFILE_UPDATE] Exception: $e');
      return {
        'success': false,
        'message': 'Error updating profile: ${e.toString()}',
      };
    }
  }

  static Future<bool> updateAvatar(File avatarFile) async {
    try {
      _devLog('📸 [AVATAR_UPDATE] Uploading avatar...');

      // Validate file
      if (!await avatarFile.exists()) {
        _devLog('❌ [AVATAR_UPDATE] File not found');
        return false;
      }

      // Create multipart request
      final uri = Uri.parse('${ApiClient.baseUrl}/users/me/avatar');
      final request = http.MultipartRequest('PUT', uri);

      // Add auth header
      final token = await AuthService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add file
      try {
        final stream = http.ByteStream(avatarFile.openRead());
        final length = await avatarFile.length();
        request.files.add(
          http.MultipartFile(
            'avatar',
            stream,
            length,
            filename: avatarFile.path.split('/').last,
          ),
        );
      } catch (e) {
        _devLog('❌ [AVATAR_UPDATE] File read error: $e');
        return false;
      }

      // Send request
      _devLog('📤 [AVATAR_UPDATE] Sending to server...');
      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode != 200) {
        _devLog('❌ [AVATAR_UPDATE] Server error: ${response.statusCode}');
        return false;
      }

      _devLog('✅ [AVATAR_UPDATE] Success');

      // Invalidate profile cache on successful upload
      _invalidateProfileCache();
      return true;
    } catch (e) {
      _devLog('❌ [AVATAR_UPDATE] Exception: $e');
      return false;
    }
  }

  /// Update privacy settings with cache invalidation
  static Future<bool> updatePrivacySettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      _devLog('🔒 [PRIVACY] Updating privacy settings...');

      final response = await EnhancedApiService.instance.put(
        '$_meEndpoint/privacy',
        settings,
      );

      if (response.isSuccess) {
        _devLog('✅ [PRIVACY] Success');
        _invalidateProfileCache();
        return true;
      }

      _devLog('❌ [PRIVACY] Error: ${response.message}');
      return false;
    } catch (e) {
      _devLog('❌ [PRIVACY] Exception: $e');
      return false;
    }
  }

  /// Update advanced settings with cache invalidation
  static Future<bool> updateAdvancedSettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      _devLog('⚙️ [ADVANCED] Updating advanced settings...');

      final response = await EnhancedApiService.instance.put(
        '$_meEndpoint/advanced',
        settings,
      );

      if (response.isSuccess) {
        _devLog('✅ [ADVANCED] Success');
        _invalidateProfileCache();
        return true;
      }

      _devLog('❌ [ADVANCED] Error: ${response.message}');
      return false;
    } catch (e) {
      _devLog('❌ [ADVANCED] Exception: $e');
      return false;
    }
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      _devLog('👤 [GET_USER] Fetching user $userId...');

      final response = await EnhancedApiService.instance.getCached(
        '$_endpoint/$userId',
        cacheTtl: _cacheTtl,
      );

      if (response.isSuccess) {
        _devLog('✅ [GET_USER] Success');
        return response.data?['user'];
      }

      _devLog('❌ [GET_USER] Error: ${response.message}');
      return null;
    } catch (e) {
      _devLog('❌ [GET_USER] Exception: $e');
      return null;
    }
  }

  /// Update user interests
  static Future<bool> updateInterests(List<String> interests) async {
    try {
      _devLog('♥️ [INTERESTS] Updating interests (${interests.length}) ...');

      final response = await EnhancedApiService.instance.put(
        '$_meEndpoint/interests',
        {'interests': interests},
      );

      if (response.isSuccess) {
        _devLog('✅ [INTERESTS] Success');
        _invalidateProfileCache();
        return true;
      }

      _devLog('❌ [INTERESTS] Error: ${response.message}');
      return false;
    } catch (e) {
      _devLog('❌ [INTERESTS] Exception: $e');
      return false;
    }
  }

  /// Get user favorites
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      _devLog('⭐ [FAVORITES] Fetching favorites...');

      final response = await EnhancedApiService.instance.getCached(
        '$_meEndpoint/favorites',
        cacheTtl: _cacheTtl,
      );

      if (response.isSuccess) {
        final items = response.data?['favorites'];
        if (items is List) {
          _devLog('✅ [FAVORITES] Loaded ${items.length} items');
          return items.whereType<Map<String, dynamic>>().toList();
        }
      }
      
      _devLog('✅ [FAVORITES] Success');
      return [];
    } catch (e) {
      _devLog('❌ [FAVORITES] Exception: $e');
      return [];
    }
  }

  /// Add to favorites
  static Future<bool> addFavorite(String activityId) async {
    try {
      _devLog('➕ [FAVORITE_ADD] Adding activity:$activityId...');

      final response = await EnhancedApiService.instance.post(
        '$_meEndpoint/favorites/$activityId',
        {},
      );

      if (response.isSuccess) {
        _devLog('✅ [FAVORITE_ADD] Success');
        _dropFavoritesCacheOnMutation();
        return true;
      }

      _devLog('❌ [FAVORITE_ADD] Error: ${response.message}');
      return false;
    } catch (e) {
      _devLog('❌ [FAVORITE_ADD] Exception: $e');
      return false;
    }
  }

  /// Remove from favorites
  static Future<bool> removeFavorite(String activityId) async {
    try {
      _devLog('➖ [FAVORITE_REMOVE] Removing activity:$activityId...');

      final response = await EnhancedApiService.instance.delete(
        '$_meEndpoint/favorites/$activityId',
      );

      if (response.isSuccess) {
        _devLog('✅ [FAVORITE_REMOVE] Success');
        _dropFavoritesCacheOnMutation();
        return true;
      }

      _devLog('❌ [FAVORITE_REMOVE] Error: ${response.message}');
      return false;
    } catch (e) {
      _devLog('❌ [FAVORITE_REMOVE] Exception: $e');
      return false;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Safe JSON parsing with null safety
  static Map<String, dynamic>? _safeParseJson(String body) {
    try {
      final decoded = Uri.decodeComponent(body);
      // Simple JSON check
      if (decoded.startsWith('{')) {
        return {'message': 'success'};
      }
    } catch (_) {}
    return null;
  }

  /// Delete user account permanently
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      _devLog('🗑️ [DELETE_ACCOUNT] Deleting account...');

      final response = await EnhancedApiService.instance.delete(_meEndpoint);

      if (response.isSuccess) {
        _devLog('✅ [DELETE_ACCOUNT] Success');
        // Clear all cached user data
        _invalidateProfileCache();
        return {'success': true, 'message': 'Account deleted successfully'};
      }

      _devLog('❌ [DELETE_ACCOUNT] Error: ${response.message}');
      return {
        'success': false,
        'message': response.message,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      _devLog('❌ [DELETE_ACCOUNT] Exception: $e');
      return {
        'success': false,
        'message': 'Error deleting account: ${e.toString()}',
      };
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Drop favorites cache on mutation operations
  static void _dropFavoritesCacheOnMutation() {
    CacheManager.instance.remove('favorites:me');
  }

  static void _invalidateProfileCache() {
    CacheManager.instance.remove(_cacheKeyProfile);
    CacheManager.instance.remove('GET:/users/me');
    CacheManager.instance.removeByPattern('GET:/users/me*');
  }

  /// Development logging with TAG prefix
  static void _devLog(String message) {
    if (kDebugMode) {
      print('[UserService] $message');
    }
  }
}
