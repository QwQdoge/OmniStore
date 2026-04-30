import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../l10n/app_localizations.dart';

class WindowTitleBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SizedBox(
        height: 48,
        child: Stack(
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
                      title ?? "OmniStore",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  
                  const Expanded(child: DragToMoveArea(child: SizedBox.expand())),

                  // Search Bar (Middle)
                  if (showSearch)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 200, maxWidth: 400),
                        child: InkWell(
                          onTap: onSearchPressed,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)?.searchHint ?? "Search",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const Expanded(child: DragToMoveArea(child: SizedBox.expand())),

                  // Window Controls
                  Row(
                    children: [
                      _buildWindowButton(
                        icon: Icons.minimize_rounded,
                        onPressed: () => windowManager.minimize(),
                        colorScheme: colorScheme,
                      ),
                      _buildWindowButton(
                        icon: Icons.crop_square_rounded,
                        onPressed: () async {
                          if (await windowManager.isMaximized()) {
                            windowManager.unmaximize();
                          } else {
                            windowManager.maximize();
                          }
                        },
                        colorScheme: colorScheme,
                      ),
                      _buildWindowButton(
                        icon: Icons.close_rounded,
                        onPressed: () => windowManager.close(),
                        isClose: true,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isClose = false,
  }) {
    return SizedBox(
      width: 46,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 16,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: isClose
              ? Colors.red.withOpacity(0.8)
              : colorScheme.onSurface.withOpacity(0.1),
          foregroundColor: isClose ? null : colorScheme.onSurface.withOpacity(0.7),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
