import 'package:flutter/material.dart';

class MainMapScreen extends StatelessWidget {
  const MainMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map View Workspace')),
      body: const Center(
        child: Text(
          'Google Maps Layer & Interactive Sheet coming here.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}