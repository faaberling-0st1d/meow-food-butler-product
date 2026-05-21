import 'package:flutter/material.dart';
import 'package:meow_food_butler/services/navigation.dart'; // Import your navigation layout directly

void main() {
  runApp(const FoodButlerApp());
}

class FoodButlerApp extends StatelessWidget {
  const FoodButlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Food Butler',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.dark,
      ),
      // Bind router delegates straight to your GoRouter architecture schema
      routerConfig: AppNavigation.router,
    );
  }
}