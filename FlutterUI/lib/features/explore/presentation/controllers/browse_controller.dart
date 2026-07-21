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
  AppPackage? _selectedApp;

  // Race condition handler: ensures only the latest search results update the UI
  int _activeSearchId = 0;

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

  Future<void> fetchRecommendations({bool forceRefresh = false}) async {
    _recommendations = await _packageRepository.getRecommendations(forceRefresh: forceRefresh);
    notifyListeners();

    // If there is an active background fetch task running, await it as well
    // and trigger notifyListeners() again when it finishes so the UI receives fresh data.
    final backgroundFuture = _packageRepository.activeFetchFuture;
    if (backgroundFuture != null) {
      try {
        _recommendations = await backgroundFuture;
        notifyListeners();
      } catch (e) {
        debugPrint("Background recommendations sync failed: $e");
      }
    }
  }

  /// Performs an asynchronous search for packages.
  /// ⚡ Bolt: Removed 300ms artificial debounce as searches are triggered by explicit
  /// user actions (onSubmitted). Added _activeSearchId to handle race conditions.
  Future<void> search(String query) async {
    final searchId = ++_activeSearchId;
    _isSearching = true;
    _selectedApp = null;
    notifyListeners();

    try {
      final results = await _packageRepository.searchPackages(query);

      // Only update if this is still the most recent search
      if (searchId == _activeSearchId) {
        _searchResults = results;
      }
    } finally {
      if (searchId == _activeSearchId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }
}
