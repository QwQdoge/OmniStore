import 'dart:async';
import "package:frontend/data/repositories/package_repository.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';

class BrowseController with ChangeNotifier {
  final PackageRepository _packageRepository;

  Map<String, List<AppPackage>> _recommendations = {};
  List<AppPackage> _searchResults = [];
  bool _isSearching = false;
  String? _pendingSearchQuery;
  Timer? _debounceTimer;
  AppPackage? _selectedApp;

  BrowseController(this._packageRepository);

  Map<String, List<AppPackage>> get recommendations => _recommendations;
  List<AppPackage> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get pendingSearchQuery => _pendingSearchQuery;
  AppPackage? get selectedApp => _selectedApp;

  set pendingSearchQuery(String? query) {
    _pendingSearchQuery = query;
    notifyListeners();
  }

  set selectedApp(AppPackage? app) {
    if (_selectedApp?.id == app?.id && _selectedApp?.name == app?.name) return;
    _selectedApp = app;
    notifyListeners();
  }

  Future<void> fetchRecommendations() async {
    _recommendations = await _packageRepository.getRecommendations();
    notifyListeners();
  }

  Future<void> search(String query) async {
    _debounceTimer?.cancel();
    _isSearching = true;
    _selectedApp = null;
    notifyListeners();

    final completer = Completer<void>();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        _searchResults = await _packageRepository.searchPackages(query);
      } finally {
        _isSearching = false;
        notifyListeners();
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
