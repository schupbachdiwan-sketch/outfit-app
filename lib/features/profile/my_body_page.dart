import 'package:flutter/material.dart';
import '../../shared/widgets/empty_state.dart';

class MyBodyPage extends StatelessWidget {
  const MyBodyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的身材'),
        centerTitle: true,
      ),
      body: EmptyState(
        icon: Icons.accessibility_new,
        message: '还没有设置身材模板\n选择或拍摄你的身材，开始虚拟试衣',
        actionLabel: '去设置身材',
        onAction: () {
          // TODO Phase 3: 跳转身材设置页
        },
      ),
    );
  }
}
