# PhuotThu — bản bàn giao mở rộng demo 29/10/2026

**Nguồn đối chiếu:** `anhleduc333/PhuotThu`, nhánh `develop`, commit `03a9c32` (26/10/2026).

## Những phần được tạo trong gói này

1. **DEV-09.7D — GPS Auto Arrival:** Migration SQL `006_checkpoint_gps_arrival.sql` tạo trigger sau khi vị trí nhóm được lưu. Chỉ tự ghi nhận nếu là vị trí của chính người đăng nhập, thành viên active, đã đồng ý chia sẻ vị trí, GPS mới trong 90 giây, sai số <=60m và chính tọa độ ± sai số nằm trong vòng checkpoint. Ghi idempotent, không điểm danh lần hai. Nếu không thỏa thì không ghi nhận.
2. **DEV-09.7E/F — Group Checkpoint Progress:** Trang `trip_checkpoint_progress_page.dart` hiển thị N/M thành viên đã tới, từng người đã/chưa tới, thông tin GPS gần đây, khoảng cách đường chim bay và ETA rất thô; cho thành viên tự điểm danh thủ công. Tự refresh 10 giây; **không phải push Realtime trực tiếp của arrivals**, chỉ Live Location dùng Realtime hiện có.
3. **Bổ sung demo:** `trip_track_page.dart` ghi lộ trình GPS trong lúc màn hình mở và phát lại các điểm trên bản đồ; lưu trên thiết bị bằng SharedPreferencesAsync, không đồng bộ đám mây và không chạy nền.
4. **Bổ sung demo:** `trip_emergency_page.dart` tạo thông tin vị trí để sao chép và **tự gửi** cho người hỗ trợ. Không gửi SOS tự động, không liên hệ cứu hộ.
5. **Kiểm thử bổ sung:** test pure Dart `trip_track_point_test.dart` (chưa được thực thi trong môi trường tạo gói).

## Cách cài đặt, theo đúng thứ tự

**A. Sao lưu** thư mục PhuotThu (hoặc commit/backup hiện trạng). Kiểm tra terminal đang ở `D:\Projects\PhuotThu` và nhánh `develop`. Không cần ghi đè các file đã có.

**B. Sao chép** bốn thư mục `lib`, `test`, `tools` và `supabase` từ ZIP này vào thư mục gốc dự án. Các file trong gói này đều mang tên mới; `tools/apply_delivery.py` và `tools/verify_delivery.ps1` là các file bổ sung mới. **Không** chép SQL làm lại bảng; chỉ dùng migration `006`.

**C. Trong VS Code Terminal PowerShell:**

```powershell
cd D:\Projects\PhuotThu
python tools\apply_delivery.py
dart format lib test
flutter analyze
flutter test
# Hoặc chạy cả format check + analyze + tests + Android debug build và lưu log:
powershell -ExecutionPolicy Bypass -File tools\verify_delivery.ps1
```

Script chỉ thêm hai nút AppBar vào `trip_detail_page.dart` và một nút tiến độ vào `trip_checkpoint_management_page.dart`, có backup tại `build/delivery_2026_10_29_backup/`. Nó dừng khi mẫu code không khớp, và có thể chạy lại an toàn.

**D. Nếu toàn bộ analyzer/tests PASS**, mở Supabase SQL Editor (quyền quản trị), thực thi **nguyên file `supabase/sql/006_checkpoint_gps_arrival.sql`** đúng 1 lần. Sau đó thực thi file **`007_verify_checkpoint_gps.sql`**. Mong đợi: 4 cột boolean đầu đều `true`; bảng arrivals có thể đang rỗng. Script SQL có transaction `BEGIN/COMMIT` và có thể chạy lại mà không tạo trigger trùng. Không chạy lại `001_core_schema.sql`, `DEV-09.7A` hoặc xóa bất kỳ bảng nào.

**E. Kiểm tra trên Android Emulator với A/B:**

1. A (Owner) bật Group Travel; B (Member) tham gia. Chọn 1 checkpoint có `auto_arrival_enabled=true`, bán kính 100–300 m. A/B có thể xem trang **Tiến độ đoàn** từ nút trên màn hình Checkpoint.
2. A/B bật **Chia sẻ vị trí của tôi** trong màn hình chi tiết chuyến đi, đồng thời cấp quyền GPS thiết bị. Emulator đổi vị trí GPS thành vị trí gần checkpoint, sai số cho phép (chẳng hạn 10–30m), bảo đảm đã có dữ liệu location mới. Sau một nhịp cập nhật live location và khoảng 10 giây refresh, hệ thống mới ghi nhận đã đến. Kiểm tra không ghi trùng. Nếu mô phỏng GPS không nằm trong checkpoint thì không được tự ghi nhận.
3. Tắt location sharing → cập nhật vị trí không được tự ghi nhận. Kiểm tra dữ liệu chưa đến checkpoint. Nếu GPS không đủ tốt, bấm **Tôi đã đến** để dùng xác nhận thủ công. Dùng tài khoản B để chắc chắn không sửa/xóa điểm hẹn của A.
4. Vào chi tiết chuyến → nút **Ghi / xem lại hành trình**: bật GPS, nhấn Bắt đầu ghi, mô phỏng di chuyển vài vị trí trên Emulator, Dừng ghi, Phát lại. Dữ liệu track tồn tại sau khi thoát/mở lại.
5. Nút **Thông tin hỗ trợ khẩn cấp**: cấp quyền GPS, sao chép vị trí và kiểm tra dán nội dung. Đây **không** gửi thông báo tới ai.

**F. Sau khi đã chạy tốt:**

```powershell
git status
git diff --check
git add lib test supabase/sql/006_checkpoint_gps_arrival.sql supabase/sql/007_verify_checkpoint_gps.sql tools/apply_delivery.py
git diff --cached --stat
git commit -m "feat: add checkpoint GPS arrivals and demo readiness tools"
git push origin develop
git status
```

Không push nếu `flutter analyze` hoặc `flutter test` lỗi. Nếu xuất hiện lỗi, gửi log và tên file; sửa lỗi trước khi commit.

## Giới hạn và các việc chưa hoàn thành

- Không thể chạy `flutter analyze`, `flutter test`, Android/iOS Emulator hay thực thi SQL Supabase từ môi trường tạo gói. Các bước trên là yêu cầu kiểm chứng trên máy anh, **chưa có kết quả PASS mới**.
- GPS vị trí gửi từ thiết bị có thể bị giả mạo; trigger xác minh tính mới, đồng ý chia sẻ, bán kính và accuracy, **không xác thực chống GPS spoofing tuyệt đối**.
- `trip_checkpoint_arrivals` được cập nhật qua polling 10 giây, không phải WebSocket toàn phần.
- Bản demo thiếu: offline map tile và đồng bộ offline thực, notification/FCM, SOS gửi cảnh báo thực, chat/mạng xã hội, recommendation/optimization nâng cao, analytics/crash monitoring, kiểm thử iOS/release và đánh giá thực nghiệm cho đồ án tốt nghiệp. Do đó **không được gọi sản phẩm đã đạt 100% phạm vi ban đầu**.
- Chỉ nên trình bày bản hiện tại là **bản Android demo mở rộng** nếu các bước kiểm thử hoàn tất.
