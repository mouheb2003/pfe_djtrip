class AiChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<AiSource>? sources;

  AiChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources,
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      sources: json['sources'] != null 
          ? (json['sources'] as List).map((e) => AiSource.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (sources != null) 'sources': sources?.map((e) => e.toJson()).toList(),
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class AiSource {
  final String filename;
  final String? path;
  final String? sectionHeading;
  final double similarity;

  AiSource({
    required this.filename,
    this.path,
    this.sectionHeading,
    required this.similarity,
  });

  factory AiSource.fromJson(Map<String, dynamic> json) {
    return AiSource(
      filename: json['filename'] ?? '',
      path: json['path'],
      sectionHeading: json['sectionHeading'],
      similarity: (json['similarity'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      if (path != null) 'path': path,
      if (sectionHeading != null) 'sectionHeading': sectionHeading,
      'similarity': similarity,
    };
  }
}

class AiChatResponse {
  final String response;
  final String conversationId;
  final List<AiSource> sources;
  final Map<String, dynamic> context;
  final String model;
  final DateTime timestamp;

  AiChatResponse({
    required this.response,
    required this.conversationId,
    required this.sources,
    required this.context,
    required this.model,
    required this.timestamp,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AiChatResponse(
      response: data['response'] ?? '',
      conversationId: data['conversationId'] ?? '',
      sources: (data['sources'] as List?)
              ?.map((e) => AiSource.fromJson(e))
              .toList() ?? [],
      context: data['context'] ?? {},
      model: data['model'] ?? '',
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'conversationId': conversationId,
      'sources': sources.map((e) => e.toJson()).toList(),
      'context': context,
      'model': model,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class AiSearchResponse {
  final List<AiSearchResult> results;
  final String query;
  final int totalChunks;
  final int filteredChunks;
  final int foundResults;
  final String message;

  AiSearchResponse({
    required this.results,
    required this.query,
    required this.totalChunks,
    required this.filteredChunks,
    required this.foundResults,
    required this.message,
  });

  factory AiSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AiSearchResponse(
      results: (data['results'] as List?)
              ?.map((e) => AiSearchResult.fromJson(e))
              .toList() ?? [],
      query: data['query'] ?? '',
      totalChunks: data['totalChunks'] ?? 0,
      filteredChunks: data['filteredChunks'] ?? 0,
      foundResults: data['foundResults'] ?? 0,
      message: data['message'] ?? '',
    );
  }
}

class AiSearchResult {
  final Map<String, dynamic> chunk;
  final double similarity;
  final String relevance;

  AiSearchResult({
    required this.chunk,
    required this.similarity,
    required this.relevance,
  });

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    return AiSearchResult(
      chunk: json['chunk'] ?? {},
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      relevance: json['relevance'] ?? '',
    );
  }
}

class AiConversation {
  final String id;
  final List<AiChatMessage> history;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> metadata;

  AiConversation({
    required this.id,
    required this.history,
    required this.stats,
    required this.metadata,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] ?? '',
      history: (json['history'] as List?)
              ?.map((e) => AiChatMessage.fromJson(e))
              .toList() ?? [],
      stats: json['stats'] ?? {},
      metadata: json['metadata'] ?? {},
    );
  }
}
