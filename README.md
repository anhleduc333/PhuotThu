# PhuotThu — Ứng dụng hỗ trợ lập kế hoạch và đồng hành chuyến đi

> **PhuotThu** là ứng dụng di động hỗ trợ người đi phượt **lập kế hoạch trước chuyến đi, đưa ra quyết định trên đường và đồng hành an toàn khi di chuyển theo nhóm**. Ứng dụng cung cấp thông tin và gợi ý; **người dùng luôn là người quyết định** tuyến đi, điểm dừng và phương án di chuyển.

**Nền tảng:** Flutter / Dart · Android (đã thử nghiệm) · iOS (định hướng, chưa xác minh trên thiết bị)  
**Backend:** Supabase Auth · PostgreSQL/PostGIS · RLS · Supabase Realtime  
**Bản đồ & dịch vụ:** OpenStreetMap · flutter_map · Nominatim · OSRM · Geoapify · Open-Meteo  
**Trạng thái:** Bản demo Android tích hợp nhiều chức năng; **chưa phải bản phát hành thương mại hoặc toàn bộ phạm vi đồ án tốt nghiệp đã hoàn thành**.

---

## Mục lục

1. [Giới thiệu và định hướng](#1-giới-thiệu-và-định-hướng)
2. [Phạm vi và chức năng](#2-phạm-vi-và-chức-năng)
3. [Kiến trúc hệ thống](#3-kiến-trúc-hệ-thống)
4. [Công nghệ sử dụng](#4-công-nghệ-sử-dụng)
5. [Cấu trúc thư mục](#5-cấu-trúc-thư-mục)
6. [Yêu cầu môi trường](#6-yêu-cầu-môi-trường)
7. [Cài đặt và chạy ứng dụng](#7-cài-đặt-và-chạy-ứng-dụng)
8. [Cơ sở dữ liệu và Supabase](#8-cơ-sở-dữ-liệu-và-supabase)
9. [Các luồng nghiệp vụ chính](#9-các-luồng-nghiệp-vụ-chính)
10. [Kiểm thử và kết quả đã xác nhận](#10-kiểm-thử-và-kết-quả-đã-xác-nhận)
11. [Bảo mật, quyền riêng tư và an toàn](#11-bảo-mật-quyền-riêng-tư-và-an-toàn)
12. [Giới hạn hiện tại](#12-giới-hạn-hiện-tại)
13. [Lộ trình phát triển](#13-lộ-trình-phát-triển)
14. [Quy trình phát triển và đóng góp](#14-quy-trình-phát-triển-và-đóng-góp)
15. [Tài liệu tham khảo và ghi nhận](#15-tài-liệu-tham-khảo-và-ghi-nhận)

## 1. Giới thiệu và định hướng

PhuotThu được phát triển trong bối cảnh đồ án CNTT, với định hướng có thể mở rộng từ **đồ án cơ sở → đồ án liên ngành → đồ án tốt nghiệp** mà không phải xây dựng lại ứng dụng từ đầu.

### Bài toán

Trong một chuyến đi dài, đặc biệt khi di chuyển bằng xe máy hoặc theo đoàn, người dùng phải phối hợp nhiều quyết định: chọn đường, tìm nơi đổ xăng/nghỉ chân, tính chi phí, chuẩn bị cho nơi có nguy cơ thiếu kết nối và nắm được tình trạng thành viên trong nhóm. PhuotThu gom các nhu cầu này vào một ứng dụng di động có dữ liệu tuyến đường và vị trí làm trung tâm.

### Nguyên tắc thiết kế

- **Assisted Trip Planner:** phân tích, cung cấp lựa chọn và gợi ý thay vì tự động áp đặt các điểm dừng.
- **Route-aware:** ưu tiên dữ liệu *dọc tuyến đang đi*, không chỉ tìm địa điểm gần điểm xuất phát.
- **Safety-aware:** ưu tiên cảnh báo, trạng thái GPS, chuẩn bị offline và khả năng phối hợp đoàn.
- **Privacy by design:** chia sẻ vị trí là hành động có chủ đích, chịu kiểm soát quyền truy cập; không được coi là dịch vụ theo dõi 24/7.
- **Incremental architecture:** tách giao diện, nghiệp vụ và truy cập dữ liệu để dễ nâng cấp dịch vụ, thuật toán và hạ tầng.

Ứng dụng hiện tập trung vào **Android và iOS, không xây dựng phiên bản web**. Android là nền tảng đã được chạy thử và build trong quá trình phát triển.

## 2. Phạm vi và chức năng

Bảng sau phản ánh **những chức năng có mã nguồn trong nhánh `develop` tại thời điểm cập nhật README**, phân biệt rõ trạng thái hiện hành và các giới hạn.

| Nhóm | Chức năng | Trạng thái / lưu ý |
| --- | --- | --- |
| Tài khoản | Đăng ký, đăng nhập, đăng xuất; hồ sơ cá nhân | Đã triển khai qua Supabase Auth và Profiles |
| Phương tiện | Tạo/sửa/xóa phương tiện, khai báo mức tiêu hao và dung tích bình | Đã triển khai |
| Chuyến đi | CRUD chuyến đi, thời gian, điểm đi/đến, trạng thái chuyến | Đã triển khai |
| Bản đồ và tuyến | Bản đồ OSM, tìm địa điểm Nominatim, tính tuyến OSRM, hiển thị khoảng cách/thời gian | Đã triển khai; phụ thuộc dữ liệu/dịch vụ bên ngoài |
| Chi phí | Ước tính nhiên liệu và chi phí tối thiểu, ngân sách nhiều hạng mục | Đã triển khai; số tiền mang tính ước tính |
| Along Route POI | Tìm cây xăng, ăn uống, nghỉ chân/lưu trú gần tuyến | Đã triển khai qua dịch vụ tìm kiếm địa điểm |
| Smart Fuel / Rest | Tính phạm vi nhiên liệu, tìm điểm có thể dừng và xếp gợi ý theo quy tắc | Đã triển khai; không phải hệ thống AI tự quyết định |
| Connectivity Risk | Ước lượng các đoạn đường có nguy cơ kết nối kém | Đã triển khai bằng dữ liệu *proxy*, không phải dữ liệu phủ sóng nhà mạng |
| Offline Trip | Lưu gói dữ liệu chuyến đi cục bộ, chấm điểm sẵn sàng offline | Có bản nền tảng; **chưa** có bản đồ tile offline đầy đủ |
| Trip Readiness | Checklist chuẩn bị xe, cá nhân, điều kiện tuyến/thời tiết và khẩn cấp | Đã triển khai |
| Group Travel | Bật chuyến đi nhóm; mời/chấp nhận/từ chối; owner/leader/member; rời/loại thành viên | Đã triển khai và thử luồng A/B |
| Live Location | Tự bật/tắt chia sẻ vị trí, hiển thị thành viên trên bản đồ nhóm | Đã triển khai Supabase Realtime; không cam kết chạy nền 24/7 |
| Convoy Safety | Cảnh báo tách đoàn, GPS cũ, mất tín hiệu vị trí | Đã triển khai theo chính sách ngưỡng |
| Checkpoint | Owner/Leader chọn điểm hẹn trên bản đồ, thêm/sửa/xóa; Member xem | Đã triển khai và kiểm thử thực tế |
| GPS Auto Arrival | Tự ghi nhận đến Checkpoint khi GPS hợp lệ, thành viên active và đã bật chia sẻ | Đã quan sát một bản ghi `gps` thực trên Supabase; xem `006` |
| Group Progress | Xem số thành viên đã/chưa đến, xác nhận thủ công, trạng thái và khoảng cách | Đã triển khai; tiến độ arrivals **làm mới mỗi 10 giây** |
| GPS Track & Replay | Ghi điểm GPS và phát lại trên bản đồ | **Bản demo cục bộ, chỉ ghi khi màn hình đang mở** |
| Thông tin khẩn cấp | Lấy GPS, tạo nội dung chứa tọa độ và sao chép để tự gửi | **Bản demo, không tự gửi SOS hoặc gọi cứu hộ** |
| Community / Social | Khung điều hướng cộng đồng | **Chưa** triển khai mạng xã hội đầy đủ |
| Tối ưu hóa, AI nâng cao, thông báo đẩy | Lộ trình tiếp theo | **Chưa** triển khai hoàn chỉnh |

### Các nhóm chức năng nổi bật

**Trip Planner → Route → Fuel/Budget:** thông số phương tiện và tuyến đường được sử dụng để tính lượng nhiên liệu, chi phí dự kiến và so sánh với ngân sách.

**Along Route → Smart Stop:** hệ thống truy vấn địa điểm theo hành lang tuyến đường, tìm cây xăng hoặc điểm nghỉ khả dụng và xếp gợi ý theo các chính sách hành trình. Người dùng chọn điểm dừng cuối cùng.

**Connectivity → Offline/Trip Readiness:** ước lượng rủi ro dựa trên các bằng chứng địa lý gián tiếp, sau đó hỗ trợ đánh giá dữ liệu cần chuẩn bị trước chuyến đi.

**Group → Live Map → Convoy → Checkpoint:** thành viên tham gia chuyến đi, chủ động chia sẻ GPS, quan sát vị trí nhóm, nhận cảnh báo và theo dõi việc đến các điểm hẹn.

## 3. Kiến trúc hệ thống

Dự án tổ chức theo **feature-first**, trong mỗi nhóm chức năng ưu tiên phân tách nghiệp vụ và hạ tầng:

```text
                    FLUTTER MOBILE UI (Android / iOS)
                                 │
                   Presentation / Widgets
                                 │
                        Riverpod Providers
                                 │
                    Domain Models & Policies
                                 │
                    Repositories / Services
                 ┌───────────────┼─────────────────┐
                 │               │                 │
         Supabase Auth/DB   Maps/Geocoding     Local Storage
         Postgres + RLS     OSRM / Geoapify    SharedPreferences
         Realtime / RPC     Open-Meteo         GPS/Replay cache
```

- **Presentation:** màn hình, form, bản đồ, thông báo trạng thái và tương tác.
- **Domain:** dữ liệu nghiệp vụ, kiểm tra hợp lệ, bộ tính toán nhiên liệu/ngân sách, chấm điểm, quy tắc cảnh báo.
- **Data:** repository và service kết nối Supabase, API bản đồ/địa điểm, GPS và bộ nhớ cục bộ.
- **State management:** Riverpod kết nối các tầng, kiểm soát trạng thái tải/lỗi và làm mới dữ liệu.
- **Navigation:** `go_router` cho luồng chính; một số màn hình nhóm mở bằng `Navigator`.

### Luồng dữ liệu ví dụ

```text
Người dùng chọn điểm đi và điểm đến
    → Nominatim trả về địa điểm / tọa độ
    → OSRM trả về tuyến, chiều dài, thời gian
    → Domain tính nhiên liệu và chi phí
    → Along Route tìm dịch vụ dọc tuyến
    → Flutter hiển thị kết quả cho người dùng lựa chọn
```

**Live Location:** nguồn vị trí của điện thoại (`geolocator`) → chính sách chọn mẫu gửi vị trí → Supabase RPC/`trip_live_locations` → Supabase stream → marker nhóm và thuật toán Convoy Safety.

**Checkpoint Auto Arrival:** vị trí hợp lệ được ghi → database trigger kiểm tra tư cách thành viên, đồng ý chia sẻ, tuổi/sai số GPS và khoảng cách → insert attendance chống trùng → trang tiến độ đọc kết quả.

## 4. Công nghệ sử dụng

| Thành phần | Công nghệ / package | Vai trò |
| --- | --- | --- |
| Mobile | Flutter, Dart | UI đa nền tảng |
| State | `flutter_riverpod` | Providers và trạng thái |
| Navigation | `go_router` | Điều hướng |
| Backend | `supabase_flutter` | Auth, database, realtime, RPC |
| Database | PostgreSQL + PostGIS | Dữ liệu nghiệp vụ và địa lý |
| Bảo mật | Supabase RLS, role/membership | Phân quyền dữ liệu |
| Bản đồ | `flutter_map`, `latlong2`, OpenStreetMap | Tile/marker/polyline và tọa độ |
| GPS | `geolocator` | Quyền vị trí, tọa độ và stream GPS |
| Tìm địa điểm | Nominatim | Geocoding/search |
| Tính tuyến | OSRM | Khoảng cách, thời gian, hình học tuyến |
| POI dọc tuyến | Geoapify; mã nguồn có lựa chọn Overpass | Tìm địa điểm theo tuyến |
| Phân tích địa hình | Open-Meteo | Bằng chứng địa hình cho Connectivity Risk |
| HTTP | `http` | Gọi các dịch vụ bên ngoài |
| Bộ nhớ cục bộ | `shared_preferences` / SharedPreferencesAsync | Snapshot, checklist và track demo |
| Kiểm thử | `flutter_test`, `flutter_lints` | Unit/widget tests và lint |

Phiên bản package cụ thể được khóa bởi [`pubspec.yaml`](pubspec.yaml) và [`pubspec.lock`](pubspec.lock); không nên coi bảng này là cam kết về phiên bản mới nhất của nhà cung cấp.

## 5. Cấu trúc thư mục

```text
PhuotThu/
├── android/                     # Dự án Android native / Gradle
├── ios/                         # Dự án iOS native (chưa xác minh build)
├── lib/
│   ├── main.dart                # Khởi tạo config, Supabase, Router, ProviderScope
│   ├── app/                     # App shell, theme, router
│   ├── core/                    # Cấu hình, logging, Supabase provider
│   └── features/
│       ├── auth/                # Đăng ký / đăng nhập
│       ├── profile/             # Hồ sơ
│       ├── vehicle/             # Phương tiện
│       ├── trips/               # Trip, route, budget, readiness, offline,
│       │                        # local GPS track, hỗ trợ khẩn cấp
│       ├── map/                 # Search, route, POI
│       ├── group_travel/        # Membership, invitation, live GPS,
│       │                        # convoy, checkpoint và progress
│       ├── home/
│       └── community/           # Khung trang, chưa có social đầy đủ
├── supabase/sql/                # SQL đã đưa vào repository
├── test/                        # Automated unit/widget tests
├── README.md                    # Tài liệu dự án tổng hợp
├── TEST_PLAN.md                 # Checklist kiểm thử bổ sung
└── pubspec.yaml                 # Dependencies và cấu hình Dart/Flutter
```

Các file trọng tâm để đọc mã:

- [`lib/features/trips/presentation/pages/trip_route_page.dart`](lib/features/trips/presentation/pages/trip_route_page.dart): tuyến, POI, nhiên liệu, readiness và offline.
- [`lib/features/group_travel/presentation/trip_group_live_map_page.dart`](lib/features/group_travel/presentation/trip_group_live_map_page.dart): bản đồ nhóm và Convoy Safety.
- [`lib/features/group_travel/presentation/trip_checkpoint_management_page.dart`](lib/features/group_travel/presentation/trip_checkpoint_management_page.dart): quản lý điểm hẹn.
- [`lib/features/group_travel/presentation/trip_checkpoint_progress_page.dart`](lib/features/group_travel/presentation/trip_checkpoint_progress_page.dart): điểm danh và tiến độ.
- [`lib/features/trips/presentation/pages/trip_track_page.dart`](lib/features/trips/presentation/pages/trip_track_page.dart): ghi/phát lại track cục bộ.
- [`lib/features/trips/presentation/pages/trip_emergency_page.dart`](lib/features/trips/presentation/pages/trip_emergency_page.dart): nội dung vị trí hỗ trợ khẩn cấp.

## 6. Yêu cầu môi trường

**Đã sử dụng trong quá trình phát triển:** VS Code trên Windows, Flutter SDK, Android SDK và Android Emulator. Trên máy đã chạy kiểm thử có Flutter 3.47.6 và bộ Dart phù hợp. Repository khai báo **Dart SDK `^3.13.5`** trong `pubspec.yaml`; hãy ưu tiên một bộ Flutter tương thích với ràng buộc này.

Chuẩn bị:

1. Git và Flutter SDK tương thích.
2. Android Studio/Android SDK hoặc một thiết bị Android đã bật USB debugging.
3. VS Code + Flutter/Dart extensions (hoặc IDE hỗ trợ Flutter).
4. Một dự án Supabase đã cấu hình Auth, PostgreSQL và RLS.
5. Thông tin cấu hình Supabase và Geoapify; kết nối Internet để dùng các dịch vụ bản đồ/API.

**iOS:** cần macOS và Xcode để build/chạy trên iOS; dự án hiện chưa có kết quả kiểm thử iOS được xác nhận.

Kiểm tra môi trường:

```powershell
flutter --version
flutter doctor -v
flutter devices
```

## 7. Cài đặt và chạy ứng dụng

### 7.1. Clone mã nguồn

```powershell
git clone -b develop https://github.com/anhleduc333/PhuotThu.git
cd PhuotThu
flutter pub get
```

> Nhánh `develop` chứa phiên bản đang được phát triển và kiểm thử trong tài liệu này. Không giả định nhánh mặc định khác có cùng nội dung.

### 7.2. Cấu hình chạy cục bộ

Ứng dụng đọc ba giá trị bằng `String.fromEnvironment` tại [`AppConfig`](lib/core/config/app_config.dart):

| Biến | Mục đích |
| --- | --- |
| `SUPABASE_URL` | URL của dự án Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Khóa **publishable** của Supabase (không phải service role key) |
| `GEOAPIFY_API_KEY` | Khóa gọi Geoapify |

Tạo file JSON **ngoài thư mục Git/repository**, ví dụ `C:\phuotthu-local.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_SUPABASE_PUBLISHABLE_KEY",
  "GEOAPIFY_API_KEY": "YOUR_GEOAPIFY_API_KEY"
}
```

Sau đó chạy:

```powershell
flutter run --dart-define-from-file="C:\phuotthu-local.json"
```

**Quan trọng:**

- Không commit tệp cấu hình có key, mật khẩu, JWT, service role key hoặc dữ liệu người dùng.
- Khóa Supabase `publishable`/`anon` dành cho client; **không bao giờ** nhúng `service_role` vào ứng dụng.
- `--dart-define` **không** phải cơ chế giấu bí mật: giá trị build vào ứng dụng có thể bị trích xuất. Khóa API client phải được giới hạn quyền/quota; dữ liệu nhạy cảm cần xử lý ở backend/proxy.
- Xác thực/quyền truy cập thực tế phải dựa trên Supabase Auth, RLS và chính sách database; không chỉ ẩn nút giao diện.

### 7.3. Chạy kiểm tra tự động

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Nếu đang phát triển, có thể chạy `dart format lib test` trước khi kiểm tra.

### 7.4. Build APK trình diễn

```powershell
flutter build apk --debug --dart-define-from-file="C:\phuotthu-local.json"
```

APK đầu ra:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

**Chưa coi bản release là bản phân phối:** cấu hình `android/app/build.gradle.kts` hiện sử dụng **debug signing cho build release**. Phát hành chính thức cần tạo và quản lý keystore, cấu hình signing, versioning, kiểm thử cài đặt sạch và tuân thủ quy định cửa hàng ứng dụng.

### 7.5. Một số lỗi thường gặp

| Hiện tượng | Cách kiểm tra |
| --- | --- |
| `Missing SUPABASE_URL` hoặc `Missing GEOAPIFY_API_KEY` | Chưa truyền đúng `--dart-define-from-file`; kiểm tra tên biến và JSON |
| Đăng nhập thành công nhưng lỗi truy cập dữ liệu | Kiểm tra Supabase schema, RLS, membership và các RPC đã triển khai |
| Bản đồ/POI/tuyến không tải | Kiểm tra Internet, quota, API key, trạng thái Nominatim/OSRM/Geoapify |
| GPS không cập nhật | Bật dịch vụ vị trí, cấp quyền, cập nhật tọa độ Emulator, bật chia sẻ vị trí |
| Không điểm danh tự động | Kiểm tra Checkpoint cho phép auto-arrival, tư cách active, location sharing, độ mới và accuracy |
| `flutter analyze` phát hiện lint | Xem đúng dòng được báo, sửa và chạy lại tests |
| Git báo file `U` | Là file mới `untracked`; kiểm tra trước khi `git add` |

## 8. Cơ sở dữ liệu và Supabase

### 8.1. Các nhóm dữ liệu chính

- `auth.users` và `profiles`: danh tính và hồ sơ.
- `vehicles`: cấu hình phương tiện.
- `trips`, bảng điểm tuyến và `trip_budget_items`: hành trình, tuyến và ngân sách.
- `trip_members`, lời mời và role: thành viên chuyến đi nhóm.
- `trip_live_locations`: trạng thái vị trí gần nhất cho bản đồ nhóm.
- `trip_checkpoints`: điểm hẹn do chủ/trưởng nhóm quản lý.
- `trip_checkpoint_arrivals`: mỗi thành viên được ghi nhận đến một điểm hẹn, có phương thức `manual` hoặc `gps`.

### 8.2. Các script SQL có trong repository

| File | Nội dung |
| --- | --- |
| [`001_core_schema.sql`](supabase/sql/001_core_schema.sql) | Schema nền: profile, vehicle, trip và một số cấu trúc nhóm ban đầu |
| [`002_trip_route_points.sql`](supabase/sql/002_trip_route_points.sql) | Dữ liệu điểm tuyến |
| [`003_fuel_prices.sql`](supabase/sql/003_fuel_prices.sql) | Giá nhiên liệu |
| [`004_trip_budget_items.sql`](supabase/sql/004_trip_budget_items.sql) | Dự toán chi phí |
| [`005_trip_budget_total_trigger.sql`](supabase/sql/005_trip_budget_total_trigger.sql) | Đồng bộ tổng dự toán |
| [`006_checkpoint_gps_arrival.sql`](supabase/sql/006_checkpoint_gps_arrival.sql) | Trigger điểm danh GPS tự động |
| [`007_verify_checkpoint_gps.sql`](supabase/sql/007_verify_checkpoint_gps.sql) | Truy vấn chỉ đọc để kiểm tra `006` |

**Giới hạn tái dựng backend:** các migration nâng cấp **Group Travel v2, invitation/live location và DEV-09.7A Checkpoint schema/RLS** đã được triển khai khi phát triển nhưng **chưa có đầy đủ dưới dạng migration versioned trong thư mục `supabase/sql` hiện tại**. Vì vậy, **không thể khẳng định clone repository rồi chạy `001–007` sẽ tự dựng được backend đầy đủ từ một Supabase trống**. Muốn triển khai trên môi trường mới phải xuất/chuẩn hóa các migration còn thiếu và kiểm tra thứ tự phụ thuộc trước khi chạy.

**Không** chạy lại `001_core_schema.sql` trên database sản xuất đã có dữ liệu; một số lệnh tạo bảng/trigger của script nền không được thiết kế làm bản nâng cấp lặp an toàn. Không xóa/recreate bảng để xử lý lỗi migration.

### 8.3. GPS Auto Arrival hoạt động thế nào?

Trigger trong `006` chạy sau khi một hàng vị trí nhóm được thêm/cập nhật. Nó chỉ có thể thêm điểm danh nếu đồng thời đáp ứng các điều kiện, bao gồm:

1. Dữ liệu vị trí thuộc người dùng đang được xác thực.
2. Thành viên có trạng thái `active` và đã bật `location_sharing`.
3. Tọa độ hợp lệ, vị trí không cũ quá **90 giây** hoặc vượt thời gian tương lai cho phép.
4. `accuracy_m` đã biết và không vượt **60 m**; kiểm tra thêm ngưỡng theo bán kính checkpoint.
5. Tốc độ GPS không vượt ngưỡng bảo thủ trong trigger.
6. Khoảng cách **đường chim bay + sai số GPS** không vượt bán kính checkpoint và `auto_arrival_enabled = true`.
7. `ON CONFLICT (checkpoint_id, user_id) DO NOTHING` ngăn insert bản ghi trùng theo khóa duy nhất.

Đây là **heuristic dựa trên GPS thiết bị**, không phải bằng chứng không thể giả mạo về sự hiện diện của người dùng.

### 8.4. Kiểm tra sau migration

Chạy `007_verify_checkpoint_gps.sql` trên **Supabase SQL Editor** của môi trường đã được chuẩn bị. Bốn cột đầu tương ứng việc có bảng live location, bảng checkpoint, function và trigger đang bật; mong đợi đều `true`.

Có thể kiểm tra phương thức điểm danh:

```sql
SELECT c.name, a.arrival_method, a.arrived_at,
       a.distance_m, a.gps_accuracy_m
FROM public.trip_checkpoint_arrivals AS a
JOIN public.trip_checkpoints AS c ON c.id = a.checkpoint_id
ORDER BY a.arrived_at DESC
LIMIT 10;
```

Kiểm tra dữ liệu trùng hiện có:

```sql
SELECT checkpoint_id, user_id, COUNT(*) AS arrival_count
FROM public.trip_checkpoint_arrivals
GROUP BY checkpoint_id, user_id
HAVING COUNT(*) > 1;
```

`0 rows` có nghĩa **hiện không có dữ liệu trùng**, nhưng không thay thế bài kiểm thử gửi GPS nhiều lần, đồng thời hoặc giả lập quyền truy cập trái phép.

## 9. Các luồng nghiệp vụ chính

### 9.1. Lập kế hoạch chuyến đi

1. Đăng nhập → khai báo hoặc chọn phương tiện.
2. Tạo chuyến → chọn địa điểm xuất phát/đích đến.
3. Tính tuyến OSRM → xem bản đồ, quãng đường, thời gian.
4. Xem dự toán nhiên liệu/ngân sách và gợi ý cây xăng, ăn uống, nghỉ chân.
5. Phân tích Connectivity Risk, lưu gói offline nền tảng và hoàn thành checklist Trip Readiness.

### 9.2. Chuyến đi nhóm và cảnh báo đoàn

1. Owner bật chuyến đi nhóm và gửi lời mời.
2. Thành viên nhận/chấp nhận lời mời; Owner/Leader quản lý vai trò theo quyền.
3. Mỗi thành viên tự bật quyền chia sẻ vị trí.
4. Group Live Map cập nhật vị trí qua Supabase; Convoy Safety phân tích khoảng cách và tuổi GPS.
5. Owner/Leader đặt Checkpoint trên bản đồ; thành viên xem danh sách/tiến độ.
6. Khi có GPS hợp lệ trong bán kính, database tự ghi nhận; thành viên cũng có đường xác nhận thủ công.

**Các ngưỡng Convoy Safety mặc định trong phiên bản đã kiểm thử:** cảnh báo tách đoàn từ khoảng **500 m**, nghiêm trọng từ **1.500 m**; vị trí cũ khoảng **2 phút**, mất tín hiệu khoảng **5 phút**. Ngưỡng tùy chỉnh theo chính sách, không phải tiêu chuẩn giao thông được chứng nhận.

### 9.3. Track / Replay và hỗ trợ khẩn cấp

- **Track/Replay:** bắt đầu ghi khi màn hình mở → có các điểm GPS → dừng → phát lại bằng marker/slider; track được lưu cục bộ theo chuyến và người dùng. **Không ghi nền và không đồng bộ đám mây.**
- **Thông tin khẩn cấp:** lấy GPS theo quyền của thiết bị → tạo nội dung có tọa độ, thời điểm và đường dẫn bản đồ → người dùng **sao chép và tự chia sẻ**. **Không** có quy trình gửi SOS tự động hay xác nhận cứu hộ.

## 10. Kiểm thử và kết quả đã xác nhận

### 10.1. Automated QA

Kết quả đã được ghi nhận trên máy phát triển Android vào **29/10/2026** (trước khi hợp nhất README):

| Hạng mục | Kết quả quan sát |
| --- | --- |
| `flutter analyze` | **No issues found** |
| `flutter test` | **488/488 tests passed** |
| `flutter build apk --debug` | **Build thành công** |
| Git | Bộ chức năng mở rộng đã commit/push lên `develop` |

Đây là **kết quả chạy thực tế tại thời điểm trên**, không có nghĩa toàn bộ tính năng đã được kiểm thử mọi thiết bị, mọi mạng hoặc iOS. Chỉnh sửa README không thay đổi kết quả test ứng dụng, nhưng nếu có code change mới thì phải chạy lại.

### 10.2. Kiểm thử thực tế đã ghi nhận

- Owner tạo/sửa/xóa Checkpoint; Member chỉ thấy màn hình xem (giới hạn UI).
- Bản đồ nhóm với hai tài khoản; cảnh báo GPS cũ/mất tín hiệu hiển thị.
- Một bản ghi trong `trip_checkpoint_arrivals` có `arrival_method = 'gps'`, khoảng cách **174,85 m**, accuracy **5 m**.
- Truy vấn tìm bản ghi điểm danh trùng trả về **0 hàng** tại thời điểm kiểm tra.
- Track cục bộ ghi được **7 điểm GPS** trên Emulator; người dùng đã xác nhận marker phát lại lần lượt qua các điểm.
- Màn hình hỗ trợ khẩn cấp lấy được vị trí và tạo nội dung để sao chép.

Các bài kiểm thử **chưa được chứng minh đầy đủ**: chống GPS giả mạo, GPS sai số lớn trong mọi tình huống, API/RLS kiểm thử đối kháng A/B, battery/background dài hạn, cài đặt APK release mới trên thiết bị độc lập, iOS và kiểm thử hiệu năng thực địa.

### 10.3. Checklist nghiệm thu nhanh

1. `flutter analyze`, `flutter test`, `flutter build apk --debug`.
2. Đăng nhập A/B, tạo chuyến, bản đồ/tuyến, ngân sách và tìm POI.
3. Owner tạo Checkpoint; Member không có quyền sửa/xóa; **thử RLS bằng request thực nếu nghiệm thu bảo mật**.
4. Tọa độ gần/ngoài checkpoint, GPS mới/cũ, accuracy tốt/kém, bật/tắt sharing.
5. Kiểm tra arrivals trên Supabase và không có dữ liệu trùng.
6. Bản đồ nhóm, cảnh báo tách đoàn và tuổi GPS.
7. Track/Replay trên Emulator và kiểm tra dữ liệu cục bộ sau mở lại.
8. Sao chép thông tin khẩn cấp; xác nhận không có tác vụ tự gửi.
9. Thử trên thiết bị Android cài đặt mới và điều kiện kết nối khác nhau.

Xem thêm [`TEST_PLAN.md`](TEST_PLAN.md) để tham khảo các trường hợp kiểm thử đặc thù của gói mở rộng.

## 11. Bảo mật, quyền riêng tư và an toàn

- **Authentication:** sử dụng Supabase Auth, không tự lưu mật khẩu trong Flutter.
- **Authorization:** thiết kế truy cập theo người dùng, tư cách thành viên, vai trò và database RLS. Ẩn nút UI chỉ là một lớp giao diện, **không** thay thế kiểm thử chính sách database.
- **Location consent:** chỉ chia sẻ vị trí nhóm sau khi người dùng đồng ý và thiết bị cấp quyền. Có thao tác tắt chia sẻ.
- **Dữ liệu GPS:** vị trí có thể cũ, sai lệch, bị chỉnh trên Emulator hoặc giả mạo. Chỉ nên coi cảnh báo/điểm danh là dữ liệu hỗ trợ.
- **API client:** không đưa service role/admin secret vào Flutter, commit hoặc tài liệu. Giới hạn khóa dịch vụ công khai theo quota và chính sách nhà cung cấp.
- **SOS:** nội dung khẩn cấp trong demo **không** đồng nghĩa đã thông báo cho người thân, đơn vị hỗ trợ hoặc lực lượng cứu hộ.
- **An toàn lái xe:** chỉ thao tác khi đã dừng ở vị trí an toàn; không sử dụng cảnh báo của ứng dụng thay cho đánh giá tình huống thực tế.

## 12. Giới hạn hiện tại

1. **Android demo:** chưa xác nhận iOS thực tế hoặc bản release dùng khóa ký phân phối.
2. **Backend reproducibility:** còn thiếu migration versioned cho một số phần Group Travel v2/DEV-09.7A trên repo.
3. **Offline:** có dữ liệu/snapshot cục bộ; chưa hoàn thiện tile bản đồ offline và đồng bộ offline-first.
4. **Checkpoint Progress:** arrivals đang làm mới định kỳ **10 giây**; không phải toàn bộ progress đẩy push tức thì.
5. **GPS Track:** chỉ ghi khi màn hình ghi hành trình đang hoạt động; không ghi nền 24/7.
6. **Emergency:** tạo/copy thông tin, không tự gửi cảnh báo, không gọi SOS tự động.
7. **Community, chat, push notification, recommendation/optimization nâng cao:** chưa hoàn chỉnh.
8. **Dữ liệu bên thứ ba:** phụ thuộc quota, độ phủ, chính sách sử dụng Nominatim/OSRM/OSM/Geoapify/Open-Meteo.
9. **Vận hành:** chưa xác nhận đầy đủ monitoring/crash analytics, thử nghiệm thực địa quy mô lớn, kiểm thử bảo mật chuyên sâu.

## 13. Lộ trình phát triển

| Giai đoạn | Trọng tâm | Định hướng |
| --- | --- | --- |
| **Đồ án cơ sở** | Trip Planner, Route, POI, Fuel/Budget | Đã có lõi hoạt động |
| **Đồ án liên ngành** | Group Travel, invitation, Live Map, Convoy, Checkpoint, Safety/Offline | Các luồng chính đã có; tiếp tục tăng độ ổn định và hoàn thiện |
| **Đồ án tốt nghiệp** | Replay nâng cao, offline-first, SOS/notification, tối ưu/gợi ý, đánh giá thực nghiệm | Cần tiếp tục phát triển và kiểm chứng |

**Ưu tiên gần nhất:**

1. Chuẩn hóa toàn bộ migration Supabase (bao gồm các SQL Group Travel còn thiếu) và script dựng môi trường mới.
2. Kiểm thử hồi quy A/B, RLS trực tiếp, GPS edge cases, cài APK mới và kiểm thử iOS.
3. Hoàn thiện offline bản đồ, chia sẻ vị trí nền nếu được thiết kế/đồng ý phù hợp và xử lý sự cố mạng.
4. Xây dựng SOS/notification thực với thiết kế an toàn, quyền riêng tư và xác nhận gửi.
5. Mở rộng GPS Track/Trip Replay, gợi ý/tối ưu lộ trình và đánh giá thuật toán bằng số liệu.
6. Hoàn thiện UI/UX, tài liệu kiến trúc, kết quả thử nghiệm và quy trình phát hành.

## 14. Quy trình phát triển và đóng góp

Nhánh làm việc chính trong các milestone vừa qua là `develop`.

```powershell
git checkout develop
git pull --ff-only origin develop
flutter pub get
dart format lib test
flutter analyze
flutter test
git status
```

Nguyên tắc thay đổi:

- Giữ tính tương thích với model/repository/provider đã có; viết test cho logic và regression quan trọng.
- Với SQL: xác định thứ tự migration, preflight, rollback và tác động RLS; **không** sửa schema đang có dữ liệu một cách tùy tiện.
- Trước commit: chạy analyze/test, kiểm tra `git diff`, không đưa bí mật hay dữ liệu thật của người dùng vào Git.
- Ưu tiên commit nhỏ, mô tả rõ mục đích, ví dụ `feat:`, `fix:`, `docs:`, `test:`.
- Lưu kết quả kiểm thử/ảnh demo có chủ đích, tránh công bố vị trí GPS cá nhân hoặc khóa cấu hình.

**License:** tại thời điểm viết README, repository **chưa có file `LICENSE` được xác nhận**. Không mặc nhiên suy ra mã nguồn được cấp phép tự do để sử dụng lại hoặc phân phối thương mại.

## 15. Tài liệu tham khảo và ghi nhận

- [Flutter](https://docs.flutter.dev/) / [Dart](https://dart.dev/)
- [Riverpod](https://riverpod.dev/) / [go_router](https://pub.dev/packages/go_router)
- [Supabase](https://supabase.com/docs) / [PostgreSQL](https://www.postgresql.org/docs/) / [PostGIS](https://postgis.net/documentation/)
- [OpenStreetMap](https://www.openstreetmap.org/) / [OSM Copyright & Attribution](https://www.openstreetmap.org/copyright)
- [flutter_map](https://docs.fleaflet.dev/)
- [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/)
- [OSRM](https://project-osrm.org/)
- [Geoapify](https://www.geoapify.com/) / [Open-Meteo](https://open-meteo.com/)
- [Flutter testing](https://docs.flutter.dev/testing/overview)

Ứng dụng sử dụng hoặc tích hợp các dữ liệu/dịch vụ bên thứ ba; việc khai thác phải tuân thủ **giấy phép dữ liệu, yêu cầu ghi nguồn, hạn mức và điều khoản** của từng nhà cung cấp.

---

**PhuotThu — Lập kế hoạch chủ động, đồng hành có thông tin, ưu tiên an toàn.**  
*Tài liệu tổng hợp README dành cho mã nguồn, cài đặt, kiểm thử và báo cáo đồ án; cập nhật ngày 29/10/2026.*
