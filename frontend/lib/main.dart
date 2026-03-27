import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(
  MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color.fromARGB(255, 202, 110, 207),
    ),
    home: const OmniGoogleApp(),
    debugShowCheckedModeBanner: false,
  ),
);

class OmniGoogleApp extends StatefulWidget {
  const OmniGoogleApp({super.key});
  @override
  State<OmniGoogleApp> createState() => _OmniGoogleAppState();
}

class _OmniGoogleAppState extends State<OmniGoogleApp> {
  late WebSocketChannel _channel;
  StreamSubscription<dynamic>? _wsSubscription;
  List<dynamic> _packages = [];
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/search'),
      );
      _isConnected = true;
      _retryCount = 0;

      _wsSubscription?.cancel();
      _wsSubscription = _channel.stream.listen(
        _handleWsMessage,
        onError: _handleWsError,
        onDone: _handleWsDone,
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
        _errorMessage = '连接失败：$e';
      });
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'results') {
        setState(() {
          _packages = List<dynamic>.from(data['data'] ?? []);
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('解析错误: $e');
    }
  }

  void _handleWsError(Object error) {
    setState(() {
      _isConnected = false;
      _isLoading = false;
      _errorMessage = 'WebSocket 错误：$error';
    });
    _scheduleReconnect();
  }

  void _handleWsDone() {
    setState(() {
      _isConnected = false;
      _isLoading = false;
      _errorMessage = '连接已断开，正在尝试重连...';
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delay = min(30, pow(2, _retryCount).toInt());
    _retryCount += 1;

    Future.delayed(Duration(seconds: delay), () {
      if (!mounted) return;
      _connectWebSocket();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Explore'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.download_for_offline_outlined),
                selectedIcon: Icon(Icons.download_for_offline),
                label: Text('Tasks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildResultList()), // 此处已定义
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBar(
            hintText: "Search apps on Arch...",
            leading: const Icon(Icons.search),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            onChanged: (val) {
              if (val.isNotEmpty) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _channel.sink.add(jsonEncode({"query": val}));
              }
            },
          ),
          if (!_isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '未连接：正在尝试重连...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 修复：定义搜索结果列表 ---
  Widget _buildResultList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _connectWebSocket();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_packages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No apps found. Try searching for 'vlc'!",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _packages.length,
      itemBuilder: (context, index) => _packageCard(_packages[index]),
    );
  }

  // --- 修复：定义软件包卡片 ---
  Widget _packageCard(dynamic pkg) {
    final List variants = pkg['variants'] ?? [];
    // 默认展示第一个来源
    final primary = variants.isNotEmpty
        ? variants[0]
        : {"source": "Unknown", "version": "N/A", "is_installed": false};

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(pkg['name'][0].toUpperCase()),
        ),
        title: Text(
          pkg['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(pkg['desc'] ?? "No description"),
        trailing: FilledButton.tonal(
          onPressed: primary['is_installed']
              ? null
              : () => _sendInstallRequest(pkg, primary),
          child: Text(primary['is_installed'] ? "Installed" : "Install"),
        ),
        children: variants
            .map(
              (v) => ListTile(
                title: Text(v['source']),
                subtitle: Text("Version: ${v['version']}"),
                trailing: OutlinedButton(
                  onPressed: v['is_installed']
                      ? null
                      : () => _sendInstallRequest(pkg, v),
                  child: const Text("Install"),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _sendInstallRequest(dynamic pkg, dynamic variant) {
    // 这里留给下一阶段实现 WebSocket 安装指令发送
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Action: Install ${pkg['name']} from ${variant['source']}",
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel.sink.close();
    super.dispose();
  }
}
