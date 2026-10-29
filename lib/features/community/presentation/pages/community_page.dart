import 'package:flutter/material.dart';

import '../../../social_demo/data/demo_social_data.dart';
import 'demo_call_page.dart';
import 'demo_chat_page.dart';

/// Bảng tin nhắn & lịch sử cuộc gọi giả lập, không kết nối người dùng thật.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _searchController = TextEditingController();
  int _tab = 0;
  bool _onlyUnread = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(DemoConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoChatPage(conversation: conversation),
      ),
    );
  }

  void _openCall({
    required String name,
    required String initials,
    required Color color,
    required bool isVideo,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoCallPage(
          name: name,
          initials: initials,
          avatarColor: color,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final chats = DemoSocialData.conversations.where((conversation) {
      return conversation.name.toLowerCase().contains(query) &&
          (!_onlyUnread || conversation.unreadCount > 0);
    }).toList();
    final calls = DemoSocialData.calls
        .where((call) => call.name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cộng đồng',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Kết nối trên mọi cung đường',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thông tin cộng đồng',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Cộng đồng PhuotThu'),
                content: const Text(
                  'Kết nối bạn đồng hành, trao đổi hành trình và giữ liên lạc trên mọi cung đường. '
                  'Giao diện được thiết kế để mang lại trải nghiệm trò chuyện và liên lạc liền mạch trong ứng dụng. '
                  'Bạn có thể khám phá các mục trò chuyện, cuộc gọi và danh bạ cộng đồng ngay trên ứng dụng.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Đã hiểu'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: .5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nhắn tin và liên lạc cùng cộng đồng PhuotThu',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    icon: Icon(Icons.chat_bubble_outline),
                    label: Text('Tin nhắn'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.call_outlined),
                    label: Text('Cuộc gọi'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() {
                  _tab = value.first;
                  _searchController.clear();
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _tab == 0
                      ? 'Tìm cuộc trò chuyện...'
                      : 'Tìm lịch sử cuộc gọi...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_tab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cuộc trò chuyện',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Chưa đọc'),
                      selected: _onlyUnread,
                      onSelected: (value) =>
                          setState(() => _onlyUnread = value),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Gần đây',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _tab == 0
                  ? (chats.isEmpty
                        ? const Center(
                            child: Text('Không có cuộc trò chuyện phù hợp.'),
                          )
                        : ListView.separated(
                            key: const Key('demo-chat-list'),
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                            itemCount: chats.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 80,
                              endIndent: 12,
                            ),
                            itemBuilder: (_, index) {
                              final chat = chats[index];
                              return ListTile(
                                key: Key('chat-${chat.id}'),
                                onTap: () => _openChat(chat),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                leading: _DemoChatAvatar(chat: chat),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chat.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      chat.time,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    chat.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                trailing: chat.unreadCount > 0
                                    ? CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        child: Text(
                                          '${chat.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ))
                  : (calls.isEmpty
                        ? const Center(child: Text('Chưa có cuộc gọi phù hợp.'))
                        : ListView.separated(
                            key: const Key('demo-call-list'),
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                            itemCount: calls.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 80,
                              endIndent: 12,
                            ),
                            itemBuilder: (_, index) {
                              final call = calls[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: call.color.withValues(
                                    alpha: .15,
                                  ),
                                  child: Text(
                                    call.initials,
                                    style: TextStyle(
                                      color: call.color,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  call.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      call.isMissed
                                          ? Icons.call_missed_outgoing
                                          : Icons.call_received,
                                      size: 16,
                                      color: call.isMissed
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '${call.time} · ${call.isVideo ? 'Video' : 'Thoại'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: 'Gọi lại',
                                  icon: Icon(
                                    call.isVideo
                                        ? Icons.videocam_outlined
                                        : Icons.call_outlined,
                                  ),
                                  onPressed: () => _openCall(
                                    name: call.name,
                                    initials: call.initials,
                                    color: call.color,
                                    isVideo: call.isVideo,
                                  ),
                                ),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liên hệ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text('Chọn người dùng để bắt đầu cuộc trò chuyện.'),
                    for (final chat
                        in DemoSocialData.conversations
                            .where((item) => !item.isGroup)
                            .take(3))
                      ListTile(
                        leading: CircleAvatar(child: Text(chat.initials)),
                        title: Text(chat.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openChat(chat);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Tin nhắn mới'),
      ),
    );
  }
}

class _DemoChatAvatar extends StatelessWidget {
  const _DemoChatAvatar({required this.chat});
  final DemoConversation chat;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: chat.color.withValues(alpha: .17),
          child: chat.isGroup
              ? Icon(Icons.groups_rounded, color: chat.color)
              : Text(
                  chat.initials,
                  style: TextStyle(
                    color: chat.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        if (chat.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF1DA76C),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
