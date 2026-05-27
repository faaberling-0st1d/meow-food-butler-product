import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const themeColor = Colors.indigo;
    return Scaffold(
      backgroundColor: themeColor.withOpacity(0.2),
      appBar: AppBar(title: const Text('AI Chat Core Engine')),
      body: const Center(
        child: Text(
          'AI Dialogue & Swipe Cards coming here.',
          style: TextStyle(fontSize: 20, color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}