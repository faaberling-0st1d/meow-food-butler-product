import 'package:flutter/material.dart';

class MainMapScreen extends StatelessWidget {
  const MainMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const themeColor = Colors.blueGrey;
    return Scaffold(
      backgroundColor: themeColor.withOpacity(0.2),
      appBar: AppBar(title: const Text('Map View Workspace')),
      body: const Center(
        child: Text(
          'Google Maps Layer & Interactive Sheet coming here.',
          style: TextStyle(fontSize: 20, color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}