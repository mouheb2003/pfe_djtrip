import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import 'public_organizer_profile_screen.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import '../../services/call_sound_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final bool partnerOnline;

  const ChatConversationScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerOnline = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _editCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _loading = true;
  String? _currentUserId;
  List<_UiMessage> _messages = [];
  io.Socket? _socket;
  bool _isRecordingVoice = false;
  bool _isVoicePaused = false;
  Timer? _recordTicker;
  int _recordElapsedSec = 0;
  double _recordSlideOffset = 0;
  bool _slideCancelTriggered = false;
  bool _isSendingVideo = false;
  String _playingMessageId = '';
  String _loadedAudioUrl = '';
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  String _editingMessageId = '';
  String _editingOriginalText = '';
  bool _isSavingEdit = false;
  late bool _partnerOnline;
  bool _isExplicitlyDisconnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _partnerOnline = widget.partnerOnline;
    _initVoicePlayer();
    _msgCtrl.addListener(_onDraftChanged);
    _loadMessages();
    _initSocket();
  }

  @override
  void dispose() {
    _isExplicitlyDisconnected = true;
    WidgetsBinding.instance.removeObserver(this);
    _socket?.disconnect();
    _socket?.dispose();
    unawaited(_voicePlayer.stop().catchError((_) {}));
    unawaited(_voicePlayer.dispose().catchError((_) {}));
    _audioRecorder.dispose();
    _recordTicker?.cancel();
    _msgCtrl.removeListener(_onDraftChanged);
    _msgCtrl.dispose();
    _editCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showIncomingCallDialog({
    required String type,
    Map<String, dynamic>? offer,
  }) {
    CallSoundService.playIncoming();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.partnerName} is calling you'),
        content: Text(
          type == 'video'
              ? 'Incoming video call'
              : 'Incoming audio call',
        ),
        actions: [
          TextButton(
            onPressed: () {
              CallSoundService.stop();
              _socket?.emit('call:reject', {'callerId': widget.partnerId});
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              CallSoundService.stop();
              Navigator.of(ctx).pop(true);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => type == 'video'
                      ? VideoCallScreen(
                          partnerId: widget.partnerId,
                          name: widget.partnerName,
                          avatarUrl: widget.partnerAvatar ?? '',
                          isInitiator: false,
                          socket: _socket,
                          initialOffer: offer,
                        )
                      : VoiceCallScreen(
                          partnerId: widget.partnerId,
                          name: widget.partnerName,
                          avatarUrl: widget.partnerAvatar ?? '',
                          subtitle: 'Calling from DJTrip',
                          isInitiator: false,
                          socket: _socket,
                          initialOffer: offer,
                        ),
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _initVoicePlayer() {
    _voicePlayer.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _voicePosition = p);
    });

    _voicePlayer.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _voiceDuration = d);
    });

    _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingMessageId = '';
          _voicePosition = Duration.zero;
        });
      } else {
        setState(() {});
      }
    });
  }

  void _onDraftChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        print('⏸️ Chat going to background/hidden, disconnecting socket');
        _isExplicitlyDisconnected = true;
        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        return;

      case AppLifecycleState.resumed:
        print('▶️ Chat resumed, reconnecting socket');
        _isExplicitlyDisconnected = false;
        if (_socket == null) {
          _initSocket();
        }
        break;
    }
  }

  String _resolveAudioUrl(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    if (raw.startsWith('/')) return '$serverUrl$raw';
    return '$serverUrl/$raw';
  }

  String _cloudinaryMp3Fallback(String url) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return '';
    }
    return url.replaceFirst('/upload/', '/upload/f_mp3/');
  }

  Future<void> _toggleAudioPlayback(_UiMessage msg) async {
    final url = _resolveAudioUrl(msg.audioUrl);
    print('[AUDIO] URL used: $url');
    if (url.isEmpty) {
      print('[AUDIO] Empty or invalid URL');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio unavailable for this message.')),
      );
      return;
    }

    try {
      final isCurrent = _playingMessageId == msg.id;
      final sameSource = _loadedAudioUrl == url;

      if (isCurrent && _voicePlayer.playing) {
        print('[AUDIO] Pause audio');
        await _voicePlayer.pause();
        return;
      }

      if (!sameSource) {
        print('[AUDIO] Loading new source');
        await _voicePlayer.setUrl(Uri.encodeFull(url));
        _loadedAudioUrl = url;
      }

      if (!mounted) return;
      setState(() {
        _playingMessageId = msg.id;
        _voicePosition = Duration.zero;
      });

      print('[AUDIO] Playing...');
      await _voicePlayer.play();
      print('[AUDIO] Playback started');
    } catch (e) {
      print('[AUDIO] Playback error: $e');
      final fallback = _cloudinaryMp3Fallback(url);
      if (fallback.isNotEmpty && fallback != _loadedAudioUrl) {
        try {
          print('[AUDIO] Trying Cloudinary fallback: $fallback');
          await _voicePlayer.setUrl(Uri.encodeFull(fallback));
          _loadedAudioUrl = fallback;

          if (!mounted) return;
          setState(() {
            _playingMessageId = msg.id;
            _voicePosition = Duration.zero;
          });

          await _voicePlayer.play();
          print('[AUDIO] Fallback playback started');
          return;
        } catch (e2) {
          print('[AUDIO] Fallback error: $e2');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play voice message.')),
      );
    }
  }

  Future<void> _initSocket() async {
    if (_isExplicitlyDisconnected) return; // Don't reconnect if explicitly disconnected

    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionDelay(1000) // Better reconnection settings
          .setReconnectionAttempts(5)
          .setTimeout(20000)
          .build(),
    );

    // Better connection event handling
    socket.on('connect', (_) {
      print('Chat Socket connected successfully');
      _isExplicitlyDisconnected = false;
    });

    socket.on('disconnect', (reason) {
      print('Chat Socket disconnected: $reason');
      if (reason == 'io server disconnect') {
        _isExplicitlyDisconnected = true;
      }
    });

    socket.on('reconnect', (_) {
      print('Chat Socket reconnected');
      _loadMessages(); // Recharger les messages
    });

    socket.on('message_sent', (data) {
      _pushSocketMessage(data, forceMine: true);
    });

    socket.on('new_message', (data) {
      _pushSocketMessage(data);
    });

    socket.on('call:incoming', (data) {
      if (!mounted) return;
      if (data is! Map) return;
      final callerId = (data['callerId'] ?? '').toString();
      if (callerId != widget.partnerId) return;
      final type = (data['type'] ?? 'audio').toString();
      final offer = data['offer'] as Map<String, dynamic>?;
      _showIncomingCallDialog(type: type, offer: offer);
    });

    socket.on('user_status', (data) {
      print('📡 [ChatScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;

      if (userId == widget.partnerId) {
        print('🔄 [ChatScreen] Updating partner $userId to online=$isOnline');
        setState(() {
          _partnerOnline = isOnline;
        });
      }
    });

    socket.connect();
    _socket = socket;
  }

  void _pushSocketMessage(dynamic data, {bool forceMine = false}) {
    if (!mounted) return;
    if (data is! Map) return;

    final sender = (data['sender_id'] ?? '').toString();
    final receiver = (data['receiver_id'] ?? '').toString();
    final me = _currentUserId ?? '';
    final partner = widget.partnerId;

    final belongsToCurrentChat =
        (sender == partner && receiver == me) ||
        (sender == me && receiver == partner);
    if (!belongsToCurrentChat && !forceMine) return;

    final msg = _UiMessage(
      id: (data['_id'] ?? '').toString(),
      text: (data['content'] ?? '').toString(),
      type: (data['message_type'] ?? 'text').toString(),
      audioUrl: (data['media_url'] ?? '').toString(),
      durationSec: (data['media_duration'] as num?)?.toInt() ?? 0,
      isMine: forceMine || sender == me,
      time:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: (data['is_read'] == true),
      readAt: DateTime.tryParse((data['read_at'] ?? '').toString()),
    );

    setState(() {
      if (_messages.any((m) => m.id == msg.id && msg.id.isNotEmpty)) {
        return;
      }
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    final userId = await AuthService.getUserId();
    final raw = await MessageService.getMessages(widget.partnerId);
    if (!mounted) return;

    final mapped = raw.map((m) {
      final sender = (m['sender_id'] ?? '').toString();
      final createdAt = DateTime.tryParse((m['createdAt'] ?? '').toString());
      final readAtRaw = DateTime.tryParse((m['read_at'] ?? '').toString());
      final readAt = readAtRaw != null && !readAtRaw.isBefore(DateTime(2000))
          ? readAtRaw
          : null;
      return _UiMessage(
        id: (m['_id'] ?? '').toString(),
        text: (m['content'] ?? '').toString(),
        type: (m['message_type'] ?? 'text').toString(),
        audioUrl: (m['media_url'] ?? '').toString(),
        durationSec: (m['media_duration'] as num?)?.toInt() ?? 0,
        isMine: sender == (userId ?? ''),
        time: createdAt,
        isRead: (m['is_read'] == true),
        readAt: readAt,
      );
    }).toList();

    setState(() {
      _currentUserId = userId;
      _messages = mapped;
      _loading = false;
    });

    _scrollToBottom();
    _socket?.emit('mark_read', {'partnerId': widget.partnerId});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );

      // A second pass helps when item heights settle after initial frame.
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!_scrollCtrl.hasClients) return;
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final response = await MessageService.sendMessage(
      partnerId: widget.partnerId,
      content: text,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final payload = response['message'] as Map<String, dynamic>;
      _pushSocketMessage(payload, forceMine: true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (response['messageText'] ?? 'Unable to send message')
              .toString(),
        ),
      ),
    );
  }

  void _onCallTap({required bool isVideo}) {
    if (!_partnerOnline) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${widget.partnerName} is offline'),
          content: const Text(
            "They won't receive the call until they come online. Do you still want to call?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToCallScreen(isVideo: isVideo);
              },
              child: const Text('Call anyway'),
            ),
          ],
        ),
      );
      return;
    }
    _navigateToCallScreen(isVideo: isVideo);
  }

  void _navigateToCallScreen({required bool isVideo}) {
    if (isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            partnerId: widget.partnerId,
            name: widget.partnerName,
            avatarUrl: widget.partnerAvatar ?? '',
            isInitiator: true,
            socket: _socket,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
            partnerId: widget.partnerId,
            name: widget.partnerName,
            avatarUrl: widget.partnerAvatar ?? '',
            subtitle: 'Calling from DJTrip',
            isInitiator: true,
            socket: _socket,
          ),
        ),
      );
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice) return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
        return;
      }

      final tmp = await getTemporaryDirectory();
      final path =
          '${tmp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _isVoicePaused = false;
        _recordElapsedSec = 0;
        _recordSlideOffset = 0;
        _slideCancelTriggered = false;
      });

      _startRecordTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _isVoicePaused = false;
        _recordElapsedSec = 0;
        _recordSlideOffset = 0;
        _slideCancelTriggered = false;
      });
      _recordTicker?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start voice recording: $e')),
      );
    }
  }

  void _startRecordTicker() {
    _recordTicker?.cancel();
    _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecordingVoice || _isVoicePaused) return;
      setState(() {
        _recordElapsedSec += 1;
      });
    });
  }

  Future<void> _toggleVoicePause() async {
    if (!_isRecordingVoice) return;

    try {
      if (_isVoicePaused) {
        await _audioRecorder.resume();
        if (!mounted) return;
        setState(() {
          _isVoicePaused = false;
        });
        _startRecordTicker();
      } else {
        await _audioRecorder.pause();
        _recordTicker?.cancel();
        if (!mounted) return;
        setState(() {
          _isVoicePaused = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to pause/resume recording.'),
        ),
      );
    }
  }

  Future<void> _stopVoiceRecordingAndSend() async {
    if (!_isRecordingVoice) return;
    String? filePath;
    final elapsed = _recordElapsedSec;

    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error stopping voice recording.')),
          );
      }
    }

    _recordTicker?.cancel();

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _isVoicePaused = false;
      _recordSlideOffset = 0;
      _slideCancelTriggered = false;
      _recordElapsedSec = 0;
    });

    if (filePath == null || filePath.isEmpty) return;
    if (elapsed < 1) {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice message too short.')));
      return;
    }

    final res = await MessageService.sendAudioMessage(
      partnerId: widget.partnerId,
      audioFile: File(filePath),
      durationSec: elapsed,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      final payload = res['message'] as Map<String, dynamic>;
      _pushSocketMessage(payload, forceMine: true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (res['messageText'] ?? 'Unable to send voice message').toString(),
        ),
      ),
    );
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecordingVoice) return;

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {}

    _recordTicker?.cancel();

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _isVoicePaused = false;
      _recordSlideOffset = 0;
      _slideCancelTriggered = false;
      _recordElapsedSec = 0;
    });

    if (filePath != null && filePath.isNotEmpty) {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  void _onRecordSlideUpdate(DragUpdateDetails details) {
    if (!_isRecordingVoice) return;
    final next = (_recordSlideOffset + details.delta.dx).clamp(-130.0, 0.0);
    setState(() {
      _recordSlideOffset = next;
    });

    if (next <= -100 && !_slideCancelTriggered) {
      _slideCancelTriggered = true;
      _cancelVoiceRecording();
    }
  }

  void _onRecordSlideEnd(DragEndDetails details) {
    if (!_isRecordingVoice) return;
    setState(() {
      _recordSlideOffset = 0;
    });
  }

  String _recordDurationLabel(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _chatDateLabel() {
    final months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _resolvedPartnerAvatar() {
    return widget.partnerAvatar ?? '';
  }

  void _openAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        Widget action(IconData icon, String label, {VoidCallback? onTap}) {
          return SizedBox(
            width: 110,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DCE6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 18,
                  runSpacing: 20,
                  children: [
                    action(
                      Icons.image,
                      'Photo & Video',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendVideo();
                      },
                    ),
                    action(Icons.location_on, 'Location'),
                    action(Icons.description, 'Document'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(
    _UiMessage msg,
    Offset globalPosition,
  ) async {
    if (!msg.isMine || msg.id.isEmpty || msg.id.startsWith('local_')) return;
    final canEdit = msg.type == 'text';

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 172, maxWidth: 188),
      items: [
        if (canEdit)
          const PopupMenuItem<String>(
            value: 'edit',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.edit, color: Color(0xFFF97316), size: 18),
                SizedBox(width: 10),
                Text(
                  'Edit Message',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F2747),
                  ),
                ),
              ],
            ),
          ),
        if (canEdit) const PopupMenuDivider(height: 6),
        const PopupMenuItem<String>(
          value: 'delete',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.delete, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 10),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      _startInlineEdit(msg);
    } else if (action == 'delete') {
      await _deleteMessage(msg);
    }
  }

  void _startInlineEdit(_UiMessage msg) {
    if (!msg.isMine || msg.id.isEmpty || msg.type != 'text') return;
    setState(() {
      _editingMessageId = msg.id;
      _editingOriginalText = msg.text;
      _editCtrl.text = msg.text;
      _isSavingEdit = false;
    });
    _scrollToBottom();
  }

  void _cancelInlineEdit() {
    if (_editingMessageId.isEmpty) return;
    setState(() {
      _editingMessageId = '';
      _editingOriginalText = '';
      _editCtrl.clear();
      _isSavingEdit = false;
    });
  }

  Future<void> _saveInlineEdit() async {
    if (_editingMessageId.isEmpty || _isSavingEdit) return;
    final edited = _editCtrl.text.trim();

    if (edited.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot be empty.')),
      );
      return;
    }

    if (edited == _editingOriginalText.trim()) {
      _cancelInlineEdit();
      return;
    }

    setState(() => _isSavingEdit = true);

    final res = await MessageService.editMessage(
      messageId: _editingMessageId,
      content: edited,
    );
    if (!mounted) return;

    if (res['success'] == true) {
      final payload = res['message'] as Map<String, dynamic>;
      final updatedText = (payload['content'] ?? edited).toString();
      setState(() {
        _messages = _messages
            .map(
              (m) =>
                  m.id == _editingMessageId ? m.copyWith(text: updatedText) : m,
            )
            .toList();
        _editingMessageId = '';
        _editingOriginalText = '';
        _editCtrl.clear();
        _isSavingEdit = false;
      });
      return;
    }

    setState(() => _isSavingEdit = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (res['messageText'] ?? 'Unable to edit this message')
              .toString(),
        ),
      ),
    );
  }

  Future<void> _pickAndSendVideo() async {
    if (_isSendingVideo) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isSendingVideo = true);

      final res = await MessageService.sendVideoMessage(
        partnerId: widget.partnerId,
        videoFile: File(picked.path),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final payload = res['message'] as Map<String, dynamic>;
        _pushSocketMessage(payload, forceMine: true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (res['messageText'] ?? 'Unable to send video').toString(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select/send video.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingVideo = false);
      }
    }
  }

  Future<void> _deleteMessage(_UiMessage msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete Message?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to delete this message? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || confirm != true) return;

    final ok = await MessageService.deleteMessage(msg.id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
        if (_editingMessageId == msg.id) {
          _editingMessageId = '';
          _editingOriginalText = '';
          _editCtrl.clear();
          _isSavingEdit = false;
        }
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to delete this message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerAvatarUrl = _resolvedPartnerAvatar();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceVariant,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(bottom: BorderSide(color: cs.outline)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: cs.onSurface),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicOrganizerProfileScreen(
                              organizerId: widget.partnerId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.surfaceVariant,
                              backgroundImage: partnerAvatarUrl.isNotEmpty
                                  ? NetworkImage(partnerAvatarUrl)
                                  : null,
                              child: partnerAvatarUrl.isEmpty
                                  ? Icon(Icons.person,
                                      color: cs.onSurfaceVariant)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.partnerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    _partnerOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _partnerOnline
                                          ? const Color(0xFF22C55E) // Vert pour online
                                          : Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _onCallTap(isVideo: false),
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    tooltip: 'Audio call',
                  ),
                  IconButton(
                    onPressed: () => _onCallTap(isVideo: true),
                    icon: const Icon(Icons.videocam, color: AppColors.primary),
                    tooltip: 'Video call',
                  ),
                  IconButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('More options coming soon.'),
                      ),
                    ),
                    icon: const Icon(Icons.more_vert, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollCtrl,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        14,
                        12,
                        28 + MediaQuery.of(context).viewPadding.bottom,
                      ),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _chatDateLabel(),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          );
                        }

                        final msg = _messages[i - 1];
                        return _MessageBubble(
                          msg: msg,
                          partnerAvatarUrl: partnerAvatarUrl,
                          isEditing: _editingMessageId == msg.id,
                          onAudioTap: msg.type == 'audio'
                              ? () => _toggleAudioPlayback(msg)
                              : null,
                          isAudioPlaying:
                              _playingMessageId == msg.id &&
                              _voicePlayer.playing,
                          audioProgress:
                              _playingMessageId == msg.id &&
                                  _voiceDuration.inMilliseconds > 0
                              ? (_voicePosition.inMilliseconds /
                                        _voiceDuration.inMilliseconds)
                                    .clamp(0.0, 1.0)
                              : 0.0,
                          audioPosition: _playingMessageId == msg.id
                              ? _voicePosition
                              : Duration.zero,
                          audioDuration: _playingMessageId == msg.id
                              ? _voiceDuration
                              : Duration(seconds: msg.durationSec),
                          onLongPressStart: msg.isMine
                              ? (details) => _showMessageActions(
                                  msg,
                                  details.globalPosition,
                                )
                              : null,
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE8ECF1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editingMessageId.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAF5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFF3C6A2),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.edit,
                                color: Color(0xFFF97316),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'EDIT MESSAGE',
                                style: TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: _cancelInlineEdit,
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Color(0xFFB0B6C3),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7F9),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: TextField(
                              controller: _editCtrl,
                              maxLines: 3,
                              minLines: 1,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              style: const TextStyle(
                                fontSize: 17,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _isSavingEdit
                                      ? null
                                      : _cancelInlineEdit,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSavingEdit ||
                                          _editCtrl.text.trim().isEmpty
                                      ? null
                                      : _saveInlineEdit,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 5,
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFFFCD9BE,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shadowColor: Colors.orange.withOpacity(
                                      0.18,
                                    ),
                                  ),
                                  icon: _isSavingEdit
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.check, size: 18),
                                  label: const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      if (_isRecordingVoice) ...[
                        GestureDetector(
                          onTap: _cancelVoiceRecording,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragUpdate: _onRecordSlideUpdate,
                            onHorizontalDragEnd: _onRecordSlideEnd,
                            child: Transform.translate(
                              offset: Offset(_recordSlideOffset, 0),
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF3F6),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.fiber_manual_record,
                                      color: Color(0xFFF87171),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _recordDurationLabel(_recordElapsedSec),
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Icon(
                                      Icons.chevron_left,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Slide to cancel',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _toggleVoicePause,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF97316),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isVoicePaused
                                              ? Icons.play_arrow
                                              : Icons.pause,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _stopVoiceRecordingAndSend,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF97316),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: _openAttachmentSheet,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6DEE8),
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _msgCtrl,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText: 'Type a message',
                                hintStyle: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        (_msgCtrl.text.trim().isEmpty && !_isSendingVideo)
                            ? GestureDetector(
                                onTap: _startVoiceRecording,
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD6DEE8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mic,
                                    color: Color(0xFF64748B),
                                    size: 24,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: _isSendingVideo ? null : _send,
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _isSendingVideo
                                        ? const Color(0xFF94A3B8)
                                        : AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isSendingVideo
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                ),
                              ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiMessage {
  final String id;
  final String text;
  final String type;
  final String audioUrl;
  final int durationSec;
  final bool isMine;
  final DateTime? time;
  final bool isRead;
  final DateTime? readAt;

  const _UiMessage({
    required this.id,
    required this.text,
    this.type = 'text',
    this.audioUrl = '',
    this.durationSec = 0,
    required this.isMine,
    this.time,
    this.isRead = false,
    this.readAt,
  });

  _UiMessage copyWith({
    String? id,
    String? text,
    String? type,
    String? audioUrl,
    int? durationSec,
    bool? isMine,
    DateTime? time,
    bool? isRead,
    DateTime? readAt,
  }) {
    return _UiMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSec: durationSec ?? this.durationSec,
      isMine: isMine ?? this.isMine,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _UiMessage msg;
  final String partnerAvatarUrl;
  final bool isEditing;
  final VoidCallback? onAudioTap;
  final bool isAudioPlaying;
  final double audioProgress;
  final Duration audioPosition;
  final Duration audioDuration;
  final ValueChanged<LongPressStartDetails>? onLongPressStart;

  const _MessageBubble({
    required this.msg,
    required this.partnerAvatarUrl,
    this.isEditing = false,
    this.onAudioTap,
    this.isAudioPlaying = false,
    this.audioProgress = 0.0,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.onLongPressStart,
  });

  String get _time {
    if (msg.time == null) return '';
    final h = msg.time!.hour.toString().padLeft(2, '0');
    final m = msg.time!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get _looksEmojiOnly {
    if (msg.type != 'text') return false;
    final t = msg.text.trim();
    if (t.isEmpty) return false;
    final hasAlphaNum = RegExp(r'[A-Za-z0-9]').hasMatch(t);
    return !hasAlphaNum && t.runes.length <= 3;
  }

  Widget _incomingAvatar() {
    if (partnerAvatarUrl.isEmpty) {
      return Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(right: 6, bottom: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
      );
    }

    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 6, bottom: 14),
      child: ClipOval(
        child: Image.network(
          partnerAvatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFE2E8F0),
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editingTextBubble = isEditing && msg.isMine && msg.type == 'text';
    final bubbleColor = editingTextBubble
        ? const Color(0xFFF8F4EF)
        : (msg.isMine ? AppColors.primary : Colors.white);
    final txtColor = editingTextBubble
        ? const Color(0xFF0F172A)
        : (msg.isMine ? Colors.white : const Color(0xFF0B163B));
    final bubbleRadius = BorderRadius.circular(16);
    final textPadding = _looksEmojiOnly
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 11);

    Widget bubbleChild;
    if (msg.type == 'audio') {
      bubbleChild = _AudioMessageContent(
        isMine: msg.isMine,
        isPlaying: isAudioPlaying,
        progress: audioProgress,
        position: audioPosition,
        duration: audioDuration.inSeconds > 0
            ? audioDuration
            : Duration(seconds: msg.durationSec),
        onTap: onAudioTap,
      );
    } else if (msg.type == 'video') {
      bubbleChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: txtColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'Video message',
            style: TextStyle(
              color: txtColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      bubbleChild = Text(
        msg.text.trim(),
        style: TextStyle(
          color: txtColor,
          fontSize: _looksEmojiOnly ? 22 : 16,
          height: 1.35,
        ),
      );
    }

    final bubble = GestureDetector(
      onLongPressStart: onLongPressStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(top: 8),
        padding: textPadding,
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: bubbleRadius,
          border: editingTextBubble
              ? Border.all(color: const Color(0xFFF97316), width: 2)
              : (msg.isMine
                    ? null
                    : Border.all(color: const Color(0xFFE5EAF0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: bubbleChild,
      ),
    );

    String readLabel = '';
    if (msg.isMine && msg.isRead) {
      if (msg.readAt != null) {
        final h = msg.readAt!.hour.toString().padLeft(2, '0');
        final m = msg.readAt!.minute.toString().padLeft(2, '0');
        readLabel = 'Seen at $h:$m';
      } else {
        readLabel = 'Seen';
      }
    }

    final timeLabel = Padding(
      padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _time,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (readLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.done_all, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  readLabel,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final bubbleAndTime = Column(
      crossAxisAlignment: msg.isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (editingTextBubble)
          const Padding(
            padding: EdgeInsets.only(bottom: 4, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: Color(0xFFF97316), size: 14),
                SizedBox(width: 6),
                Text(
                  'Editing message...',
                  style: TextStyle(
                    color: Color(0xFFF97316),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        bubble,
        timeLabel,
      ],
    );

    return Align(
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: msg.isMine
          ? bubbleAndTime
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [_incomingAvatar(), bubbleAndTime],
            ),
    );
  }
}

class _AudioMessageContent extends StatelessWidget {
  final bool isMine;
  final bool isPlaying;
  final double progress;
  final Duration position;
  final Duration duration;
  final VoidCallback? onTap;

  const _AudioMessageContent({
    required this.isMine,
    required this.isPlaying,
    required this.progress,
    required this.position,
    required this.duration,
    this.onTap,
  });

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final baseFg = isMine ? Colors.white : const Color(0xFF0B163B);
    final subFg = isMine
        ? Colors.white.withOpacity(0.84)
        : const Color(0xFF64748B);
    final controlBg = isMine
        ? Colors.white.withOpacity(0.22)
        : const Color(0xFFF1F5F9);

    final effectiveDuration = duration.inSeconds > 0
        ? duration
        : const Duration(seconds: 0);
    final safeProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: 210,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: controlBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: baseFg,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPlaying ? 'Playing message' : 'Voice message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: baseFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                _WaveformBar(progress: safeProgress, isMine: isMine),
                const SizedBox(height: 6),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(effectiveDuration)}',
                  style: TextStyle(
                    color: subFg,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  final double progress;
  final bool isMine;

  const _WaveformBar({required this.progress, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final active = isMine ? Colors.white : const Color(0xFFF97316);
    final idle = isMine
        ? Colors.white.withOpacity(0.35)
        : const Color(0xFFCBD5E1);

    final bars = <double>[3, 6, 9, 5, 10, 4, 8, 11, 7, 4, 10, 5, 8, 4, 7, 10];

    return SizedBox(
      height: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (i) {
          final threshold = (i + 1) / bars.length;
          final color = progress >= threshold ? active : idle;
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 2.8,
                height: bars[i],
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
