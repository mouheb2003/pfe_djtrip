class MapPlaceSuggestion {
  const MapPlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  String get fullText {
    if (secondaryText.trim().isEmpty) {
      return primaryText;
    }
    return '$primaryText, $secondaryText';
  }
}
