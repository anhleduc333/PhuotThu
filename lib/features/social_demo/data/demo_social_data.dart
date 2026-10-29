import 'package:flutter/material.dart';

/// Dữ liệu trình diễn độc lập, không có yêu cầu Supabase/API hay danh tính thật.
/// Có thể thay bằng repository khi xây backend cho đồ án lớn hơn.
class DemoPost {
  const DemoPost({
    required this.id,
    required this.author,
    required this.initials,
    required this.handle,
    required this.location,
    required this.timeLabel,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.tags,
    required this.accent,
    this.photoUrl,
  });

  final String id;
  final String author;
  final String initials;
  final String handle;
  final String location;
  final String timeLabel;
  final String caption;
  final int likes;
  final List<DemoComment> comments;
  final List<String> tags;
  final Color accent;
  final String? photoUrl;
}

class DemoComment {
  const DemoComment({required this.author, required this.text});
  final String author;
  final String text;
}

class DemoMessage {
  const DemoMessage({
    required this.text,
    required this.time,
    required this.isMine,
  });
  final String text;
  final String time;
  final bool isMine;
}

class DemoConversation {
  const DemoConversation({
    required this.id,
    required this.name,
    required this.initials,
    required this.preview,
    required this.time,
    required this.color,
    required this.messages,
    this.isGroup = false,
    this.isOnline = false,
    this.unreadCount = 0,
  });

  final String id;
  final String name;
  final String initials;
  final String preview;
  final String time;
  final Color color;
  final List<DemoMessage> messages;
  final bool isGroup;
  final bool isOnline;
  final int unreadCount;
}

class DemoCallLog {
  const DemoCallLog({
    required this.name,
    required this.initials,
    required this.time,
    required this.color,
    required this.isVideo,
    required this.isMissed,
  });
  final String name;
  final String initials;
  final String time;
  final Color color;
  final bool isVideo;
  final bool isMissed;
}

class DemoSocialData {
  DemoSocialData._();

  static const posts = <DemoPost>[
    DemoPost(
      id: 'ha-giang',
      author: 'Minh Anh',
      initials: 'MA',
      handle: '@minhanh.phuot',
      location: 'Đèo Mã Pí Lèng · Hà Giang',
      timeLabel: '2 giờ trước',
      caption:
          'Có những con đường chỉ cần đi một lần là nhớ mãi. '
          'Mây lững lờ trên đỉnh đèo, dòng Nho Quế xanh ngắt bên dưới. '
          'Ai đang lên kế hoạch cho cung Hà Giang mùa này? 🏍️',
      likes: 128,
      comments: [
        DemoComment(author: 'Quang Huy', text: 'Cung này đẹp quá!'),
        DemoComment(author: 'Hà Linh', text: 'Nhất định phải ghé năm nay.'),
      ],
      tags: ['HàGiang', 'MotoTrip', 'ĐèoMãPíLèng'],
      accent: Color(0xFF25746A),
      photoUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1100&q=82',
    ),
    DemoPost(
      id: 'da-lat',
      author: 'Hà Linh',
      initials: 'HL',
      handle: '@halinh.ontheroad',
      location: 'Đà Lạt · Lâm Đồng',
      timeLabel: 'Hôm qua',
      caption:
          'Một sáng trời se lạnh, cà phê nóng và những khúc cua giữa rừng thông. '
          'Đà Lạt vẫn luôn là nơi tuyệt vời để bắt đầu một hành trình chậm rãi.',
      likes: 94,
      comments: [
        DemoComment(author: 'Minh Anh', text: 'Cho mình xin lịch trình nhé!'),
      ],
      tags: ['ĐàLạt', 'RừngThông', 'ChillRide'],
      accent: Color(0xFF376F87),
      photoUrl: 'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=1100&q=82',
    ),
    DemoPost(
      id: 'sapa',
      author: 'Quang Huy',
      initials: 'QH',
      handle: '@huy.xedich',
      location: 'Sa Pa · Lào Cai',
      timeLabel: '2 ngày trước',
      caption:
          'Săn mây thành công sau một buổi leo đèo! '
          'Mẹo nhỏ: kiểm tra phanh, lốp và dự báo thời tiết trước khi lên núi. '
          'Đi chậm thôi, cảnh đẹp vẫn đợi mình.',
      likes: 215,
      comments: [
        DemoComment(
          author: 'Gia Bảo',
          text: 'Ảnh đẹp và lời nhắc rất hữu ích.',
        ),
        DemoComment(author: 'Hà Linh', text: 'Đi an toàn nhé!'),
      ],
      tags: ['SaPa', 'SănMây', 'AnToàn'],
      accent: Color(0xFF756E9B),
      photoUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1100&q=82',
    ),
    DemoPost(
      id: 'hoi-an',
      author: 'Gia Bảo',
      initials: 'GB',
      handle: '@giabao.roadtrip',
      location: 'Hội An · Quảng Nam',
      timeLabel: '4 ngày trước',
      caption:
          'Một đoạn dừng chân bên phố cổ, ngắm nắng chiều và ăn thật ngon. '
          'Đôi khi điều đáng nhớ nhất lại là những phút nghỉ giữa hành trình.',
      likes: 73,
      comments: [
        DemoComment(author: 'Quang Huy', text: 'Hội An tối lên đèn rất đẹp!'),
      ],
      tags: ['HộiAn', 'DừngChân'],
      accent: Color(0xFFAF7955),
      photoUrl: 'https://images.unsplash.com/photo-1500534623283-312aade485b7?w=1100&q=82',
    ),
  ];

  static const conversations = <DemoConversation>[
    DemoConversation(
      id: 'riders',
      name: 'Đội phượt cuối tuần',
      initials: '🏍',
      preview: 'Minh Anh: Hẹn mọi người 6 giờ sáng nhé!',
      time: '09:42',
      color: Color(0xFF267D75),
      isGroup: true,
      unreadCount: 3,
      messages: [
        DemoMessage(
          text: 'Cuối tuần này chốt cung Tam Đảo nhé!',
          time: '09:30',
          isMine: false,
        ),
        DemoMessage(
          text: 'Mình đã kiểm tra tuyến và cây xăng rồi.',
          time: '09:34',
          isMine: true,
        ),
        DemoMessage(
          text: 'Hẹn mọi người 6 giờ sáng nhé!',
          time: '09:42',
          isMine: false,
        ),
      ],
    ),
    DemoConversation(
      id: 'minh-anh',
      name: 'Minh Anh',
      initials: 'MA',
      preview: 'Mình gửi lịch trình cho bạn nhé.',
      time: '08:15',
      color: Color(0xFFBC7A63),
      isOnline: true,
      unreadCount: 1,
      messages: [
        DemoMessage(
          text: 'Chào bạn, mình đang tìm lịch trình Hà Giang 3N2Đ.',
          time: '08:09',
          isMine: true,
        ),
        DemoMessage(
          text: 'Mình gửi lịch trình cho bạn nhé.',
          time: '08:15',
          isMine: false,
        ),
      ],
    ),
    DemoConversation(
      id: 'quang-huy',
      name: 'Quang Huy',
      initials: 'QH',
      preview: 'Đèo này đẹp, nhưng nhớ kiểm tra thời tiết.',
      time: 'Hôm qua',
      color: Color(0xFF627DAB),
      messages: [
        DemoMessage(
          text: 'Có nên đi Sa Pa cuối tháng không?',
          time: '19:12',
          isMine: true,
        ),
        DemoMessage(
          text: 'Đèo này đẹp, nhưng nhớ kiểm tra thời tiết.',
          time: '19:20',
          isMine: false,
        ),
      ],
    ),
    DemoConversation(
      id: 'da-lat-group',
      name: 'Hội mê Đà Lạt',
      initials: 'DL',
      preview: 'Hà Linh: Tụi mình gặp nhau ở quảng trường nha.',
      time: 'Thứ 3',
      color: Color(0xFF6C9776),
      isGroup: true,
      messages: [
        DemoMessage(
          text: 'Có ai muốn ghép đoàn cuối tuần này?',
          time: '11:08',
          isMine: false,
        ),
        DemoMessage(
          text: 'Tụi mình gặp nhau ở quảng trường nha.',
          time: '11:20',
          isMine: false,
        ),
      ],
    ),
    DemoConversation(
      id: 'ha-linh',
      name: 'Hà Linh',
      initials: 'HL',
      preview: 'Cảm ơn bạn đã chia sẻ địa điểm!',
      time: 'Thứ 2',
      color: Color(0xFFA284B8),
      isOnline: true,
      messages: [
        DemoMessage(
          text: 'Chỗ này có bãi gửi xe không?',
          time: '16:00',
          isMine: false,
        ),
        DemoMessage(
          text: 'Có nha, phía cuối đường.',
          time: '16:04',
          isMine: true,
        ),
        DemoMessage(
          text: 'Cảm ơn bạn đã chia sẻ địa điểm!',
          time: '16:06',
          isMine: false,
        ),
      ],
    ),
  ];

  static const calls = <DemoCallLog>[
    DemoCallLog(
      name: 'Minh Anh',
      initials: 'MA',
      time: 'Hôm nay · 10:30',
      color: Color(0xFFBC7A63),
      isVideo: true,
      isMissed: false,
    ),
    DemoCallLog(
      name: 'Quang Huy',
      initials: 'QH',
      time: 'Hôm qua · 20:16',
      color: Color(0xFF627DAB),
      isVideo: false,
      isMissed: true,
    ),
    DemoCallLog(
      name: 'Hà Linh',
      initials: 'HL',
      time: 'Thứ 3 · 18:05',
      color: Color(0xFFA284B8),
      isVideo: false,
      isMissed: false,
    ),
  ];
}
