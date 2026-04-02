import 'dart:ui' as ui;

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
import '../organizer/map_picker_screen.dart';

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
  final ScrollController _scrollCtrl = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _loading = true;
  String? _currentUserId;
  List<_UiMessage> _messages = [];
  io.Socket? _socket;
  bool _isRecordingVoice = false;
  bool _isRecordingPaused = false;
  bool _isUploadingImage = false;
  Timer? _recordTicker;
  int _recordElapsedSec = 0;
  String _playingMessageId = '';
  String _loadedAudioUrl = '';
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;

  // 🚀 SIMPLIFIED: Simple online status tracking
  bool _partnerOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🚀 FIX: Initialize with widget value
    _partnerOnline = widget.partnerOnline;

    _initVoicePlayer();
    _loadMessages();
    _initSocket();
  }

  @override
  void dispose() {
    print('🔴 [ChatScreen] DISPOSE: Forcing logout...');

    // 🚀 NEW: Force logout before disposing
    _socket?.emit('force_logout');

    // Small delay to ensure the event is sent
    Future.delayed(const Duration(milliseconds: 100), () {
      WidgetsBinding.instance.removeObserver(this);
      _socket?.disconnect();
      _socket?.dispose();
      _voicePlayer.stop();
      _voicePlayer.dispose();
      _audioRecorder.dispose();
      _recordTicker?.cancel();
      _msgCtrl.dispose();
      _scrollCtrl.dispose();
      super.dispose();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        print('⏸️ Chat going to background, forcing logout...');
        // 🚀 NEW: Force logout on app background
        _socket?.emit('force_logout');

        Future.delayed(const Duration(milliseconds: 100), () {
          _socket?.disconnect();
          _socket?.dispose();
          _socket = null;
        });
        return;

      case AppLifecycleState.resumed:
        print('▶️ Chat resumed, reconnecting socket');
        if (_socket == null) {
          _initSocket();
        }
        break;
    }
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
      }
    });
  }

  Future<void> _initSocket() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    // 🚀 SIMPLIFIED: Clean socket event handling
    socket.on('connect', (_) {
      print('🔗 Chat Socket connected successfully');
    });

    socket.on('disconnect', (reason) {
      print('🔌 Chat Socket disconnected: $reason');
    });

    socket.on('message_sent', (data) {
      _pushSocketMessage(data, forceMine: true);
    });

    socket.on('new_message', (data) {
      _pushSocketMessage(data);
    });

    // 🚀 CRITICAL: Proper user status handling
    socket.on('user_status', (data) {
      print('📡 [ChatScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;
      final timestamp = data['timestamp'];

      print(
        '🔄 [ChatScreen] Checking partner: widget.partnerId=${widget.partnerId}, received userId=$userId',
      );
      print(
        '🔄 [ChatScreen] Current _partnerOnline=$_partnerOnline, new isOnline=$isOnline',
      );

      if (userId == widget.partnerId) {
        print(
          '✅ [ChatScreen] UPDATING PARTNER STATUS to online=$isOnline at $timestamp',
        );
        setState(() {
          _partnerOnline = isOnline;
        });
        print(
          '✅ [ChatScreen] State updated. New _partnerOnline=$_partnerOnline',
        );
      } else {
        print('❌ [ChatScreen] User ID mismatch, ignoring status update');
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
          DateTime.now(), // 🚀 FIX: Handle null
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
        time: createdAt ?? DateTime.now(), // 🚀 FIX: Handle null createdAt
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
          (response['messageText'] ?? 'Unable to send message').toString(),
        ),
      ),
    );
  }

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _resolveMediaUrl(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    if (raw.startsWith('/')) return '$serverUrl$raw';
    return '$serverUrl/$raw';
  }

  bool _isImageMessage(_UiMessage msg) {
    if (msg.type == 'image') return true;
    final lower = msg.audioUrl.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isVoiceMessage(_UiMessage msg) {
    return msg.type == 'audio' || msg.type == 'voice';
  }

  Future<void> _toggleVoicePlayback(_UiMessage msg) async {
    final url = _resolveMediaUrl(msg.audioUrl);
    if (url.isEmpty) {
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
        await _voicePlayer.pause();
        return;
      }

      if (!sameSource) {
        await _voicePlayer.setUrl(Uri.encodeFull(url));
        _loadedAudioUrl = url;
      }

      if (!mounted) return;
      setState(() {
        _playingMessageId = msg.id;
        _voicePosition = Duration.zero;
      });

      await _voicePlayer.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play voice message.')),
      );
    }
  }

  void _onCallTap({required bool isVideo}) {
    if (!_partnerOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.partnerName} is offline')),
      );
      return;
    }

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

  Future<void> _startRecordingUi() async {
    if (_isRecordingVoice) return;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }

    try {
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
        _recordElapsedSec = 0;
        _isRecordingPaused = false;
      });

      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVoice || _isRecordingPaused) return;
        setState(() => _recordElapsedSec += 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start recording: $e')));
    }
  }

  Future<void> _togglePauseRecordingUi() async {
    if (!_isRecordingVoice) return;

    try {
      if (_isRecordingPaused) {
        await _audioRecorder.resume();
      } else {
        await _audioRecorder.pause();
      }

      if (!mounted) return;
      setState(() {
        _isRecordingPaused = !_isRecordingPaused;
      });

      _recordTicker?.cancel();
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVoice || _isRecordingPaused) return;
        setState(() => _recordElapsedSec += 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to pause recording: $e')));
    }
  }

  Future<void> _cancelRecordingUi() async {
    if (!_isRecordingVoice) return;
    _recordTicker?.cancel();

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {}

    if (filePath != null && filePath.isNotEmpty) {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordElapsedSec = 0;
    });
  }

  Future<void> _sendRecordingUi() async {
    if (!_isRecordingVoice) return;
    final elapsed = _recordElapsedSec;

    _recordTicker?.cancel();

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordElapsedSec = 0;
    });

    if (filePath == null || filePath.isEmpty || elapsed < 1) {
      if (filePath != null && filePath.isNotEmpty) {
        final f = File(filePath);
        if (await f.exists()) {
          await f.delete();
        }
      }
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

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingImage) return;

    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      final response = await MessageService.sendImageMessage(
        partnerId: widget.partnerId,
        imageFile: File(picked.path),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        await _loadMessages();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['messageText'] ?? 'Unable to send image').toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _pickAndSendLocation() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (!mounted || result == null) return;

    final lat = result.latLng.latitude.toStringAsFixed(6);
    final lng = result.latLng.longitude.toStringAsFixed(6);
    final locationText =
        'Location: ${result.address}\nhttps://maps.google.com/?q=$lat,$lng';

    final response = await MessageService.sendMessage(
      partnerId: widget.partnerId,
      content: locationText,
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
          (response['messageText'] ?? 'Unable to share location').toString(),
        ),
      ),
    );
  }

  Future<void> _openAttachmentSheet() async {
    if (_isUploadingImage) return;

    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _attachmentTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF315CFF),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                _attachmentTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  color: const Color(0xFF0EA5E9),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                _attachmentTile(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  color: const Color(0xFF22C55E),
                  onTap: () => Navigator.pop(ctx, 'location'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selection == null) return;

    if (selection == 'gallery') {
      await _pickImage(ImageSource.gallery);
      return;
    }

    if (selection == 'camera') {
      await _pickImage(ImageSource.camera);
      return;
    }

    if (selection == 'location') {
      await _pickAndSendLocation();
    }
  }

  Widget _attachmentTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E2A4A),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'TODAY';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildHeader(ColorScheme cs) {
    final partnerAvatar = widget.partnerAvatar;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: cs.surfaceVariant,
                          backgroundImage: partnerAvatar != null
                              ? NetworkImage(partnerAvatar)
                              : null,
                          child: partnerAvatar == null
                              ? Icon(
                                  Icons.person,
                                  size: 19,
                                  color: cs.onSurfaceVariant,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _partnerOnline
                                  ? const Color(0xFF22C55E)
                                  : cs.outline,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _partnerOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: _partnerOnline
                                  ? const Color(0xFF22C55E)
                                  : cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
            icon: Icon(Icons.call_rounded, color: cs.primary),
            tooltip: 'Voice call',
          ),
          IconButton(
            onPressed: () => _onCallTap(isVideo: true),
            icon: Icon(Icons.videocam_rounded, color: cs.primary),
            tooltip: 'Video call',
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
            tooltip: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withOpacity(0.1),
              ),
              child: Icon(Icons.forum_outlined, color: cs.primary, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              'No messages yet',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the conversation with your first message.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return _buildEmptyState(cs);
    }

    return ListView.builder(
      controller: _scrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final previous = i > 0 ? _messages[i - 1] : null;
        final showDay =
            previous == null || !_isSameDay(previous.time, msg.time);

        return Column(
          children: [
            if (showDay)
              Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _dayLabel(msg.time),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      letterSpacing: 1.4,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            _buildMessageItem(msg, cs),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem(_UiMessage msg, ColorScheme cs) {
    final isMine = msg.isMine;
    final bubbleColor = isMine ? AppColors.primary : const Color(0xFFFDFEFF);
    final textColor = isMine ? Colors.white : const Color(0xFF1E293B);
    final timeColor = cs.onSurfaceVariant.withOpacity(0.82);
    final partnerAvatar = widget.partnerAvatar;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 18),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: cs.surfaceVariant,
                  backgroundImage: partnerAvatar != null
                      ? NetworkImage(partnerAvatar)
                      : null,
                  child: partnerAvatar == null
                      ? Icon(Icons.person, size: 13, color: cs.onSurfaceVariant)
                      : null,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isMine
                          ? null
                          : Border.all(
                              color: const Color(0xFFD5DDF0),
                              width: 1,
                            ),
                      boxShadow: isMine
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(
                                  0xFF94A3B8,
                                ).withOpacity(0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: _buildMessageContent(msg, textColor, cs),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatClock(msg.time),
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: msg.isRead
                              ? const Color(0xFF315CFF)
                              : cs.onSurfaceVariant.withOpacity(0.7),
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

  Widget _buildMessageContent(_UiMessage msg, Color textColor, ColorScheme cs) {
    if (_isVoiceMessage(msg)) {
      final isCurrent = _playingMessageId == msg.id;
      final duration = isCurrent && _voiceDuration.inSeconds > 0
          ? _voiceDuration
          : Duration(seconds: msg.durationSec);
      final progress = isCurrent && duration.inMilliseconds > 0
          ? (_voicePosition.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
          : 0.0;

      return SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleVoicePlayback(msg),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FB),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE0E7F3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isCurrent && _voicePlayer.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: const Color(0xFF111827),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildAudioWave(progress),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration.inSeconds),
                  style: TextStyle(
                    color: const Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isImageMessage(msg)) {
      final url = _resolveMediaUrl(msg.audioUrl);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 230,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 230,
                  height: 170,
                  alignment: Alignment.center,
                  color: cs.surfaceVariant,
                  child: Text(
                    'Image unavailable',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          if (msg.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
            ),
          ],
        ],
      );
    }

    return Text(
      msg.text,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
  }

  Widget _buildAudioWave(double progress) {
    final heights = <double>[10, 18, 12, 26, 20, 32, 22, 14, 18, 12, 24, 16];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights.asMap().entries.map((entry) {
        final index = entry.key;
        final height = entry.value;
        final threshold = (index + 1) / heights.length;
        final active = progress >= threshold;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF315CFF) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordingWave() {
    final bars = <double>[26, 44, 60, 74, 96, 58, 44, 60, 40, 30];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: bars.asMap().entries.map((entry) {
        final index = entry.key;
        final h = entry.value;
        final isPrimary = index == 4;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 8,
            height: h,
            decoration: BoxDecoration(
              color: isPrimary
                  ? const Color(0xFF315CFF)
                  : const Color(0xFF9FB6FF),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordingComposer(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315CFF).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE879A3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(_recordElapsedSec),
                style: const TextStyle(
                  color: Color(0xFF1E2A4A),
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'RECORDING AUDIO...',
            style: TextStyle(
              color: Color(0xFF55638A),
              letterSpacing: 3,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          _buildRecordingWave(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleActionButton(
                icon: _isRecordingPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                bg: const Color(0xFFDFE5FF),
                fg: const Color(0xFF2B3657),
                size: 52,
                onTap: _togglePauseRecordingUi,
              ),
              _circleActionButton(
                icon: Icons.send_rounded,
                bg: const Color(0xFF315CFF),
                fg: Colors.white,
                size: 64,
                onTap: _sendRecordingUi,
              ),
              _circleActionButton(
                icon: Icons.delete_rounded,
                bg: const Color(0xFFF4E2EE),
                fg: const Color(0xFFE11D48),
                size: 52,
                onTap: _cancelRecordingUi,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleActionButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: fg.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: fg, size: size * 0.44),
      ),
    );
  }

  Widget _buildTextComposer(ColorScheme cs) {
    final text = _msgCtrl.text.trim();
    final canSend = text.isNotEmpty;

    // Définissons une taille commune pour les deux boutons d'action
    // pour une meilleure harmonie visuelle.
    const double actionButtonSize = 38.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // --- BOUTON AJOUT (GAUCHE) ---
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 2),
          child: InkWell(
            onTap: _openAttachmentSheet,
            borderRadius: BorderRadius.circular(actionButtonSize / 2),
            child: Container(
              width: actionButtonSize,
              height: actionButtonSize,
              decoration: BoxDecoration(
                color: const Color(0xFF90A0BB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
        ),

        // --- CHAMP DE TEXTE (CENTRE) ---
        Expanded(
          child: TextField(
            controller: _msgCtrl,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: const TextStyle(
                color: Color(0xFF6C7C97),
                fontSize: 15,
              ),

              // On active le remplissage ici
              filled: true,
              fillColor: const Color(0xFFE8EDF5), // La couleur grise unie
              // On définit les bordures (none) mais avec un border radius
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),

              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),

        // --- ESPACEMENT ---
        const SizedBox(width: 8), // Un peu moins d'espace pour le raffinement
        // --- BOUTON ACTION (DROITE) ---
        Padding(
          // Un petit padding en bas pour qu'il s'aligne visuellement
          // avec la base du champ de texte
          padding: const EdgeInsets.only(bottom: 2),
          child: InkWell(
            onTap: canSend ? _send : _startRecordingUi,
            onLongPress: !canSend ? _startRecordingUi : null,
            borderRadius: BorderRadius.circular(actionButtonSize / 2),
            child: Container(
              // CORRECTION : Nous utilisons la même taille commune
              width: actionButtonSize,
              height: actionButtonSize,
              decoration: BoxDecoration(
                color: const Color(0xFF315CFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    // CORRECTION : Ombre plus discrète et plus proche du bouton
                    color: const Color(0xFF315CFF).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                canSend ? Icons.send_rounded : Icons.mic_rounded,
                color: Colors.white,
                // CORRECTION : Icône légèrement plus petite pour un bouton plus petit
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomComposer(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: _isRecordingVoice
            ? _buildRecordingComposer(cs)
            : _buildTextComposer(cs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceVariant,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(cs),
              Expanded(child: _buildMessageList(cs)),
              if (!_isRecordingVoice) _buildBottomComposer(cs),
            ],
          ),
          if (_isRecordingVoice)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.white.withOpacity(0.18)),
                ),
              ),
            ),
          if (_isRecordingVoice)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildRecordingComposer(cs)),
            ),
        ],
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
  final bool isMine; // 🚀 FIX: Make sure this property exists
  final DateTime time;
  final bool isRead;
  final DateTime? readAt;

  _UiMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.audioUrl,
    required this.durationSec,
    required this.isMine, // 🚀 FIX: Required parameter
    required this.time,
    required this.isRead,
    this.readAt,
  });
}
