import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PlaceholderPage({super.key, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            if (subtitle != null) Padding(padding: const EdgeInsets.all(8), child: Text(subtitle!)),
          ],
        ),
      ),
    );
  }
}
