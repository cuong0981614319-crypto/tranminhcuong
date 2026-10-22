import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initDefaultUrl();
  }

  late String baseUrl;
  String? currentToken;
  String? currentRole;
  String? currentUsername;
  String? currentFullName;
  String? currentUserId;

  void _initDefaultUrl() {
    // URL Conveyor Cloud chính thức (chỉ lấy domain gốc, không kèm /api/Authenticate)
    baseUrl = 'https://largeorangehen46.conveyor.cloud';
  }

  void updateBaseUrl(String newUrl) {
    var url = newUrl.trim();
    // Tự động chuẩn hóa nếu người dùng dán kèm đuôi swagger hoặc api/Authenticate
    url = url.replaceAll(RegExp(r'/swagger(/index\.html)?$'), '');
    url = url.replaceAll(RegExp(r'/api/Authenticate$'), '');
    url = url.replaceAll(RegExp(r'/api$'), '');
    url = url.replaceAll(RegExp(r'/+$'), '');
    baseUrl = url;
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (currentToken != null && currentToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $currentToken';
    }
    return headers;
  }

  // ==================== AUTHENTICATION ====================

  // 1. Đăng nhập Bước 1 (Gửi Username & Mật khẩu)
  Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/login');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenDangNhap': username.trim(),
          'matKhau': password.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (data['requiresOtp'] == false) {
          // Đăng nhập thẳng (Admin hoặc Trẻ Em)
          currentToken = data['token'];
          currentRole = data['vaiTro'] ?? data['role'] ?? 'Admin';
          currentUsername = username;
          currentFullName = data['hoTen'] ?? (currentRole == 'TreEm' ? 'Tài khoản Bé' : 'Quản Trị Viên');
          currentUserId = data['userId'];
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đăng nhập không thành công (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ API: $e\n(Địa chỉ: $baseUrl)',
      };
    }
  }

  // 2. Đăng nhập Bước 2 (Xác thực OTP qua Gmail)
  Future<Map<String, dynamic>> verifyOtp(String username, String otp) async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/verify-otp');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenDangNhap': username.trim(),
          'maOtp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        currentToken = data['token'];
        currentRole = data['vaiTro'] ?? data['role'] ?? 'PhuHuynh';
        currentUsername = username;
        currentFullName = data['hoTen'] ?? username;
        currentUserId = data['userId'];
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Mã OTP không hợp lệ!',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi xác thực OTP: $e',
      };
    }
  }

  // 3. Đăng ký tài khoản mới
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/register');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenDangNhap': username.trim(),
          'email': email.trim(),
          'matKhau': password.trim(),
          'hoTen': fullName.trim(),
          'vaiTro': role,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Đăng ký thành công!'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đăng ký thất bại (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi đăng ký: $e',
      };
    }
  }

  // ==================== QUẢN LÝ THIẾT BỊ TRẺ EM (KẾT NỐI ĐIỆN THOẠI) ====================

  // Lấy danh sách thiết bị bé
  Future<List<Map<String, dynamic>>> getChildDevices() async {
    final uri = Uri.parse('$baseUrl/api/TreEm');
    try {
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('data')) {
          final list = body['data'] as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Thêm / Kết nối thiết bị của bé mới
  Future<Map<String, dynamic>> addPairDevice({
    required String hoTen,
    required String tenThietBi,
    required String heDieuHanh,
    required int gioiHanPhut,
    required String sdtKhanCap,
    required String maKetNoi,
  }) async {
    final uri = Uri.parse('$baseUrl/api/TreEm');
    try {
      final response = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'hoTen': hoTen,
          'tenThietBi': tenThietBi,
          'heDieuHanh': heDieuHanh,
          'gioiHanPhut': gioiHanPhut,
          'dangKhoa': false,
          'sdtKhanCap': sdtKhanCap,
          'maKetNoi': maKetNoi,
          'phuHuynhId': currentUserId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data['data'] ?? data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Kết nối thiết bị thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Khóa / Mở khóa thiết bị từ xa
  Future<Map<String, dynamic>> toggleLockDevice(int id, bool? status) async {
    var url = '$baseUrl/api/TreEm/$id/khoa-thiet-bi';
    if (status != null) {
      url += '?trangThai=$status';
    }
    final uri = Uri.parse(url);
    try {
      final response = await http.put(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'dangKhoa': data['dangKhoa'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Không thể khóa máy'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi gọi API khóa máy: $e'};
    }
  }

  // Xóa thiết bị kết nối
  Future<bool> deleteDevice(int id) async {
    final uri = Uri.parse('$baseUrl/api/TreEm/$id');
    try {
      final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==================== ĐỊNH VỊ GPS & NHẬT KÝ ====================

  // Lấy nhật ký / Vị trí hiện tại của bé
  Future<List<Map<String, dynamic>>> getDeviceLogs(int treEmId) async {
    final uri = Uri.parse('$baseUrl/api/NhatKy/tre-em/$treEmId');
    try {
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('data')) {
          final list = body['data'] as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Ghi nhận vị trí mới / log mới từ điện thoại của bé
  Future<Map<String, dynamic>> sendLocationPing({
    required int treEmId,
    required String viTriHienTai,
    required int mucPin,
    required String canhBao,
  }) async {
    final uri = Uri.parse('$baseUrl/api/NhatKy');
    try {
      final response = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'treEmId': treEmId,
          'thoiGianDungPhut': 15,
          'ungDung': 'Định vị GPS Hệ Thống',
          'mucPin': mucPin,
          'viTriHienTai': viTriHienTai,
          'canhBao': canhBao,
          'nhanVienGhi': 'GPS Tự Động',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
    } catch (_) {}
    return {'success': false};
  }

  // Lấy lịch sử di chuyển GPS có cấu trúc
  Future<List<Map<String, dynamic>>> getLocationHistory(int treEmId) async {
    final uri = Uri.parse('$baseUrl/api/NhatKy/lich-su-di-chuyen/$treEmId');
    try {
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('data')) {
          final list = body['data'] as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Đồng bộ hoạt động từ thiết bị Android của bé
  Future<Map<String, dynamic>> syncAndroidActivity({
    required int treEmId,
    String tenThietBi = 'Điện thoại OPPO (Android)',
    int mucPin = 88,
    String viTriHienTai = '10.762622, 106.660172',
    List<Map<String, dynamic>>? danhSachUngDung,
  }) async {
    final uri = Uri.parse('$baseUrl/api/NhatKy/dong-bo-android');
    try {
      final apps = danhSachUngDung ?? [
        {'tenUngDung': 'YouTube Kids', 'thoiGianDungPhut': 40, 'canhBao': 'Quá 30 phút'},
        {'tenUngDung': 'Roblox', 'thoiGianDungPhut': 25, 'canhBao': 'Bình thường'},
        {'tenUngDung': 'Duolingo', 'thoiGianDungPhut': 20, 'canhBao': 'Học tập tốt'},
        {'tenUngDung': 'TikTok', 'thoiGianDungPhut': 15, 'canhBao': 'Cảnh báo nội dung'},
      ];

      final response = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'treEmId': treEmId,
          'tenThietBi': tenThietBi,
          'mucPin': mucPin,
          'viTriHienTai': viTriHienTai,
          'danhSachUngDung': apps,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Đồng bộ Android thành công!',
        'data': data,
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối đồng bộ: $e'};
    }
  }

  // ==================== QUẢN LÝ TÀI KHOẢN (ADMIN) ====================

  // Lấy danh sách toàn bộ người dùng
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/users');
    try {
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Xóa người dùng (Admin)
  Future<Map<String, dynamic>> deleteUser(String username) async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/users/$username');
    try {
      final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi khi xóa tài khoản: $e'};
    }
  }

  // Cập nhật thông tin người dùng (Admin)
  Future<Map<String, dynamic>> updateUser({
    required String username,
    String? fullName,
    String? email,
    String? role,
    String? newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/api/Authenticate/users/$username');
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['hoTen'] = fullName.trim();
      if (email != null) body['email'] = email.trim();
      if (role != null) body['vaiTro'] = role.trim();
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        body['matKhauMoi'] = newPassword.trim();
      }

      final response = await http.put(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Cập nhật tài khoản thành công!',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Cập nhật thất bại (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối khi cập nhật tài khoản: $e'};
    }
  }

  void logout() {
    currentToken = null;
    currentRole = null;
    currentUsername = null;
    currentFullName = null;
    currentUserId = null;
  }
}
