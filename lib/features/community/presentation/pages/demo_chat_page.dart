import 'package:flutter/material.dart';

import '../../../social_demo/data/demo_social_data.dart';
import 'demo_call_page.dart';

/// Màn hội thoại có thể nhập và gửi tin cục bộ, không có network/chat backend.
class DemoChatPage extends StatefulWidget {
  const DemoChatPage({required this.conversation, super.key});

  final DemoConversation conversation;

  @override
  State<DemoChatPage> createState() => _DemoChatPageState();
}

class _DemoChatPageState extends State<DemoChatPage> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  late final List<DemoMessage> _messages = [...widget.conversation.messages];

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final value = _composer.text.trim();
    if (value.isEmpty) {
      return;
    }
    final now = TimeOfDay.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    setState(() {
      _messages.add(
        DemoMessage(text: value, time: '$hour:$minute', isMine: true),
      );
      _composer.clear();
    });
    // Scroll chỉ sau khi khung đã bố trí xong; không có network send.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOut,
      );
    });
  }

  void _openCall(bool isVideo) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoCallPage(
          name: widget.conversation.name,
          initials: widget.conversation.initials,
          avatarColor: widget.conversation.color,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _notAvailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng đính kèm sẽ được phát triển ở phiên bản sau.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.conversation.color.withValues(alpha: .15),
              child: widget.conversation.isGroup
                  ? Icon(
                      Icons.groups,
                      size: 20,
                      color: widget.conversation.color,
                    )
                  : Text(
                      widget.conversation.initials,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.conversation.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Đang hoạt động',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gọi thoại',
            onPressed: () => _openCall(false),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Gọi video',
            onPressed: () => _openCall(true),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer.withValues(alpha: .48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Text(
                'Trò chuyện nhanh với bạn đồng hành và cộng đồng PhuotThu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('demo-message-list'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .78,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        decoration: BoxDecoration(
                          color: message.isMine
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                message.text,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.time,
                                  style: theme.textTheme.labelSmall,
                                ),
                                if (message.isMine) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.done, size: 13),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .5,
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Đính kèm',
                      onPressed: _notAvailable,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('demo-chat-input'),
                        controller: _composer,
                        maxLines: 4,
                        minLines: 1,
                        maxLength: 400,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      key: const Key('demo-chat-send'),
                      tooltip: 'Gửi tin nhắn',
                      onPressed: _composer.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
