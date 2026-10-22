import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'child_location_screen.dart';
import 'activity_log_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _devices = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _apiService.getAllUsers();
    final devices = await _apiService.getChildDevices();
    if (!mounted) return;
    setState(() {
      _users = users;
      _devices = devices;
      _isLoading = false;
    });
  }

  // Lọc danh sách máy mà phụ huynh này đang kết nối
  List<Map<String, dynamic>> _getDevicesForUser(Map<String, dynamic> user) {
    final userId = user['id'];
    final username = (user['userName'] ?? '').toString().toLowerCase();
    final fullName = (user['hoTen'] ?? '').toString().toLowerCase();

    return _devices.where((d) {
      final pId = d['phuHuynhId'];
      final pName = (d['tenPhuHuynh'] ?? '').toString().toLowerCase();
      if (pId != null && userId != null && pId.toString().toLowerCase() == userId.toString().toLowerCase()) {
        return true;
      }
      if (pName.isNotEmpty && (pName == username || pName == fullName)) {
        return true;
      }
      return false;
    }).toList();
  }

  // Khóa / Mở khóa thiết bị từ modal của Admin
  Future<void> _toggleLockDevice(Map<String, dynamic> device, StateSetter setModalState) async {
    final id = device['id'] as int;
    final currentLock = device['dangKhoa'] == true;
    final newStatus = !currentLock;

    setModalState(() {
      device['dangKhoa'] = newStatus;
    });

    final res = await _apiService.toggleLockDevice(id, newStatus);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (newStatus ? 'Đã khóa máy!' : 'Đã mở khóa!')),
          backgroundColor: newStatus ? const Color(0xFFDC2626) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } else {
      setModalState(() {
        device['dangKhoa'] = currentLock;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Thao tác thất bại'), backgroundColor: Colors.red),
      );
    }
  }

  // Mở BottomSheet xem chi tiết phụ huynh và các máy đang kết nối
  void _showParentDetailsModal(Map<String, dynamic> user, List<Map<String, dynamic>> parentDevices) {
    final username = user['userName'] ?? '';
    final fullName = user['hoTen'] ?? username;
    final email = user['email'] ?? 'Chưa cập nhật';
    final role = (user['vaiTro'] ?? 'PhuHuynh').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Profile Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text('@$username • $role', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('Email: $email', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Device count summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: parentDevices.isNotEmpty
                          ? [const Color(0xFF065F46), const Color(0xFF059669)]
                          : [const Color(0xFF9A3412), const Color(0xFFEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phonelink_ring_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parentDevices.isNotEmpty
                                  ? 'ĐANG KẾT NỐI ${parentDevices.length} THIẾT BỊ'
                                  : 'CHƯA KẾT NỐI THIẾT BỊ NÀO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parentDevices.isNotEmpty
                                  ? 'Phụ huynh này đang giám sát trực tiếp các máy của con bên dưới.'
                                  : 'Phụ huynh chưa liên kết điện thoại của con qua mã DEV-XXXX.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // List of Devices
                Text(
                  'Danh sách máy của bé (${parentDevices.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                if (parentDevices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'Phụ huynh này chưa kết nối thiết bị nào.\nKhi phụ huynh nhập mã ghép nối, danh sách máy sẽ tự động xuất hiện ở đây.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                      ),
                    ),
                  )
                else
                  ...parentDevices.map((device) {
                    final dId = device['id'] as int;
                    final beName = device['hoTen'] ?? 'Bé';
                    final dName = device['tenThietBi'] ?? 'Smartphone';
                    final dOS = device['heDieuHanh'] ?? 'Android';
                    final dCode = device['maKetNoi'] ?? 'DEV-0000';
                    final dLocked = device['dangKhoa'] == true;
                    final limit = device['gioiHanPhut'] ?? 120;
                    final isApple = dOS.toString().toLowerCase().contains('ios');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: dLocked ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                          width: dLocked ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isApple
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                                child: Icon(
                                  isApple ? Icons.apple_rounded : Icons.android_rounded,
                                  color: isApple ? Colors.white : const Color(0xFF059669),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            beName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: dLocked ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dLocked ? '🔒 ĐANG KHÓA' : '🟢 HOẠT ĐỘNG',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: dLocked ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$dName • Mã: $dCode • Giới hạn: $limit phút/ngày',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Action buttons for Admin on this device
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _toggleLockDevice(device, setModalState),
                                icon: Icon(
                                  dLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  size: 15,
                                  color: dLocked ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                                label: Text(
                                  dLocked ? 'Mở Khóa Máy' : 'Khóa Máy Bé',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: dLocked ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChildLocationScreen(
                                        treEmId: dId,
                                        tenBe: beName,
                                        tenThietBi: dName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.location_on_rounded, size: 14),
                                label: const Text('Xem GPS Máy Này', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityLogScreen(
                                        treEmId: dId,
                                        tenBe: beName,
                                        tenThietBi: dName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.history_edu_rounded, size: 14),
                                label: const Text('Nhật Ký Máy Này', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                // Edit parent button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditUserDialog(user);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Chỉnh Sửa Thông Tin Phụ Huynh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (username.toLowerCase() != 'admin') const SizedBox(height: 10),

                // Delete parent button
                if (username.toLowerCase() != 'admin')
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleDeleteUser(username);
                    },
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Xóa Tài Khoản Phụ Huynh Này'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mở Dialog chỉnh sửa thông tin người dùng
  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final username = (user['userName'] ?? '').toString();
    final isRootAdmin = username.toLowerCase() == 'admin';

    final nameController = TextEditingController(text: user['hoTen'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final passwordController = TextEditingController();

    String selectedRole = (user['vaiTro'] ?? 'PhuHuynh').toString();
    if (selectedRole != 'Admin' && selectedRole != 'TreEm' && selectedRole != 'PhuHuynh') {
      selectedRole = 'PhuHuynh';
    }

    bool obscurePassword = true;
    bool isSaving = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sửa Người Dùng',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '@$username',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogCtx).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Họ và tên
                  const Text('Họ và tên', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      hintText: 'Nhập họ và tên',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const Text('Địa chỉ Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      hintText: 'Nhập email liên hệ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Vai trò
                  const Text('Vai trò tài khoản', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  if (isRootAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 20),
                          SizedBox(width: 8),
                          Text('Quản Trị Viên (Admin Tối Cao)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PhuHuynh',
                          child: Text('Phụ Huynh (Quản lý bé)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'TreEm',
                          child: Text('Trẻ Em (Thiết bị con)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Admin',
                          child: Text('Quản Trị Viên (Admin)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  const SizedBox(height: 14),

                  // Mật khẩu mới
                  const Text('Mật khẩu mới (Tùy chọn)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                      hintText: 'Để trống nếu giữ nguyên mật khẩu',
                      helperText: 'Chỉ nhập khi cần đặt lại mật khẩu cho tài khoản',
                      helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newFullName = nameController.text.trim();
                      final newEmail = emailController.text.trim();
                      final newPass = passwordController.text.trim();

                      if (newFullName.isEmpty) {
                        setDialogState(() => errorMessage = 'Vui lòng nhập họ và tên');
                        return;
                      }

                      if (newEmail.isNotEmpty && !newEmail.contains('@')) {
                        setDialogState(() => errorMessage = 'Email không hợp lệ');
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      final res = await _apiService.updateUser(
                        username: username,
                        fullName: newFullName,
                        email: newEmail.isNotEmpty ? newEmail : null,
                        role: selectedRole,
                        newPassword: newPass.isNotEmpty ? newPass : null,
                      );

                      if (!dialogCtx.mounted || !mounted) return;

                      if (res['success'] == true) {
                        Navigator.of(dialogCtx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Đã cập nhật thông tin thành công!'),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _loadData();
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = res['message'] ?? 'Cập nhật thất bại';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteUser(String username) async {
    if (username.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa tài khoản Admin tối cao!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài khoản'),
        content: Text('Bạn có chắc chắn muốn xóa tài khoản "$username" khỏi hệ thống?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _apiService.deleteUser(username);
      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Đã xóa tài khoản thành công!'), backgroundColor: const Color(0xFF10B981)),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Xóa thất bại!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final q = _searchQuery.toLowerCase();
      final username = (u['userName'] ?? '').toString().toLowerCase();
      final fullName = (u['hoTen'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['vaiTro'] ?? '').toString().toLowerCase();
      return username.contains(q) || fullName.contains(q) || email.contains(q) || role.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản Trị Người Dùng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm phụ huynh, bé, username...',
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // User count stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tổng tài khoản: ${_users.length} • Thiết bị: ${_devices.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hiển thị: ${filteredUsers.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? const Center(child: Text('Không tìm thấy tài khoản nào.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final username = user['userName'] ?? '';
                          final fullName = user['hoTen'] ?? username;
                          final email = user['email'] ?? '';
                          final role = (user['vaiTro'] ?? 'PhuHuynh').toString();

                          final isParent = role.toLowerCase() == 'phuhuynh';
                          final parentDevices = _getDevicesForUser(user);

                          Color roleColor;
                          String roleLabel;
                          if (role.toLowerCase() == 'admin') {
                            roleColor = const Color(0xFF7C3AED);
                            roleLabel = 'Admin';
                          } else if (role.toLowerCase() == 'treem') {
                            roleColor = const Color(0xFFF59E0B);
                            roleLabel = 'Trẻ Em';
                          } else {
                            roleColor = const Color(0xFF2563EB);
                            roleLabel = 'Phụ Huynh';
                          }

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: isParent
                                  ? () => _showParentDetailsModal(user, parentDevices)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: roleColor.withValues(alpha: 0.15),
                                      child: Text(
                                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  fullName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  roleLabel,
                                                  style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('@$username • $email', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),

                                          // Nếu là phụ huynh: Hiển thị huy hiệu số máy đã kết nối!
                                          if (isParent) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: parentDevices.isNotEmpty
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: parentDevices.isNotEmpty
                                                      ? const Color(0xFF86EFAC)
                                                      : const Color(0xFFFDE68A),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone_android_rounded,
                                                    size: 13,
                                                    color: parentDevices.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      parentDevices.isNotEmpty
                                                          ? '${parentDevices.length} máy kết nối'
                                                          : 'Chưa kết nối máy',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: parentDevices.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 19),
                                          tooltip: 'Sửa thông tin',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showEditUserDialog(user),
                                        ),
                                        if (username.toLowerCase() != 'admin') ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 19),
                                            tooltip: 'Xóa tài khoản',
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _handleDeleteUser(username),
                                          ),
                                        ],
                                        if (isParent) ...[
                                          const SizedBox(width: 2),
                                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
