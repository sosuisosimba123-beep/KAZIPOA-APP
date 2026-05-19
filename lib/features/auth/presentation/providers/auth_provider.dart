import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazipoa/core/services/auth_service.dart';
import 'package:kazipoa/core/services/auth_manager.dart';
import 'package:kazipoa/core/services/enhanced_auth_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? currentUser;

  const AuthState({
    required this.isLoading,
    this.error,
    required this.isAuthenticated,
    this.currentUser,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    Map<String, dynamic>? currentUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser ?? this.currentUser,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final EnhancedAuthService _authService;

  @override
  AuthState build() {
    _authService = ref.read(enhancedAuthServiceProvider);
    // TEMPORARY: Always return authenticated state to bypass login for now
    return const AuthState(
      isLoading: false,
      error: null,
      isAuthenticated: true,
      currentUser: {
        'id': 'mock-id',
        'name': 'Mock User',
        'email': 'mock@example.com',
        'role': 'client',
      },
    );
  }

  
  Future<void> login(String email, String password, {String userType = 'client'}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.login(email, password, userType: userType);
      
      if (result['success'] == true) {
        final user = result['user'];
        AuthManager().login(user['id'], user['role'] ?? userType);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          currentUser: user,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          currentUser: null,
          error: result['error'] ?? 'Login failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        currentUser: null,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.logout();
      AuthManager().logout();
      state = const AuthState(
        isLoading: false,
        error: null,
        isAuthenticated: false,
        currentUser: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.register(userData);
      
      if (result['success'] == true) {
        final user = result['user'];
        AuthManager().login(user['id'], user['role'] ?? 'client');
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          currentUser: user,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          currentUser: null,
          error: result['error'] ?? 'Registration failed',
        );
      }
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true);
    
    try {
      final result = await _authService.updateProfile(updates);
      
      if (result['success'] == true) {
        final updatedUser = Map<String, dynamic>.from(state.currentUser ?? {});
        updatedUser.addAll(updates);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          currentUser: updatedUser,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['error'] ?? 'Update failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());

// Convenience getters
extension AuthProviderRef on WidgetRef {
  AuthNotifier get authNotifier => read(authProvider.notifier);
  AuthState get authState => watch(authProvider);
}
