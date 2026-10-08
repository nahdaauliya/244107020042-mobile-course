import 'package:flutter/material.dart';

class AnnouncementPage extends StatelessWidget {
  final String id;
  const AnnouncementPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Announcement #$id'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.campaign, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(
                'Announcement Detail #$id',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Schedule changed: Mobile class moved to Room A2 at 1:00 PM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}