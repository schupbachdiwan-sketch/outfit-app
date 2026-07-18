import 'package:flutter/material.dart';
import '../../shared/widgets/empty_state.dart';

class MyOutfitsPage extends StatelessWidget {
  const MyOutfitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的搭配'),
        centerTitle: true,
      ),
      body: const EmptyState(
        icon: Icons.checkroom,
        message: '还没有保存的搭配\n去试衣间创建你的第一套搭配吧',
      ),
    );
  }
}
