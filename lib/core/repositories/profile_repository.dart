import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

/// Profile repository for managing user profiles
class ProfileRepository {
  static const String _profilesTable = 'profiles';
  static const String _prosTable = 'pros';
  static const String _storageBucket = 'profile_images';

  /// Fetch current user profile
  static Future<Map<String, dynamic>?> fetchProfile() async {
    // TEMPORARY: Always return mock profile
    return {
      'id': 'mock_user_id',
      'name': 'Mtumiaji Mock',
      'role': 'client',
      'is_verified': true,
      'profile_completed': true,
    };
  }

  /// Fetch profile by user ID
  static Future<Map<String, dynamic>?> fetchProfileById(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch profile by ID error: $e');
      }
      rethrow;
    }
  }

  /// Update user profile
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await Supabase.instance.client
          .from(_profilesTable)
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      if (kDebugMode) {
        print('Update profile error: $e');
      }
      rethrow;
    }
  }

  /// Upload profile image
  static Future<String> uploadProfileImage(File imageFile) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profiles/$fileName';

      await Supabase.instance.client.storage.from(_storageBucket).upload(
        filePath,
        imageFile,
      );

      final publicUrl = Supabase.instance.client.storage
          .from(_storageBucket)
          .getPublicUrl(filePath);

      // Update profile with new image URL
      await updateProfile({'profile_image_url': publicUrl});

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Upload profile image error: $e');
      }
      rethrow;
    }
  }

  /// Get pro profile
  static Future<Map<String, dynamic>?> getProProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from(_prosTable)
          .select()
          .eq('user_id', userId)
          .single();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Get pro profile error: $e');
      }
      return null;
    }
  }

  /// Update pro profile
  static Future<void> updateProProfile(Map<String, dynamic> updates) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await Supabase.instance.client
          .from(_prosTable)
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);
    } catch (e) {
      if (kDebugMode) {
        print('Update pro profile error: $e');
      }
      rethrow;
    }
  }

  /// Create pro profile
  static Future<void> createProProfile(Map<String, dynamic> proData) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final proWithMetadata = {
        ...proData,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from(_prosTable).insert(proWithMetadata);
    } catch (e) {
      if (kDebugMode) {
        print('Create pro profile error: $e');
      }
      rethrow;
    }
  }

  /// Get user role
  static Future<String> getUserRole() async {
    try {
      final profile = await fetchProfile();
      return profile?['role'] ?? 'client';
    } catch (e) {
      if (kDebugMode) {
        print('Get user role error: $e');
      }
      return 'client';
    }
  }

  /// Check if profile is complete
  static Future<bool> isProfileComplete() async {
    // TEMPORARY: Always return true to bypass profile setup
    return true;
  }
}
