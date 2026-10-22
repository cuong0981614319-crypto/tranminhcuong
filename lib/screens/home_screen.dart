import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'device_pairing_screen.dart';
import 'child_location_screen.dart';
import 'user_management_screen.dart';
import 'activity_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  bool _isDeviceLocked = false;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final role = (_apiService.currentRole ?? 'PhuHuynh').toLowerCase();
    if (role == 'treem') {
      setState(() => _checkingStatus = true);
      final devices = await _apiService.getChildDevices();
      if (!mounted) return;
      if (devices.isNotEmpty) {
        // Kiểm tra xem thiết bị của bé có đang bị khóa không
        final isLocked = devices.any((d) => d['dangKhoa'] == true);
        setState(() {
          _isDeviceLocked = isLocked;
          _checkingStatus = false;
        });
      } else {
        setState(() => _checkingStatus = false);
      }
    }
  }

  Future<void> _syncChildAndroidActivity() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Đang đồng bộ nhật ký từ máy Android...'),
              ],
            ),
          ),
        ),
      ),
    );

    int childId = 4;
    final devices = await _apiService.getChildDevices();
    if (devices.isNotEmpty) {
      childId = devices.first['id'] ?? 4;
    }

    // Lấy tọa độ GPS phần cứng thực tế của thiết bị
    String realCoords = '10.762622, 106.660172';
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
        );
        realCoords = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }
    } catch (_) {}

    final res = await _apiService.syncAndroidActivity(
      treEmId: childId,
      tenThietBi: 'Samsung Galaxy A15 (Android 14)',
      mucPin: 88,
      viTriHienTai: realCoords,
    );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(res['success'] == true ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(res['message'] ?? 'Đã đồng bộ hoạt động thiết bị lên máy Phụ huynh!')),
          ],
        ),
        backgroundColor: res['success'] == true ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = (_apiService.currentRole ?? 'PhuHuynh').toLowerCase();
    final fullName = _apiService.currentFullName ?? 'Người dùng';
    final username = _apiService.currentUsername ?? 'User';

    final isAdmin = role == 'admin';
    final isChild = role == 'treem';

    String roleBadgeText;
    Color roleBadgeColor;
    if (isAdmin) {
      roleBadgeText = '🛡️ Quản trị viên (Admin)';
      roleBadgeColor = const Color(0xFF7C3AED);
    } else if (isChild) {
      roleBadgeText = '🧒 Chế độ Trẻ Em (Kid Safe)';
      roleBadgeColor = const Color(0xFFF59E0B);
    } else {
      roleBadgeText = '👨‍👩‍👧 Phụ huynh giám sát';
      roleBadgeColor = const Color(0xFF2563EB);
    }

    // Nếu là bé VÀ máy đang bị khóa từ xa -> Hiển thị Màn Hình Khóa Bé!
    if (isChild && _isDeviceLocked) {
      return _buildChildLockScreen(fullName);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: roleBadgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isChild ? Icons.child_care_rounded : Icons.shield_rounded,
                color: roleBadgeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isChild ? 'KidSafe - Máy Của Bé' : 'KidSafe Manager',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isChild ? 'Bảo vệ & đồng hành cùng con' : 'Quản lý điện thoại trẻ em',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: () {
              _apiService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isChild
                      ? [const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFFEC4899)]
                      : isAdmin
                          ? [const Color(0xFF4C1D95), const Color(0xFF6D28D9), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF1E3A8A), const Color(0xFF2563EB), const Color(0xFF38BDF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isChild ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleBadgeText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Server Connection Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'API Backend: ${_apiService.baseUrl}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= GIAO DIỆN DÀNH CHO BÉ (TRẺ EM) =================
            if (isChild) ...[
              const Text(
                'Tình trạng hoạt động của bé',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              // Time card for Kid
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.access_time_filled_rounded, color: Color(0xFFF59E0B), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Thời gian dùng máy hôm nay',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Còn 75 phút',
                            style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        value: 45 / 120,
                        minHeight: 10,
                        backgroundColor: Color(0xFFF1F5F9),
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Đã dùng: 45 phút', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Giới hạn: 120 phút/ngày', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Big SOS Button for Kid
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.call_end_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(child: Text('Đang gửi tín hiệu SOS và gọi khẩn cấp cho Phụ Huynh!')),
                        ],
                      ),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                },
                icon: const Icon(Icons.emergency_rounded, size: 26, color: Colors.white),
                label: const Text(
                  '🆘 GỌI KHẨN CẤP CHO BỐ MẸ (SOS)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 16),

              // Nút đồng bộ Android cho máy của Bé
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _syncChildAndroidActivity,
                  icon: const Icon(Icons.sync_rounded, size: 22, color: Colors.white),
                  label: const Text(
                    '📱 ĐỒNG BỘ HOẠT ĐỘNG ANDROID VỀ CHO PHỤ HUYNH',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Kid Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.08,
                children: [
                  _buildFeatureCard(
                    icon: Icons.add_alarm_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Xin thêm giờ',
                    subtitle: 'Gửi yêu cầu (+30 phút)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã gửi yêu cầu xin thêm 30 phút tới máy Phụ huynh!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.apps_rounded,
                    iconColor: const Color(0xFF059669),
                    title: 'Ứng dụng cho phép',
                    subtitle: 'Học tập, YouTube Kids',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Danh sách: YouTube Kids, Duolingo, Toán vui')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.share_location_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Vị trí an toàn',
                    subtitle: 'Xem định vị GPS của em',
                    onTap: () async {
                      int treEmId = 4;
                      final devices = await _apiService.getChildDevices();
                      if (devices.isNotEmpty) {
                        treEmId = devices.first['id'] ?? 4;
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildLocationScreen(
                            treEmId: treEmId,
                            tenBe: fullName,
                            tenThietBi: 'Điện thoại của bé',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.qr_code_scanner_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Mã kết nối máy',
                    subtitle: 'Mã: DEV-8899',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Mã Ghép Nối Điện Thoại'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF2563EB)),
                              const SizedBox(height: 12),
                              const Text('Đưa mã này cho Bố Mẹ nhập vào máy phụ huynh:'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'DEV-8899',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ]

            // ================= GIAO DIỆN CHO PHỤ HUYNH & ADMIN =================
            else ...[
              Text(
                isAdmin ? 'Tính năng Quản trị & Giám sát' : 'Tính năng Phụ huynh giám sát',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.08,
                children: [
                  _buildFeatureCard(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Ghép nối thiết bị',
                    subtitle: 'Kết nối điện thoại bé',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.lock_clock_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: 'Khóa máy từ xa',
                    subtitle: 'Quản lý khóa & Giờ dùng',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Định vị GPS',
                    subtitle: 'Vị trí hiện tại của con',
                    onTap: () async {
                      int treEmId = 4;
                      String tenBe = 'Bé Tuấn';
                      final devices = await _apiService.getChildDevices();
                      if (devices.isNotEmpty) {
                        treEmId = devices.first['id'] ?? 4;
                        tenBe = devices.first['hoTen'] ?? 'Bé Tuấn';
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildLocationScreen(
                            treEmId: treEmId,
                            tenBe: tenBe,
                            tenThietBi: 'Samsung Galaxy A15',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.history_edu_rounded,
                    iconColor: const Color(0xFF059669),
                    title: 'Nhật ký hoạt động',
                    subtitle: 'Ứng dụng đã xem, Pin',
                    onTap: () async {
                      final devices = await _apiService.getChildDevices();
                      if (!context.mounted) return;

                      if (devices.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chưa có thiết bị nào. Vui lòng bấm "Ghép nối thiết bị" để kết nối điện thoại OPPO của bé!'),
                            backgroundColor: Color(0xFFD97706),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      if (devices.length == 1) {
                        final d = devices.first;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityLogScreen(
                              treEmId: d['id'] as int,
                              tenBe: d['hoTen'] ?? 'Bé',
                              tenThietBi: d['tenThietBi'] ?? 'Điện thoại OPPO',
                            ),
                          ),
                        );
                        return;
                      }

                      // Nếu có nhiều máy, hiện danh sách chọn máy để xem nhật ký
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chọn thiết bị xem Nhật ký', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const SizedBox(height: 12),
                              ...devices.map((d) => ListTile(
                                leading: const Icon(Icons.phone_android_rounded, color: Color(0xFF2563EB)),
                                title: Text(d['hoTen'] ?? 'Bé', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${d['tenThietBi']} • Mã: ${d['maKetNoi']}'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityLogScreen(
                                        treEmId: d['id'] as int,
                                        tenBe: d['hoTen'] ?? 'Bé',
                                        tenThietBi: d['tenThietBi'] ?? 'Điện thoại OPPO',
                                      ),
                                    ),
                                  );
                                },
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (isAdmin)
                    _buildFeatureCard(
                      icon: Icons.manage_accounts_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Quản lý tài khoản',
                      subtitle: 'Danh sách Phụ huynh & Bé',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),
                  _buildFeatureCard(
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: 'Cài đặt SOS',
                    subtitle: 'Số điện thoại khẩn cấp',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Số khẩn cấp SOS: 0981614319 (Bố Mẹ)')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Màn hình khóa máy của bé khi bị bố mẹ khóa từ xa
  Widget _buildChildLockScreen(String childName) {
    return Scaffold(
      backgroundColor: const Color(0xFF7F1D1D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 80, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ĐIỆN THOẠI ĐANG BỊ KHÓA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bố mẹ đã tạm dừng quyền sử dụng điện thoại của $childName.\nVui lòng tập trung học bài hoặc nghỉ ngơi!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),

              // Nút kiểm tra mở khóa
              OutlinedButton.icon(
                onPressed: _checkingStatus ? null : _checkLockStatus,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Kiểm tra trạng thái mở khóa', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // SOS Button duy nhất
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đang gọi khẩn cấp cho Phụ huynh: 0981614319!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                icon: const Icon(Icons.call_rounded, color: Colors.red),
                label: const Text(
                  '🆘 CUỘC GỌI KHẨN CẤP (SOS)',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  _apiService.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
