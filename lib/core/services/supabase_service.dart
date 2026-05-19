import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kazipoa/core/config/supabase_config.dart';

/// Supabase service for all backend operations with local fallback
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  // Table names
  static const String _usersTable = 'users';
  static const String _servicesTable = 'services';
  static const String _bookingsTable = 'bookings';
  static const String _chatsTable = 'chats';
  static const String _messagesTable = 'messages';
  static const String _kaziliveTable = 'kazilive_sessions';
  static const String _storageBucket = 'profile_images';

  static Map<String, dynamic>? _mockCurrentUser;

  static void setMockCurrentUser(Map<String, dynamic>? user) {
    _mockCurrentUser = user;
  }

  static bool get _useMock => SupabaseConfig.url.isEmpty || 
      SupabaseConfig.url.contains('your_supabase_project_url') ||
      SupabaseConfig.anonKey.isEmpty ||
      SupabaseConfig.anonKey.contains('your_supabase_anon_key');

  /// Get current user
  static User? get currentUser {
    // TEMPORARY: Always return mock user to bypass auth
    return User(
      id: 'mock_user_id',
      email: 'mock@domain.com',
      createdAt: DateTime.now().toIso8601String(),
      appMetadata: {},
      userMetadata: {'full_name': 'Mtumiaji Mock'},
      aud: 'authenticated',
    );
  }

  /// Authentication Methods
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    if (_useMock) {
      final userObj = User(
        id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        createdAt: DateTime.now().toIso8601String(),
        appMetadata: {},
        userMetadata: {'full_name': email.split('@').first},
        aud: 'authenticated',
      );
      return AuthResponse(
        session: Session(
          accessToken: 'mock_access_token',
          tokenType: 'bearer',
          user: userObj,
        ),
        user: userObj,
      );
    }

    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
    if (_useMock) {
      final userObj = User(
        id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        createdAt: DateTime.now().toIso8601String(),
        appMetadata: {},
        userMetadata: {'full_name': name},
        aud: 'authenticated',
      );
      return AuthResponse(
        session: Session(
          accessToken: 'mock_access_token',
          tokenType: 'bearer',
          user: userObj,
        ),
        user: userObj,
      );
    }

    final result = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (result.user != null) {
      // Create user profile
      await _client.from(_usersTable).insert({
        'id': result.user!.id,
        'name': name,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'profile_completed': false,
      });
    }
    
    return result;
  }

  static Future<void> signOut() async {
    if (_useMock) {
      _mockCurrentUser = null;
      return;
    }
    await _client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    if (_useMock) return;
    await _client.auth.resetPasswordForEmail(email);
  }

  static Stream<AuthState> authStateChanges() {
    if (_useMock) {
      return const Stream<AuthState>.empty();
    }
    return _client.auth.onAuthStateChange;
  }

  /// User Profile Methods
  static Future<void> updateUserProfile({
    String? name,
    String? phone,
    String? bio,
    String? location,
    bool? isPro,
    Map<String, dynamic>? services,
    bool? profileCompleted,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final profilesStr = prefs.getString('mock_profiles') ?? '{}';
      final Map<String, dynamic> profiles = jsonDecode(profilesStr);
      final profile = profiles[user.id] ?? {};
      
      if (name != null) profile['name'] = name;
      if (phone != null) profile['phone'] = phone;
      if (bio != null) profile['bio'] = bio;
      if (location != null) profile['location'] = location;
      if (isPro != null) profile['is_pro'] = isPro;
      if (services != null) profile['services'] = services;
      if (profileCompleted != null) profile['profile_completed'] = profileCompleted;
      profile['updated_at'] = DateTime.now().toIso8601String();
      
      profiles[user.id] = profile;
      await prefs.setString('mock_profiles', jsonEncode(profiles));
      return;
    }

    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name;
    if (phone != null) updateData['phone'] = phone;
    if (bio != null) updateData['bio'] = bio;
    if (location != null) updateData['location'] = location;
    if (isPro != null) updateData['is_pro'] = isPro;
    if (services != null) updateData['services'] = services;
    if (profileCompleted != null) updateData['profile_completed'] = profileCompleted;
    updateData['updated_at'] = DateTime.now().toIso8601String();

    await _client.from(_usersTable).update(updateData).eq('id', user.id);
  }

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // TEMPORARY: Always return mock profile
    return {
      'id': userId,
      'name': 'Mtumiaji Mock',
      'role': 'client',
      'isVerified': true,
      'profile_completed': true,
    };
  }

  /// Service Management
  static Future<void> createService(Map<String, dynamic> serviceData) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final serviceWithMetadata = {
      ...serviceData,
      'provider_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'active',
      'rating': 0.0,
      'review_count': 0,
    };

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final servicesStr = prefs.getString('mock_services') ?? '[]';
      final List<dynamic> servicesList = jsonDecode(servicesStr);
      
      final newService = {
        'id': 'service_${DateTime.now().millisecondsSinceEpoch}',
        ...serviceWithMetadata,
      };
      servicesList.add(newService);
      await prefs.setString('mock_services', jsonEncode(servicesList));
      return;
    }

    await _client.from(_servicesTable).insert(serviceWithMetadata);
  }

  static Future<List<Map<String, dynamic>>> getServices({
    String? category,
    String? location,
    double? minRating,
    int limit = 20,
  }) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final servicesStr = prefs.getString('mock_services') ?? '[]';
      List<dynamic> servicesList = jsonDecode(servicesStr);
      
      // If empty, seed with some default services matching the landing page
      if (servicesList.isEmpty) {
        servicesList = [
          {
            'id': 'pro_1',
            'name': 'Daniel Hosea',
            'category': 'Fundi Bomba',
            'location': 'Kinondoni, DSM',
            'rating': 4.8,
            'review_count': 24,
            'price': 'TSh 30,000/siku',
            'is_active': true,
            'provider_id': 'mock_provider_1',
          },
          {
            'id': 'pro_2',
            'name': 'Amina Salum',
            'category': 'Msusi',
            'location': 'Mwenge, DSM',
            'rating': 4.9,
            'review_count': 42,
            'price': 'TSh 15,000/huduma',
            'is_active': true,
            'provider_id': 'mock_provider_2',
          },
          {
            'id': 'pro_3',
            'name': 'Peter John',
            'category': 'Fundi Umeme',
            'location': 'Sinza, DSM',
            'rating': 4.7,
            'review_count': 18,
            'price': 'TSh 40,000/siku',
            'is_active': true,
            'provider_id': 'mock_provider_3',
          },
        ];
        await prefs.setString('mock_services', jsonEncode(servicesList));
      }

      List<Map<String, dynamic>> filteredList = servicesList.map((e) => Map<String, dynamic>.from(e)).toList();
      
      if (category != null) {
        filteredList = filteredList.where((s) => s['category'] == category).toList();
      }
      if (location != null) {
        filteredList = filteredList.where((s) => s['location'].toString().contains(location)).toList();
      }
      if (minRating != null) {
        filteredList = filteredList.where((s) => (s['rating'] as num).toDouble() >= minRating).toList();
      }
      
      return filteredList.take(limit).toList();
    }

    var query = _client.from(_servicesTable).select();
    if (category != null) {
      query = query.eq('category', category);
    }
    if (location != null) {
      query = query.eq('location', location);
    }
    if (minRating != null) {
      query = query.gte('rating', minRating);
    }

    final response = await query.limit(limit);
    return response;
  }

  static Future<void> updateService(String serviceId, Map<String, dynamic> updates) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final servicesStr = prefs.getString('mock_services') ?? '[]';
      final List<dynamic> servicesList = jsonDecode(servicesStr);
      
      final index = servicesList.indexWhere((s) => s['id'] == serviceId);
      if (index != -1) {
        servicesList[index].addAll(updates);
        servicesList[index]['updated_at'] = DateTime.now().toIso8601String();
        await prefs.setString('mock_services', jsonEncode(servicesList));
      }
      return;
    }

    await _client.from(_servicesTable).update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', serviceId);
  }

  static Future<void> deleteService(String serviceId) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final servicesStr = prefs.getString('mock_services') ?? '[]';
      final List<dynamic> servicesList = jsonDecode(servicesStr);
      servicesList.removeWhere((s) => s['id'] == serviceId);
      await prefs.setString('mock_services', jsonEncode(servicesList));
      return;
    }
    await _client.from(_servicesTable).delete().eq('id', serviceId);
  }

  /// Booking Methods
  static Future<void> createBooking(Map<String, dynamic> bookingData) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bookingWithMetadata = {
      ...bookingData,
      'user_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    };

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final bookingsStr = prefs.getString('mock_bookings') ?? '[]';
      final List<dynamic> bookingsList = jsonDecode(bookingsStr);
      
      final newBooking = {
        'id': 'booking_${DateTime.now().millisecondsSinceEpoch}',
        ...bookingWithMetadata,
      };
      bookingsList.add(newBooking);
      await prefs.setString('mock_bookings', jsonEncode(bookingsList));
      return;
    }

    await _client.from(_bookingsTable).insert(bookingWithMetadata);
  }

  static Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final bookingsStr = prefs.getString('mock_bookings') ?? '[]';
      final List<dynamic> bookingsList = jsonDecode(bookingsStr);
      
      return bookingsList
          .where((b) => b['user_id'] == userId || b['provider_id'] == userId)
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => b['created_at'].toString().compareTo(a['created_at'].toString()));
    }

    final response = await _client
        .from(_bookingsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response;
  }

  static Future<void> updateBookingStatus(String bookingId, String status) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final bookingsStr = prefs.getString('mock_bookings') ?? '[]';
      final List<dynamic> bookingsList = jsonDecode(bookingsStr);
      
      final index = bookingsList.indexWhere((b) => b['id'] == bookingId);
      if (index != -1) {
        bookingsList[index]['status'] = status;
        bookingsList[index]['updated_at'] = DateTime.now().toIso8601String();
        await prefs.setString('mock_bookings', jsonEncode(bookingsList));
      }
      return;
    }

    await _client.from(_bookingsTable).update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Chat Methods
  static Future<void> createChat(String userId, String otherUserId) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final participants = [userId, otherUserId]..sort();
    final chatId = participants.join('_');
    
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final chatsStr = prefs.getString('mock_chats') ?? '[]';
      final List<dynamic> chatsList = jsonDecode(chatsStr);
      
      if (!chatsList.any((c) => c['id'] == chatId)) {
        chatsList.add({
          'id': chatId,
          'participants': participants,
          'created_at': DateTime.now().toIso8601String(),
          'last_message': '',
          'last_message_time': DateTime.now().toIso8601String(),
        });
        await prefs.setString('mock_chats', jsonEncode(chatsList));
      }
      return;
    }

    await _client.from(_chatsTable).upsert({
      'id': chatId,
      'participants': participants,
      'created_at': DateTime.now().toIso8601String(),
      'last_message': '',
      'last_message_time': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> sendMessage(String chatId, String message) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final messageData = {
      'chat_id': chatId,
      'sender_id': user.id,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
    };

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      
      // Save message
      final messagesStr = prefs.getString('mock_messages') ?? '[]';
      final List<dynamic> messagesList = jsonDecode(messagesStr);
      messagesList.add(messageData);
      await prefs.setString('mock_messages', jsonEncode(messagesList));
      
      // Update chat last message
      final chatsStr = prefs.getString('mock_chats') ?? '[]';
      final List<dynamic> chatsList = jsonDecode(chatsStr);
      final index = chatsList.indexWhere((c) => c['id'] == chatId);
      if (index != -1) {
        chatsList[index]['last_message'] = message;
        chatsList[index]['last_message_time'] = DateTime.now().toIso8601String();
        await prefs.setString('mock_chats', jsonEncode(chatsList));
      }
      return;
    }

    await _client.from(_messagesTable).insert(messageData);

    // Update chat with last message
    await _client.from(_chatsTable).update({
      'last_message': message,
      'last_message_time': DateTime.now().toIso8601String(),
    }).eq('id', chatId);
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final messagesStr = prefs.getString('mock_messages') ?? '[]';
      final List<dynamic> messagesList = jsonDecode(messagesStr);
      
      return messagesList
          .where((m) => m['chat_id'] == chatId)
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => b['timestamp'].toString().compareTo(a['timestamp'].toString()));
    }

    final response = await _client
        .from(_messagesTable)
        .select()
        .eq('chat_id', chatId)
        .order('timestamp', ascending: false);
    return response;
  }

  static Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final chatsStr = prefs.getString('mock_chats') ?? '[]';
      final List<dynamic> chatsList = jsonDecode(chatsStr);
      
      return chatsList
          .where((c) => (c['participants'] as List).contains(userId))
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => b['last_message_time'].toString().compareTo(a['last_message_time'].toString()));
    }

    final response = await _client
        .from(_chatsTable)
        .select()
        .contains('participants', [userId])
        .order('last_message_time', ascending: false);
    return response;
  }

  /// Storage Methods
  static Future<String> uploadFile(File file, String path) async {
    if (_useMock) {
      // Return a standard placeholder image path
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80';
    }

    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    final filePath = '$path/$fileName';
    
    await _client.storage.from(_storageBucket).upload(filePath, file);
    
    final response = _client.storage.from(_storageBucket).getPublicUrl(filePath);
    return response;
  }

  static Future<void> deleteFile(String url) async {
    if (_useMock) return;
    
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    final filePath = pathSegments.skipWhile((segment) => segment != _storageBucket).skip(1).join('/');
    
    await _client.storage.from(_storageBucket).remove([filePath]);
  }

  /// Kazilive Methods
  static Future<void> createKaziliveSession(Map<String, dynamic> sessionData) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final sessionWithMetadata = {
      ...sessionData,
      'host_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'live',
      'viewer_count': 0,
    };

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final sessionsStr = prefs.getString('mock_kazilive') ?? '[]';
      final List<dynamic> sessionsList = jsonDecode(sessionsStr);
      
      final newSession = {
        'id': 'session_${DateTime.now().millisecondsSinceEpoch}',
        ...sessionWithMetadata,
      };
      sessionsList.add(newSession);
      await prefs.setString('mock_kazilive', jsonEncode(sessionsList));
      return;
    }

    await _client.from(_kaziliveTable).insert(sessionWithMetadata);
  }

  static Future<List<Map<String, dynamic>>> getLiveSessions() async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final sessionsStr = prefs.getString('mock_kazilive') ?? '[]';
      final List<dynamic> sessionsList = jsonDecode(sessionsStr);
      
      return sessionsList
          .where((s) => s['status'] == 'live')
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => (b['viewer_count'] as int).compareTo(a['viewer_count'] as int));
    }

    final response = await _client
        .from(_kaziliveTable)
        .select()
        .eq('status', 'live')
        .order('viewer_count', ascending: false);
    return response;
  }

  static Future<void> joinSession(String sessionId) async {
    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      final sessionsStr = prefs.getString('mock_kazilive') ?? '[]';
      final List<dynamic> sessionsList = jsonDecode(sessionsStr);
      
      final index = sessionsList.indexWhere((s) => s['id'] == sessionId);
      if (index != -1) {
        sessionsList[index]['viewer_count'] = (sessionsList[index]['viewer_count'] as int) + 1;
        await prefs.setString('mock_kazilive', jsonEncode(sessionsList));
      }
      return;
    }
    await _client.rpc('increment_viewer_count', params: {'session_id': sessionId});
  }
}
