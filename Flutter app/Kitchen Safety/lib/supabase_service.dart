import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://recsbpbfmvzqillzqasa.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlY3NicGJmbXZ6cWlsbHpxYXNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ3MjIxODYsImV4cCI6MjA3MDI5ODE4Nn0.DJOEtld0vWqPMbp91OkZqtD2vI3DVmFRV6RGUGLtxI4',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
