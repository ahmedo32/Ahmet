// pages/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR App Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                        const SizedBox(height: 20),
            const Text(
              'Welcome to the OCR Scanner App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Use the buttons below to navigate through the app.',
              style: TextStyle(fontSize: 16),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera');
              },
              child: const Text('Get an Image'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/records'); // Navigate to saved records page
              },
              child: const Text('Saved OCR Records'),
            ), 
            /*ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/result');
              },
              child: const Text('View OCR Results'),
            ),*/
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
           },
               icon: const Icon(Icons.settings),
              label: const Text('Settings'),
          ),
          ],
        ),
      ),
    );
  }
}
