import 'package:flutter/material.dart';

class InspirationPage extends StatelessWidget {
  const InspirationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('灵感')),
      body: const Center(child: Text('AI搭配推荐')),
    );
  }
}
