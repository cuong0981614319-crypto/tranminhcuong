import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_sync_helper.dart';
import 'child_location_screen.dart';
import 'activity_log_screen.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getChildDevices();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _isLoading = false;
    });
  }

  // Khóa / Mở khóa thiết bị từ xa
  Future<void> _toggleLock(Map<String, dynamic> device) async {
    final id = device['id'] as int;
    final currentLock = device['dangKhoa'] == true;
    final newStatus = !currentLock;

    // Cập nhật optimistic
    setState(() {
      device['dangKhoa'] = newStatus;
    });

    final res = await _apiService.toggleLockDevice(id, newStatus);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (newStatus ? 'Đã khóa máy của bé!' : 'Đã mở khóa máy của bé!')),
          backgroundColor: newStatus ? const Color(0xFFDC2626) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Revert if failed
      setState(() {
        device['dangKhoa'] = currentLock;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Thao tác thất bại'), backgroundColor: Colors.red),
      );
    }
  }

  // Mở hộp thoại thêm kết nối máy mới
  Future<void> _showAddDeviceDialog() async {
    final actualName = await DeviceSyncHelper.getActualDeviceName();
    final hoTenController = TextEditingController();
    final tenThietBiController = TextEditingController(text: actualName);
    final sdtKhanCapController = TextEditingController(text: '0981614319');
    final maKetNoiController = TextEditingController(text: 'DEV-${Random().nextInt(9000) + 1000}');
    String heDieuHanh = 'Android';
    int gioiHanPhut = 120;
    bool isSubmitting = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.phonelink_ring_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Ghép Nối Máy Bé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập thông tin hoặc mã ghép nối hiển thị trên điện thoại của bé:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hoTenController,
                  decoration: InputDecoration(
                    labelText: 'Tên của bé *',
                    hintText: 'Ví dụ: Bé An, Bé Tuấn...',
                    prefixIcon: const Icon(Icons.face_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tenThietBiController,
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị điện thoại *',
                    hintText: 'Ví dụ: Samsung A15, iPhone 13...',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maKetNoiController,
                  decoration: InputDecoration(
                    labelText: 'Mã Ghép Nối (DEV-XXXX) *',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sdtKhanCapController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại SOS khẩn cấp',
                    prefixIcon: const Icon(Icons.phone_in_talk_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Hệ điều hành: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ChoiceChip(
                      label: const Text('Android'),
                      selected: heDieuHanh == 'Android',
                      onSelected: (val) => setDialogState(() => heDieuHanh = 'Android'),
                    ),
                    ChoiceChip(
                      label: const Text('iOS (iPhone)'),
                      selected: heDieuHanh == 'iOS',
                      onSelected: (val) => setDialogState(() => heDieuHanh = 'iOS'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Giới hạn dùng máy: $gioiHanPhut phút/ngày (${(gioiHanPhut / 60).toStringAsFixed(1)} giờ)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                Slider(
                  value: gioiHanPhut.toDouble(),
                  min: 30,
                  max: 360,
                  divisions: 11,
                  activeColor: const Color(0xFF2563EB),
                  label: '$gioiHanPhut phút',
                  onChanged: (val) => setDialogState(() => gioiHanPhut = val.toInt()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (hoTenController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập tên của bé!')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      final res = await _apiService.addPairDevice(
                        hoTen: hoTenController.text.trim(),
                        tenThietBi: tenThietBiController.text.trim(),
                        heDieuHanh: heDieuHanh,
                        gioiHanPhut: gioiHanPhut,
                        sdtKhanCap: sdtKhanCapController.text.trim(),
                        maKetNoi: maKetNoiController.text.trim(),
                      );

                      nav.pop();

                      if (res['success'] == true) {
                        // TỰ ĐỘNG ĐỒNG BỘ NHẬT KÝ HOẠT ĐỘNG TỪ THIẾT BỊ VỪA KẾT NỐI
                        final deviceData = res['data'];
                        int? newTreEmId;
                        if (deviceData is Map) {
                          final rawId = deviceData['id'] ?? deviceData['treEmId'];
                          if (rawId is int) {
                            newTreEmId = rawId;
                          } else if (rawId != null) {
                            newTreEmId = int.tryParse(rawId.toString());
                          }
                        }

                        if (newTreEmId != null) {
                          _apiService.syncAndroidActivity(
                            treEmId: newTreEmId,
                            tenThietBi: tenThietBiController.text.trim().isNotEmpty
                                ? tenThietBiController.text.trim()
                                : 'Thiết bị của bé',
                          );
                        }

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text('Đã kết nối và tự động đồng bộ nhật ký từ máy của bé!')),
                              ],
                            ),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _loadDevices();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(content: Text(res['message'] ?? 'Lỗi ghép nối!'), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kết nối ngay'),
            ),
          ],
        ),
      ),
    );
  }

  // Xóa thiết bị
  Future<void> _deleteDevice(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy ghép nối thiết bị?'),
        content: Text('Bạn có chắc chắn muốn ngắt kết nối với điện thoại của bé "$name" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hủy kết nối'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _apiService.deleteDevice(id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa thiết bị thành công!')),
        );
        _loadDevices();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Kết Nối Điện Thoại Bé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadDevices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Ghép Nối Thiết Bị', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDevices,
              child: _devices.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: _devices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return _buildDeviceCard(device);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phonelink_setup_rounded, size: 70, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có thiết bị nào được ghép nối',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn nút "Ghép Nối Thiết Bị" bên dưới để liên kết điện thoại của con với tài khoản phụ huynh.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ghép Nối Máy Bé Ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final id = device['id'] as int;
    final hoTen = device['hoTen'] ?? 'Bé';
    final tenThietBi = device['tenThietBi'] ?? 'Smartphone';
    final heDieuHanh = device['heDieuHanh'] ?? 'Android';
    final dangKhoa = device['dangKhoa'] == true;
    final maKetNoi = device['maKetNoi'] ?? 'DEV-0000';
    final gioiHanPhut = device['gioiHanPhut'] ?? 120;
    final isApple = heDieuHanh.toString().toLowerCase().contains('ios');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dangKhoa ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: dangKhoa ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isApple
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF3DDC84).withValues(alpha: 0.2),
                  child: Icon(
                    isApple ? Icons.apple_rounded : Icons.android_rounded,
                    color: isApple ? Colors.white : const Color(0xFF0F9D58),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hoTen,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: dangKhoa ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dangKhoa ? '🔒 ĐANG KHÓA' : '🟢 HOẠT ĐỘNG',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tenThietBi • Mã: $maKetNoi',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giới hạn: $gioiHanPhut phút/ngày • Pin: 85%',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8)),
                  tooltip: 'Hủy kết nối',
                  onPressed: () => _deleteDevice(id, hoTen),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Khóa máy từ xa
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleLock(device),
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dangKhoa ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            dangKhoa ? 'Đang khóa' : 'Khóa máy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: dangKhoa,
                            activeThumbColor: const Color(0xFFDC2626),
                            onChanged: (val) => _toggleLock(device),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Xem vị trí GPS
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChildLocationScreen(
                          treEmId: id,
                          tenBe: hoTen,
                          tenThietBi: tenThietBi,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on_rounded, size: 14),
                  label: const Text('Định Vị', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),

                // Xem nhật ký hoạt động
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityLogScreen(
                          treEmId: id,
                          tenBe: hoTen,
                          tenThietBi: tenThietBi,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_edu_rounded, size: 14),
                  label: const Text('Nhật Ký', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
