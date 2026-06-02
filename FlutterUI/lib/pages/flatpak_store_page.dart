import 'package:flutter/material.dart';

class FlatpakStorePage extends StatelessWidget {
  const FlatpakStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Flatpak Store", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("Browsing Flathub catalog..."),
        ],
      ),
    );
  }
}
