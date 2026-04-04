import 'package:flutter/material.dart';

/// Base class for screens that load data
/// Handles common patterns: loading state, error handling, caching, refresh
abstract class BaseDataScreen<T> extends StatefulWidget {
  const BaseDataScreen({super.key});

  @override
  BaseDataScreenState<BaseDataScreen<T>, T> createState();
}

abstract class BaseDataScreenState<W extends BaseDataScreen<T>, T>
    extends State<W> {
  /// Override this to load data (called only once in initState)
  Future<T> loadData();

  /// Override this to build the loaded data UI
  Widget buildDataWidget(BuildContext context, T data);

  /// Override this for custom loading UI
  Widget buildLoadingWidget(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  /// Override this for custom error UI
  Widget buildErrorWidget(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _retry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Override this for custom empty UI
  Widget buildEmptyWidget(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('No data available'),
        ],
      ),
    );
  }

  // State variables
  T? _data;
  String? _error;
  bool _isLoading = true;
  bool _isFetching = false; // Prevent multiple simultaneous calls

  @override
  void initState() {
    super.initState();
    _loadDataSafely();
  }

  /// Safely load data with error handling
  Future<void> _loadDataSafely() async {
    if (_isFetching) {
      debugPrint('[BaseDataScreen] ⚠️ Already fetching, skipping');
      return;
    }

    _isFetching = true;

    try {
      final data = await loadData();

      if (!mounted) return;

      setState(() {
        _data = data;
        _error = null;
        _isLoading = false;
        _isFetching = false;
      });

      debugPrint('[BaseDataScreen] ✅ Data loaded successfully');
    } catch (e) {
      if (!mounted) return;

      debugPrint('[BaseDataScreen] ❌ Error loading data: $e');

      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isFetching = false;
      });
    }
  }

  /// Retry loading
  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadDataSafely();
  }

  /// Refresh data (for pull-to-refresh)
  Future<void> refresh() async {
    _data = null;
    await _retry();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return buildLoadingWidget(context);
    }

    if (_error != null) {
      return buildErrorWidget(context, _error!);
    }

    if (_data == null) {
      return buildEmptyWidget(context);
    }

    return buildDataWidget(context, _data as T);
  }
}
