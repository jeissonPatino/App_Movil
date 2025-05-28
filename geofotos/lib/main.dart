import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'firebase_options.dart';
import 'package:geofotos/screens/auth/login_screen.dart'; 
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:geofotos/widgets/app_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

 
  try {
    await FirebaseAppCheck.instance.activate(
      
      androidProvider: AndroidProvider.debug,
      
    );
    try {
      String? token = await FirebaseAppCheck.instance.getToken(true);
      print('MANUAL APP CHECK TOKEN: $token');
    } catch (e) {
      print('Error getting App Check token manually: $e');
    }
  } catch (e) {
    print('Error activating Firebase App Check: $e'); 
  }
  
  runApp(const GeoFotosApp()); 
}

class GeoFotosApp extends StatelessWidget {
  const GeoFotosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoFotos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const AppNavigationShell();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}