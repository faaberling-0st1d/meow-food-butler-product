import 'package:flutter/material.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const themeColor = Colors.teal;
    return Scaffold(
      backgroundColor: themeColor.withOpacity(0.2),
      appBar: AppBar(title: const Text('Saved Places Dossier')),
      body: const Center(
        child: Text(
          'Collection Folders & Experience Reviews coming here.',
          style: TextStyle(fontSize: 20, color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}