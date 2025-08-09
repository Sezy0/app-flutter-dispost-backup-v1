import 'package:flutter/material.dart';
import 'package:dispost_autopost/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Timezone Indonesia (Jakarta/WIB)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // Inisialisasi Supabase
  await initializeSupabase();

  runApp(const MyApp());
}

Future<void> initializeSupabase() async {
  try {
    await Supabase.initialize(
      url: 'https://mdsjedgyfbvtacijuflw.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kc2plZGd5ZmJ2dGFjaWp1Zmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5MDExNzYsImV4cCI6MjA2OTQ3NzE3Nn0.Auqk7qTy0KHFC0uPUWLfZBmbwnSeUC_lw06669tTaDY',
      debug: false,
    );
  } catch (e) {
    String errorMsg = e.toString();
    if (errorMsg.contains('already initialized')) {
      return;
    }
    // App will continue to run without Supabase connection
  }
}
