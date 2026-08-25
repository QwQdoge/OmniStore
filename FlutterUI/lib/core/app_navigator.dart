import 'package:flutter/material.dart';

/// Shared navigator access for app-wide consent surfaces triggered by services.
/// It is intentionally UI-only: no service may auto-approve on the user's behalf.
final GlobalKey<NavigatorState> omnistoreNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'omnistore-root-navigator');
