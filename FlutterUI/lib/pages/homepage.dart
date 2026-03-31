import 'package:flutter/material.dart'; // 这个文件是主页的 UI 实现，负责展示推荐内容和一些固定的入口

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Discover")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Recommended for You",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 这里可以放一些漂亮的 Banner 或者固定的推荐卡片
          _buildFeaturedCard(
            context,
            "Zen Browser",
            "The best browser for Arch.",
          ),
          _buildFeaturedCard(
            context,
            "Neovim",
            "Hyperextensible Vim-based text editor.",
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, String title, String desc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(desc),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
