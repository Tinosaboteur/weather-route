import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';

class SearchScreen extends StatefulWidget {
  final String initialValue;

  const SearchScreen({super.key, this.initialValue = ""});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  late final MapProvider _mapProvider;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialValue);
    _mapProvider = Provider.of<MapProvider>(context, listen: false);

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapProvider.loadHistoryAndSavedLocations();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text;
      if (query.isNotEmpty) {
        _mapProvider.fetchDestinationSuggestions(query);
      } else {
        _mapProvider.clearSuggestions();
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onItemSelected(String selection) {
    _mapProvider.addSearchToHistory(selection);
    Navigator.pop(context, selection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Tìm kiếm địa điểm...",
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            )
                : null,
          ),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Consumer<MapProvider>(
      builder: (context, provider, child) {
        final bool isSearching = _searchController.text.isNotEmpty;

        if (isSearching) {
          return _buildSuggestionsList(provider);
        } else {
          return _buildHistoryAndSavedList(provider);
        }
      },
    );
  }

  Widget _buildSuggestionsList(MapProvider provider) {
    if (provider.destSuggestions.isEmpty) {
      return const Center(child: Text("Không tìm thấy kết quả nào."));
    }
    return ListView.builder(
      itemCount: provider.destSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = provider.destSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(suggestion),
          onTap: () => _onItemSelected(suggestion),
        );
      },
    );
  }

  Widget _buildHistoryAndSavedList(MapProvider provider) {
    if (provider.savedLocations.isEmpty && provider.searchHistory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        if (provider.savedLocations.isNotEmpty) ...[
          _buildSectionHeader('Địa điểm đã lưu'),
          ...provider.savedLocations.map((location) {
            return ListTile(
              leading: Icon(Icons.star_border, color: Colors.amber[600]),
              title: Text(location['label'] ?? 'N/A'),
              subtitle: Text(location['address'] ?? 'N/A'),
              onTap: () => _onItemSelected(location['address']),
            );
          }).toList(),
        ],

        if (provider.searchHistory.isNotEmpty) ...[
          _buildSectionHeader('Lịch sử tìm kiếm'),
          ...provider.searchHistory.map((history) {
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(history['query'] ?? 'N/A'),
              onTap: () => _onItemSelected(history['query']),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.manage_search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bắt đầu tìm kiếm một địa điểm',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Lịch sử tìm kiếm của bạn sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}