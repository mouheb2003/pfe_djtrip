import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/api_config.dart';
import '../models/message.dart';
import 'http_client.dart';
import 'storage_service.dart';

class MessageService {
  static IO.Socket? _socket;
  static bool _connecting = false;
  static Completer<void>? _connectCompleter;

  static final List<void Function(Message)> _messageCallbacks = [];
  static final List<void Function(Message)> _sentCallbacks = [];
  static final List<void Function(String partnerId)> _typingCallbacks = [];
  static final List<void Function(String partnerId)> _typingStopCallbacks = [];

  static String get _socketUrl {
    final base = ApiConfig.baseUrl;

    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }

    return base;
  }

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    if (_connecting) {
      await _connectCompleter?.future;
      return;
    }

    _connecting = true;
    _connectCompleter = Completer();

    final token = await StorageService.getAccessToken();

    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection() // active la reconnexion
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000) // <- ici en millisecondes
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
      _connectCompleter?.complete();
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onConnectError((err) {
      print('Socket connect error: $err');
      _connectCompleter?.completeError(err);
    });

    _socket!.on('error', (data) {
      print('Socket error: $data');
    });

    _socket!.on('new_message', (data) {
      final msg = Message.fromJson(Map<String, dynamic>.from(data));

      for (final cb in List.of(_messageCallbacks)) {
        cb(msg);
      }
    });

    _socket!.on('message_sent', (data) {
      final msg = Message.fromJson(Map<String, dynamic>.from(data));
      for (final cb in List.of(_sentCallbacks)) {
        cb(msg);
      }
    });

    _socket!.on('partner_typing', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final partnerId = map['partnerId']?.toString() ?? '';
      for (final cb in List.of(_typingCallbacks)) {
        cb(partnerId);
      }
    });

    _socket!.on('partner_typing_stop', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final partnerId = map['partnerId']?.toString() ?? '';
      for (final cb in List.of(_typingStopCallbacks)) {
        cb(partnerId);
      }
    });

    _socket!.connect();

    await _connectCompleter?.future;

    _connecting = false;
  }

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  static Future<void> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    if (receiverId.isEmpty || content.trim().isEmpty) return;
    await connect();

    if (_socket == null || !_socket!.connected) {
      throw Exception('Messagerie non connectée. Réessayez.');
    }

    _socket!.emit('send_message', {
      'receiverId': receiverId.trim(),
      'content': content.trim(),
    });
  }

  static void onMessage(void Function(Message) callback) {
    if (!_messageCallbacks.contains(callback)) {
      _messageCallbacks.add(callback);
    }
  }

  static void offMessage(void Function(Message) callback) {
    _messageCallbacks.remove(callback);
  }

  static void onMessageSent(void Function(Message) callback) {
    if (!_sentCallbacks.contains(callback)) {
      _sentCallbacks.add(callback);
    }
  }

  static void offMessageSent(void Function(Message) callback) {
    _sentCallbacks.remove(callback);
  }

  static void onPartnerTyping(void Function(String partnerId) callback) {
    if (!_typingCallbacks.contains(callback)) _typingCallbacks.add(callback);
  }

  static void offPartnerTyping(void Function(String partnerId) callback) {
    _typingCallbacks.remove(callback);
  }

  static void onPartnerTypingStop(void Function(String partnerId) callback) {
    if (!_typingStopCallbacks.contains(callback)) _typingStopCallbacks.add(callback);
  }

  static void offPartnerTypingStop(void Function(String partnerId) callback) {
    _typingStopCallbacks.remove(callback);
  }

  static void emitTyping(String partnerId) {
    if (partnerId.isEmpty) return;
    _socket?.emit('typing_start', {'receiverId': partnerId});
  }

  static void emitTypingStop(String partnerId) {
    if (partnerId.isEmpty) return;
    _socket?.emit('typing_stop', {'receiverId': partnerId});
  }

  static Future<List<Message>> getMessages(String partnerId) async {
    final headers = await HttpClient.getAuthHeaders();

    final response = await HttpClient.get(
      '${ApiConfig.baseUrl}/messages/with/$partnerId',
      headers: headers,
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;

      return list.map((e) => Message.fromJson(e)).toList();
    }

    throw Exception('Failed to load messages');
  }

  static Future<List<Conversation>> getConversations() async {
    final headers = await HttpClient.getAuthHeaders();

    final response = await HttpClient.get(
      '${ApiConfig.baseUrl}/messages/conversations',
      headers: headers,
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;

      return list.map((e) => Conversation.fromJson(e)).toList();
    }

    throw Exception('Failed to load conversations');
  }

  /// Notifie le serveur de marquer les messages d'une conversation comme lus (émet "mark_read").
  static void markAsRead(String partnerId) {
    if (partnerId.isEmpty) return;
    _socket?.emit('mark_read', {'partnerId': partnerId});
  }

  static Future<int> getUnreadCount() async {
    final headers = await HttpClient.getAuthHeaders();

    final response = await HttpClient.get(
      '${ApiConfig.baseUrl}/messages/unread-count',
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['count'] ?? 0;
    }

    return 0;
  }
}
