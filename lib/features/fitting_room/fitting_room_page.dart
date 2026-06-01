import 'package:flutter/material.dart';

class FittingRoomPage extends StatelessWidget {
  const FittingRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('试衣间')),
      body: const Center(child: Text('虚拟试衣画布')),
    );
  }
}
