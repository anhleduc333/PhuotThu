import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../social_demo/data/demo_social_data.dart';

/// Social feed demo: hoàn toàn cục bộ, không ghi dữ liệu Supabase.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _likedPostIds = <String>{};
  final _savedPostIds = <String>{};
  final _localComments = <String, List<DemoComment>>{};
  final _createdPosts = <DemoPost>[];
  String _filter = 'Dành cho bạn';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DemoPost> get _visiblePosts {
    final all = [..._createdPosts, ...DemoSocialData.posts];
    final query = _searchController.text.trim().toLowerCase();
    var result = all.where((post) {
      return query.isEmpty ||
          '${post.author} ${post.location} ${post.caption} ${post.tags.join(' ')}'
              .toLowerCase()
              .contains(query);
    }).toList();
    if (_filter == 'Nổi bật') {
      result.sort((a, b) => b.likes.compareTo(a.likes));
    } else if (_filter == 'Đã lưu') {
      result = result.where((post) => _savedPostIds.contains(post.id)).toList();
    }
    return result;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleLike(String id) {
    setState(() {
      if (!_likedPostIds.add(id)) {
        _likedPostIds.remove(id);
      }
    });
  }

  void _toggleSave(String id) {
    final wasSaved = _savedPostIds.contains(id);
    setState(() {
      if (wasSaved) {
        _savedPostIds.remove(id);
      } else {
        _savedPostIds.add(id);
      }
    });
    _toast(wasSaved ? 'Đã bỏ lưu bài viết.' : 'Đã lưu bài viết.');
  }

  void _openComments(DemoPost post) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) {
          final comments = [...post.comments, ...?_localComments[post.id]];
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.53,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bình luận · ${comments.length}',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tham gia bình luận cùng cộng đồng PhuotThu.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE3F1EE),
                            child: Text(comment.author.substring(0, 1)),
                          ),
                          title: Text(
                            comment.author,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(comment.text),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          maxLength: 180,
                          maxLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Viết bình luận...',
                            counterText: '',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) =>
                              _addComment(post, controller, refreshSheet),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Gửi bình luận',
                        onPressed: () =>
                            _addComment(post, controller, refreshSheet),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  void _addComment(
    DemoPost post,
    TextEditingController controller,
    StateSetter refreshSheet,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _localComments
          .putIfAbsent(post.id, () => [])
          .add(DemoComment(author: 'Bạn', text: text));
    });
    refreshSheet(() {});
    controller.clear();
  }

  void _openCompose() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _DemoComposeSheet(
        onPublish: (content) {
          setState(() {
            _createdPosts.insert(
              0,
              DemoPost(
                id: 'local-${_createdPosts.length + 1}',
                author: 'Bạn',
                initials: 'B',
                handle: '@ban',
                location: 'Nhật ký hành trình',
                timeLabel: 'Vừa xong',
                caption: content,
                likes: 0,
                comments: const [],
                tags: const ['PhuotThu', 'HànhTrình'],
                accent: const Color(0xFF387C83),
              ),
            );
            _filter = 'Dành cho bạn';
            _searchController.clear();
          });
          Navigator.of(sheetContext).pop();
          _toast('Đăng bài thành công.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _visiblePosts;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PhuotThu',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const Text(
              'Mỗi cung đường, một câu chuyện',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tạo bài viết',
            onPressed: _openCompose,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined, size: 19),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bảng tin cộng đồng · cập nhật hành trình mỗi ngày',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm bài viết, địa điểm, người đi phượt...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xóa tìm kiếm',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Khám phá hành trình',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.explore_outlined, size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 103,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: DemoSocialData.posts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final post = DemoSocialData.posts[index];
                    return InkWell(
                      key: Key('story-${post.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        _searchController.text = post.location
                            .split(' · ')
                            .first;
                        setState(() => _filter = 'Dành cho bạn');
                      },
                      child: Container(
                        width: 126,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: post.accent.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terrain_rounded,
                              size: 27,
                              color: post.accent,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.location.split(' · ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              post.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in [
                            'Dành cho bạn',
                            'Nổi bật',
                            'Đã lưu',
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _filter == label,
                              onSelected: (_) =>
                                  setState(() => _filter = label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Chưa có bài viết phù hợp.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                sliver: SliverList.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _DemoPostCard(
                      key: Key('post-${post.id}'),
                      post: post,
                      liked: _likedPostIds.contains(post.id),
                      saved: _savedPostIds.contains(post.id),
                      commentsCount:
                          post.comments.length +
                          (_localComments[post.id]?.length ?? 0),
                      onLike: () => _toggleLike(post.id),
                      onSave: () => _toggleSave(post.id),
                      onComments: () => _openComments(post),
                      onShare: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${post.author} · ${post.location}\n${post.caption}\n#PhuotThu',
                          ),
                        );
                        if (context.mounted) {
                          _toast('Đã sao chép nội dung bài viết.');
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.add),
        label: const Text('Đăng bài'),
      ),
    );
  }
}

class _DemoPostCard extends StatelessWidget {
  const _DemoPostCard({
    required this.post,
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.onLike,
    required this.onSave,
    required this.onComments,
    required this.onShare,
    super.key,
  });

  final DemoPost post;
  final bool liked;
  final bool saved;
  final int commentsCount;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: post.accent.withValues(alpha: 0.17),
                  child: Text(
                    post.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: post.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${post.timeLabel} · ${post.handle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1.78,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _DemoLandscapePainter(post.accent)),
                if (post.photoUrl != null)
                  Image.network(
                    post.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x80000000)],
                    ),
                  ),
                ),
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Text(
                    '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 3)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  right: 10,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.caption, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    for (final tag in post.tags)
                      Text(
                        '#$tag',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 12),
                Row(
                  children: [
                    IconButton(
                      key: Key('like-${post.id}'),
                      tooltip: liked ? 'Bỏ thích' : 'Thích',
                      onPressed: onLike,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.redAccent : null,
                      ),
                    ),
                    Text('${post.likes + (liked ? 1 : 0)}'),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Bình luận',
                      onPressed: onComments,
                      icon: const Icon(Icons.mode_comment_outlined),
                    ),
                    Text('$commentsCount'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Sao chép nội dung bài đăng',
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_outlined),
                    ),
                    IconButton(
                      tooltip: saved ? 'Bỏ lưu bài' : 'Lưu bài',
                      onPressed: onSave,
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Phong cảnh vector dự phòng khi chưa có mạng tải hình minh họa.
class _DemoLandscapePainter extends CustomPainter {
  const _DemoLandscapePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.45), const Color(0xFFD5E4DC)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.28),
      size.height * 0.11,
      Paint()..color = const Color(0xFFF9E8BF),
    );
    void mountain(double peak, double base, Color shade) {
      final p = Path()
        ..moveTo(-size.width * .12, size.height)
        ..lineTo(size.width * peak, size.height * base)
        ..lineTo(size.width * 1.12, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = shade);
    }

    mountain(.26, .32, color.withValues(alpha: .49));
    mountain(.76, .46, color.withValues(alpha: .77));
    mountain(.49, .61, color);
    final road = Path()
      ..moveTo(size.width * .48, size.height)
      ..quadraticBezierTo(
        size.width * .7,
        size.height * .82,
        size.width * .54,
        size.height * .71,
      );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFECD9B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
  }

  @override
  bool shouldRepaint(covariant _DemoLandscapePainter old) => color != old.color;
}

class _DemoComposeSheet extends StatefulWidget {
  const _DemoComposeSheet({required this.onPublish});
  final ValueChanged<String> onPublish;

  @override
  State<_DemoComposeSheet> createState() => _DemoComposeSheetState();
}

class _DemoComposeSheetState extends State<_DemoComposeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chia sẻ hành trình',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Chia sẻ cảm hứng và trải nghiệm trên cung đường của bạn.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('demo-compose-field'),
            controller: _controller,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Kể về một cung đường đáng nhớ...',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => widget.onPublish(_controller.text.trim()),
              icon: const Icon(Icons.post_add_outlined),
              label: const Text('Đăng bài'),
            ),
          ),
        ],
      ),
    );
  }
}
