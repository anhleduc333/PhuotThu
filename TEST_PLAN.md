# Bảng nghiệm thu nhanh

| ID | Kiểm tra | Kỳ vọng |
|---|---|---|
| Q01 | dart format + flutter analyze | No issues found |
| Q02 | flutter test | All tests passed; test cũ không giảm |
| Q03 | Mở màn Checkpoint rồi Tiến độ đoàn | Không crash; hiển thị danh sách thành viên |
| Q04 | B là Member không được sửa/xóa checkpoint | Không có thao tác / RLS chặn request |
| Q05 | A/B bật location sharing, GPS cập nhật gần checkpoint | Tự điểm danh khi accuracy + radius hợp lệ |
| Q06 | GPS ngoài bán kính | Không điểm danh |
| Q07 | GPS cũ hơn 90 giây | Không điểm danh |
| Q08 | GPS accuracy > 60 m | Không điểm danh |
| Q09 | B tắt location sharing | Không điểm danh tự động |
| Q10 | Gửi GPS nhiều lần khi đã tới | Chỉ một arrival cho mỗi (checkpoint,user) |
| Q11 | B tự xác nhận thủ công | Ghi nhận `manual` một lần |
| Q12 | A sửa/xóa checkpoint | Danh sách cập nhật, dữ liệu attendance xóa cascade |
| Q13 | Ghi / phát lại hành trình trên Emulator | Đường vẽ, slider, có thể tải lại dữ liệu local |
| Q14 | Thông tin khẩn cấp | Chỉ copy, không tuyên bố đã gửi SOS |
| Q15 | 2 tài khoản ở hai Emulator | Cả hai xem được tiến độ sau refresh |
| Q16 | Build APK Android | `flutter build apk --debug` thành công |
| Q17 | Đánh giá iOS | Chưa được xác nhận nếu không có macOS/Xcode |

## Log nên lưu gửi khi gặp lỗi

```
flutter analyze
flutter test
flutter build apk --debug
git status
```

Sau khi Supabase SQL đã chạy, dùng file `007_verify_checkpoint_gps.sql` và chụp ảnh kết quả bốn boolean `true`. Không gửi key/token hay dữ liệu nhạy cảm vào chat.
