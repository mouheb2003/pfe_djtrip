import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/place_service.dart';

class PlaceSearchWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(PlaceModel)? onPlaceSelected;
  final String? hintText;

  const PlaceSearchWidget({
    Key? key,
    required this.controller,
    this.onPlaceSelected,
    this.hintText = 'Search for a place...',
  }) : super(key: key);

  @override
  State<PlaceSearchWidget> createState() => _PlaceSearchWidgetState();
}

class _PlaceSearchWidgetState extends State<PlaceSearchWidget> {
  List<PlaceModel> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _showResults = _focusNode.hasFocus && _searchResults.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await PlaceService.searchPlaces(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _showResults = results.isNotEmpty && _focusNode.hasFocus;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _selectPlace(PlaceModel place) {
    widget.controller.text = place.name;
    widget.onPlaceSelected?.call(place);
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            suffixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
          ),
          onChanged: (value) {
            if (value.length >= 2) {
              _searchPlaces(value);
            } else {
              setState(() {
                _searchResults = [];
                _showResults = false;
              });
            }
          },
        ),
        if (_showResults)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.transparent),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final place = _searchResults[index];
                return ListTile(
                  leading: place.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            place.imageUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: isDark ? const Color(0xFF333333) : Colors.grey[300],
                                child: Icon(Icons.place, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                              );
                            },
                          ),
                        )
                      : SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.place, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                  title: Text(
                    place.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    place.location ?? place.city ?? '',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _selectPlace(place),
                );
              },
            ),
          ),
      ],
    );
  }
}
