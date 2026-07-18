import 'package:flutter/material.dart';
import '../../shared/widgets/empty_state.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心愿单'),
        centerTitle: true,
      ),
      body: const EmptyState(
        icon: Icons.favorite_border,
        message: '心愿单还是空的\n浏览搭配时收藏喜欢的单品吧',
      ),
    );
  }
}
