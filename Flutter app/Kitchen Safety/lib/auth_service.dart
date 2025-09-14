import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<void> handleAuth({
    required String email,
    required String password,
    required String? username,
    required bool isSignUp,
    required BuildContext context,
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
  }) async {
    try {
      setLoading();
      final auth = _client.auth;
      final trimmedEmail = email.trim();
      final trimmedPassword = password.trim();
      final trimmedUsername = username?.trim();

      final response = isSignUp
          ? await auth.signUp(email: trimmedEmail, password: trimmedPassword)
          : await auth.signInWithPassword(
              email: trimmedEmail, password: trimmedPassword);

      final user = response.user;
      if (user != null) {
        if (isSignUp && trimmedUsername != null) {
          await _client
              .from('profiles')
              .update({'username': trimmedUsername}).eq('id', user.id);
        }
      } else {
        _showError(
          context,
          isSignUp
              ? 'Signup failed. Please try again.'
              : 'Login failed. Please check your credentials.',
        );
      }
    } catch (e) {
      _showError(context, 'An error occurred: $e');
    } finally {
      clearLoading();
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'OpenSans'),
        ),
        backgroundColor: const Color(0xFF4A0D0D),
      ),
    );
  }
}
