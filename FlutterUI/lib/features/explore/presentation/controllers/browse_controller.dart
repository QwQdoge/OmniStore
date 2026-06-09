import "package:frontend/data/repositories/package_repository.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';

class BrowseController with ChangeNotifier {
  final PackageRepository _packageRepository;

  Map<String, List<AppPackage>> _recommendations = {};
  List<AppPackage> _searchResults = [];
  bool _isSearching = false;
  String? _pendingSearchQuery;

  BrowseController(this._packageRepository);

  Map<String, List<AppPackage>> get recommendations => _recommendations;
  List<AppPackage> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get pendingSearchQuery => _pendingSearchQuery;

  set pendingSearchQuery(String? query) {
    _pendingSearchQuery = query;
    notifyListeners();
  }

  Future<void> fetchRecommendations() async {
    _recommendations = await _packageRepository.getRecommendations();
    notifyListeners();
  }

  Future<void> search(String query) async {
    _isSearching = true;
    notifyListeners();

    _searchResults = await _packageRepository.searchPackages(query);

    _isSearching = false;
    notifyListeners();
  }
}
