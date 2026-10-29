import 'package:flutter/material.dart';

/// Màn hình cuộc gọi mô phỏng. Không thiết lập cuộc gọi hay kết nối mạng.
class DemoCallPage extends StatefulWidget {
  const DemoCallPage({
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.isVideo,
    super.key,
  });

  final String name;
  final String initials;
  final Color avatarColor;
  final bool isVideo;

  @override
  State<DemoCallPage> createState() => _DemoCallPageState();
}

class _DemoCallPageState extends State<DemoCallPage> {
  bool _muted = false;
  bool _speaker = false;
  bool _cameraOff = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102D30),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Có thể cuộn dọc khi thiết bị thấp hoặc phóng to chữ.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Quay lại',
                              color: Colors.white,
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Spacer(),
                            // Chip phải có giới hạn chiều rộng. Trước đây
                            // Chip kích thước cố định + nút Quay lại khiến
                            // Row tràn 13 px trên viewport 320 px.
                            const Flexible(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Chip(
                                    label: Text('ĐANG KẾT NỐI'),
                                    avatar: Icon(
                                      Icons.science_outlined,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        CircleAvatar(
                          radius: 66,
                          backgroundColor: widget.avatarColor.withValues(
                            alpha: .84,
                          ),
                          child: Text(
                            widget.initials,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFBDD7D4),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Kết nối ổn định',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF3D69C),
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        // Wrap tự chuyển hàng khi 3 nút không đủ chỗ.
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _CallAction(
                              label: _muted ? 'Bật mic' : 'Tắt mic',
                              icon: _muted ? Icons.mic_off : Icons.mic,
                              active: _muted,
                              onPressed: () {
                                setState(() => _muted = !_muted);
                              },
                            ),
                            _CallAction(
                              label: _speaker ? 'Tắt loa' : 'Loa ngoài',
                              icon: _speaker
                                  ? Icons.volume_up
                                  : Icons.volume_down,
                              active: _speaker,
                              onPressed: () {
                                setState(() => _speaker = !_speaker);
                              },
                            ),
                            if (widget.isVideo)
                              _CallAction(
                                label: _cameraOff ? 'Bật camera' : 'Tắt camera',
                                icon: _cameraOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                active: _cameraOff,
                                onPressed: () {
                                  setState(() => _cameraOff = !_cameraOff);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        FloatingActionButton.large(
                          key: const Key('demo-call-end'),
                          tooltip: 'Kết thúc cuộc gọi',
                          backgroundColor: const Color(0xFFE45454),
                          foregroundColor: Colors.white,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.call_end_rounded, size: 32),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Kết thúc',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.active,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: active
                ? const Color(0xFF87CBBF)
                : const Color(0xFF315155),
            foregroundColor: active ? const Color(0xFF102D30) : Colors.white,
          ),
          iconSize: 25,
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
