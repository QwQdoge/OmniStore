import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/auth/auth_page.dart';
import '../l10n/app_localizations.dart';

class WindowTitleBar extends StatefulWidget {
  final String? title;
  final bool showSearch;
  final VoidCallback? onSearchPressed;

  const WindowTitleBar({
    super.key,
    this.title,
    this.showSearch = false,
    this.onSearchPressed,
  });

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final isMax = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMax;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onWindowRestore() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useSystemTitleBar = context.select<SettingsController, bool>((s) => s.useSystemTitleBar);

    return Material(
      color: colorScheme.surface,
      child: SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final showMiddleSearch = width > 700 && widget.showSearch;

            return Stack(
              children: [
                // Background Draggable Area
                const Positioned.fill(
                  child: DragToMoveArea(child: SizedBox.expand()),
                ),
                // Content Layer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Logo & Title (Also Draggable)
                      const DragToMoveArea(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 8),
                            Icon(Icons.shop_two_rounded, size: 22),
                            SizedBox(width: 12),
                          ],
                        ),
                      ),
                      DragToMoveArea(
                        child: Text(
                          widget.title ?? "OmniStore",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),

                      const Expanded(
                        child: DragToMoveArea(child: SizedBox.expand()),
                      ),

                      // Search Bar (Middle)
                      if (showMiddleSearch)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 200,
                              maxWidth: 400,
                            ),
                            child: InkWell(
                              onTap: widget.onSearchPressed,
                              borderRadius: BorderRadius.circular(28.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(28.0),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context)?.searchHint ??
                                            "Search",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      const Expanded(
                        child: DragToMoveArea(child: SizedBox.expand()),
                      ),

                      // Window Controls & Account Button
                      Row(
                        children: [
                          if (!showMiddleSearch && widget.showSearch)
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              tooltip: AppLocalizations.of(context)!.search,
                              onPressed: widget.onSearchPressed,
                            ),
                          IconButton(
                            icon: const Icon(Icons.account_circle_outlined),
                            tooltip: AppLocalizations.of(context)!.githubAuthTitle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AuthPage(),
                                ),
                              );
                            },
                          ),
                          if (!useSystemTitleBar) ...[
                            _buildWindowButton(
                              icon: Icons.minimize_rounded,
                              tooltip: AppLocalizations.of(context)!.windowMinimize,
                              onPressed: () => windowManager.minimize(),
                              colorScheme: colorScheme,
                            ),
                            _buildWindowButton(
                              icon: _isMaximized
                                  ? Icons.filter_none_rounded
                                  : Icons.crop_square_rounded,
                              tooltip: _isMaximized
                                  ? (AppLocalizations.of(context)!.windowRestore)
                                  : (AppLocalizations.of(context)!.windowMaximize),
                              onPressed: () async {
                                if (_isMaximized) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                              },
                              colorScheme: colorScheme,
                            ),
                            _buildWindowButton(
                              icon: Icons.close_rounded,
                              tooltip: AppLocalizations.of(context)!.windowClose,
                              onPressed: () => windowManager.close(),
                              isClose: true,
                              colorScheme: colorScheme,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isClose = false,
  }) {
    return SizedBox(
      width: 46,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 16,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: isClose
              ? colorScheme.error.withValues(alpha: 0.8)
              : colorScheme.onSurface.withValues(alpha: 0.1),
          foregroundColor: isClose
              ? null
              : colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
