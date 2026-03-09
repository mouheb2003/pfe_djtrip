import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/activite.dart';
import 'storage_service.dart';

class ActivityService {
  /// Get all activities for the current organizer
  static Future<Map<String, dynamic>> getMyActivities() async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/activites/my-activities'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<Activite> activities = (data['activities'] as List)
            .map((json) => Activite.fromJson(json))
            .toList();

        return {'success': true, 'activities': activities};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch activities',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Get archived activities (past end date)
  static Future<Map<String, dynamic>> getArchivedActivities() async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/activites/archived'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<Activite> activities = (data['activities'] as List)
            .map((json) => Activite.fromJson(json))
            .toList();

        return {'success': true, 'activities': activities};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch archived activities',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Create a new activity
  static Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> activityData, {
    List<String>? imagePaths,
  }) async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/activites'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      activityData.forEach((key, value) {
        if (value != null) {
          if (value is Map) {
            request.fields[key] = jsonEncode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Add image files
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (var imagePath in imagePaths) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', imagePath),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        ApiConfig.connectionTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      print('📦 Create Activity Response Status: ${response.statusCode}');
      print('📦 Create Activity Response Data: $data');

      if (response.statusCode == 201) {
        final activity = Activite.fromJson(data['activite']);
        return {
          'success': true,
          'message': data['message'],
          'activity': activity,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create activity',
        };
      }
    } catch (e) {
      print('❌ Error in createActivity: $e');
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Update an existing activity
  static Future<Map<String, dynamic>> updateActivity(
    String activityId,
    Map<String, dynamic> activityData, {
    List<String>? imagePaths,
    bool keepExistingPhotos = true,
  }) async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.baseUrl}/activites/$activityId'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      activityData.forEach((key, value) {
        if (value != null) {
          if (value is Map) {
            request.fields[key] = jsonEncode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Add keepExistingPhotos flag
      request.fields['keepExistingPhotos'] = keepExistingPhotos.toString();

      // Add image files
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (var imagePath in imagePaths) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', imagePath),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        ApiConfig.connectionTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final activity = Activite.fromJson(data['activite']);
        return {
          'success': true,
          'message': data['message'],
          'activity': activity,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update activity',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Delete an activity
  static Future<Map<String, dynamic>> deleteActivity(String activityId) async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/activites/$activityId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Activity deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete activity',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Get a single activity by ID
  static Future<Map<String, dynamic>> getActivityById(String activityId) async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/activites/$activityId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final activity = Activite.fromJson(data['activity']);
        return {'success': true, 'activity': activity};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch activity',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Get all activities (for tourists - upcoming and in progress only)
  static Future<Map<String, dynamic>> getAllActivities() async {
    try {
      // Use backend filter for better performance and consistency
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/activites?temporalite=disponibles'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      print('📦 getAllActivities Response status: ${response.statusCode}');
      print('📦 getAllActivities Response data keys: ${data.keys}');

      if (response.statusCode == 200) {
        // Backend returns 'activities'
        final activitiesList = data['activities'];
        if (activitiesList == null) {
          print('⚠️ No activities found in response');
          return {'success': true, 'activities': <Activite>[]};
        }

        print(
          '📊 Total activities from backend: ${(activitiesList as List).length}',
        );

        final List<Activite> activities = (activitiesList as List)
            .map((json) => Activite.fromJson(json))
            .toList();

        print('✅ Activities parsed successfully: ${activities.length}');
        if (activities.isNotEmpty) {
          print('   Sample activity: ${activities.first.titre}');
          print('   Date fin: ${activities.first.dateFin.toIso8601String()}');
          print('   Current time: ${DateTime.now().toIso8601String()}');
        }

        return {'success': true, 'activities': activities};
      } else {
        print('❌ Error response: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch activities',
        };
      }
    } catch (e) {
      print('❌ Error in getAllActivities: $e');
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Get tourist's past activities (activities they participated in that have ended)
  static Future<Map<String, dynamic>> getMyPastActivities() async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      // First, get all tourist's approved inscriptions
      final inscriptionsResponse = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/inscriptions/mes-inscriptions?statut=approuvee',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      if (inscriptionsResponse.statusCode != 200) {
        return {'success': false, 'message': 'Failed to fetch inscriptions'};
      }

      final inscriptionsData = jsonDecode(inscriptionsResponse.body);
      final List<dynamic> inscriptions = inscriptionsData['inscriptions'] ?? [];

      if (inscriptions.isEmpty) {
        return {'success': true, 'activities': []};
      }

      // Get activity IDs
      final activityIds = inscriptions
          .map(
            (inscription) => inscription['activite_id'] is String
                ? inscription['activite_id']
                : inscription['activite_id']?['_id'],
          )
          .where((id) => id != null)
          .toSet()
          .toList();

      if (activityIds.isEmpty) {
        return {'success': true, 'activities': []};
      }

      // Fetch activities and filter for past ones
      final List<Activite> pastActivities = [];
      final now = DateTime.now();

      for (var activityId in activityIds) {
        try {
          final activityResponse = await http
              .get(
                Uri.parse('${ApiConfig.baseUrl}/activites/$activityId'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(ApiConfig.connectionTimeout);

          if (activityResponse.statusCode == 200) {
            final activityData = jsonDecode(activityResponse.body);
            final activity = Activite.fromJson(activityData['activity']);

            // Only include activities that have ended
            if (activity.dateFin.isBefore(now)) {
              pastActivities.add(activity);
            }
          }
        } catch (e) {
          print('Error fetching activity $activityId: $e');
        }
      }

      return {'success': true, 'activities': pastActivities};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
