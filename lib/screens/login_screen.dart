import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../widgets/otp_dialog.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiService = ApiService();

  // Login Form Controllers
  final _loginUsernameController = TextEditingController(text: 'admin');
  final _loginPasswordController = TextEditingController(text: 'Admin@123');
  bool _loginObscure = true;
  bool _loginLoading = false;

  // Register Form Controllers
  final _regFullNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _selectedRole = 'PhuHuynh';
  bool _regObscure = true;
  bool _regLoading = false;
  bool _enableFingerprintOnRegister = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regFullNameController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  // Xử lý Đăng Nhập
  Future<void> _handleLogin() async {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng điền đầy đủ Tên đăng nhập và Mật khẩu', isError: true);
      return;
    }

    setState(() => _loginLoading = true);

    final res = await _apiService.login(username, password);

    if (!mounted) return;
    setState(() => _loginLoading = false);

    if (res['success'] == true) {
      final data = res['data'];
      final requiresOtp = data['requiresOtp'] == true;

      if (!requiresOtp) {
        // Lưu thông tin để kích hoạt vân tay cho các lần đăng nhập sau
        await BiometricService().saveCredentials(username, password);
        if (!mounted) return;

        // Đăng nhập thẳng (Admin hoặc Trẻ Em)
        final role = (data['vaiTro'] ?? data['role'] ?? 'Admin').toString();
        final isChild = role.toLowerCase() == 'treem';
        _showSnackBar(isChild ? 'Chào mừng bé đã đăng nhập máy!' : 'Đăng nhập thành công với quyền Admin!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Cần OTP qua Gmail (Phụ huynh / Nhân viên)
        _showOtpSheet(
          username: username,
          email: data['email'],
          otpDemo: data['otpDemo'],
        );
      }
    } else {
      _showSnackBar(res['message'] ?? 'Đăng nhập thất bại', isError: true);
    }
  }

  // Mở BottomSheet nhập OTP
  void _showOtpSheet({
    required String username,
    String? email,
    String? otpDemo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => OtpVerificationSheet(
        username: username,
        email: email,
        otpDemo: otpDemo,
        onSuccess: () async {
          final password = _loginPasswordController.text.trim();
          if (password.isNotEmpty) {
            await BiometricService().saveCredentials(username, password);
          }
          if (!mounted) return;
          _showSnackBar('Xác thực OTP thành công! Chào mừng bạn.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
      ),
    );
  }

  // Xử lý Đăng Nhập bằng Vân Tay / Sinh Trắc Học
  Future<void> _handleBiometricLogin() async {
    final bio = BiometricService();
    final saved = await bio.getSavedCredentials();

    if (saved == null) {
      final currentUsername = _loginUsernameController.text.trim();
      final currentPassword = _loginPasswordController.text.trim();

      if (currentUsername.isEmpty || currentPassword.isEmpty) {
        _showSnackBar(
          'Vui lòng đăng nhập bằng mật khẩu 1 lần đầu tiên để ghi nhớ vân tay!',
          isError: true,
        );
        return;
      }

      final authenticated = await bio.authenticate(
        reason: 'Quét vân tay để liên kết và đăng nhập tài khoản "$currentUsername"',
      );

      if (authenticated) {
        await bio.saveCredentials(currentUsername, currentPassword);
        _showSnackBar('Đã xác thực vân tay thành công! Đang đăng nhập...');
        _handleLogin();
      } else {
        _showSnackBar('Thiết bị chưa quét được vân tay hoặc bạn đã hủy.', isError: true);
      }
      return;
    }

    final authenticated = await bio.authenticate(
      reason: 'Quét vân tay để đăng nhập nhanh tài khoản "${saved['username']}"',
    );

    if (authenticated && mounted) {
      _loginUsernameController.text = saved['username']!;
      _loginPasswordController.text = saved['password']!;
      _showSnackBar('Quét vân tay chính xác! Đang vào hệ thống...');
      _handleLogin();
    } else if (!authenticated && mounted) {
      _showSnackBar('Xác thực vân tay không thành công hoặc bạn đã hủy.', isError: true);
    }
  }

  // Xử lý Đăng Ký
  Future<void> _handleRegister() async {
    final fullName = _regFullNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text.trim();

    if (fullName.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ tất cả thông tin', isError: true);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar('Email không đúng định dạng', isError: true);
      return;
    }

    setState(() => _regLoading = true);

    final res = await _apiService.register(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      role: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _regLoading = false);

    if (res['success'] == true) {
      if (_enableFingerprintOnRegister) {
        // Lưu thông tin vào sinh trắc học
        await BiometricService().saveCredentials(username, password);

        // Yêu cầu quét vân tay để kích hoạt luôn
        final authOk = await BiometricService().authenticate(
          reason: 'Quét vân tay để kích hoạt đăng nhập nhanh cho "$username"',
        );

        if (!mounted) return;

        if (authOk) {
          _showSnackBar('Đăng ký & Kích hoạt vân tay thành công! Đang vào hệ thống...');
          _loginUsernameController.text = username;
          _loginPasswordController.text = password;
          _handleLogin();
          return;
        }
      }

      _showSnackBar('Tạo tài khoản thành công! Vui lòng đăng nhập.');
      _loginUsernameController.text = username;
      _loginPasswordController.text = password;
      _tabController.animateTo(0);
    } else {
      _showSnackBar(res['message'] ?? 'Đăng ký thất bại', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Hộp thoại chỉnh cấu hình Server API URL
  void _showServerSettingsDialog() {
    final urlController = TextEditingController(text: _apiService.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Cấu hình Máy Chủ API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ Backend .NET Web API của bạn:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'http://localhost:5151',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQuickChip('☁️ Conveyor Cloud', 'https://largeorangehen46.conveyor.cloud', urlController),
                _buildQuickChip('Localhost (PC)', 'http://localhost:5151', urlController),
                _buildQuickChip('Android Emulator', 'http://10.0.2.2:5151', urlController),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _apiService.updateBaseUrl(urlController.text);
              Navigator.pop(ctx);
              _showSnackBar('Đã cập nhật máy chủ: ${_apiService.baseUrl}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String url, TextEditingController controller) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => controller.text = url,
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Header
          Container(
            height: size.height * 0.40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Header Glow Circle 1
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
              ),
            ),
          ),

          // Header Glow Circle 2
          Positioned(
            top: 60,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar Icons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'KidSafe 2.0',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        tooltip: 'Cài đặt kết nối máy chủ',
                        onPressed: _showServerSettingsDialog,
                      ),
                    ],
                  ),
                ),

                // Brand Logo & Title
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phonelink_lock_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quản Lý Điện Thoại Trẻ Em',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đồng hành & Bảo vệ sự an toàn số cho bé',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),

                // Main Card Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 25,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Tab Bar Switcher
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              labelColor: const Color(0xFF2563EB),
                              unselectedLabelColor: const Color(0xFF64748B),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              tabs: const [
                                Tab(text: 'Đăng Nhập'),
                                Tab(text: 'Đăng Ký Mới'),
                              ],
                            ),
                          ),
                        ),

                        // Tab Bar Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginForm(),
                              _buildRegisterForm(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Giao diện Tab Đăng Nhập
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Chào mừng phụ huynh trở lại! 👋',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập thông tin tài khoản để truy cập hệ thống giám sát',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // Username
          _buildTextField(
            controller: _loginUsernameController,
            label: 'Tên đăng nhập',
            hint: 'Nhập tên đăng nhập...',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Password
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Mật khẩu',
            hint: 'Nhập mật khẩu...',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _loginObscure,
            onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
          ),

          const SizedBox(height: 12),

          // Shortcut chips for quick fill test
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loginUsernameController.text = 'admin';
                    _loginPasswordController.text = 'Admin@123';
                  });
                },
                icon: const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF2563EB)),
                label: const Text(
                  'Mẫu: Admin',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loginUsernameController.text = 'be_tuan';
                    _loginPasswordController.text = '1234';
                  });
                },
                icon: const Icon(Icons.child_care_rounded, size: 15, color: Color(0xFFF59E0B)),
                label: const Text(
                  'Mẫu: Trẻ Em',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Login Button
          ElevatedButton(
            onPressed: _loginLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _loginLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ĐĂNG NHẬP NGAY',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // Fingerprint / Biometric Login Button
          OutlinedButton.icon(
            onPressed: _loginLoading ? null : _handleBiometricLogin,
            icon: const Icon(Icons.fingerprint_rounded, size: 26, color: Color(0xFF2563EB)),
            label: const Text(
              'ĐĂNG NHẬP BẰNG VÂN TAY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
                letterSpacing: 0.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF93C5FD), width: 1.5),
              backgroundColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),

          const SizedBox(height: 18),

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hệ thống tự động kích hoạt mã xác minh OTP qua Gmail khi đăng nhập bằng tài khoản Phụ huynh.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Giao diện Tab Đăng Ký Mới
  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Đăng ký tài khoản mới 🚀',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tạo tài khoản để bắt đầu giám sát và bảo vệ điện thoại con yêu',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // Họ tên
          _buildTextField(
            controller: _regFullNameController,
            label: 'Họ và tên phụ huynh',
            hint: 'Ví dụ: Nguyễn Văn A',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),

          // Username
          _buildTextField(
            controller: _regUsernameController,
            label: 'Tên đăng nhập',
            hint: 'Ví dụ: me_bong123',
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 14),

          // Email
          _buildTextField(
            controller: _regEmailController,
            label: 'Địa chỉ Gmail (Nhận mã OTP)',
            hint: 'example@gmail.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // Password
          _buildTextField(
            controller: _regPasswordController,
            label: 'Mật khẩu',
            hint: 'Nhập mật khẩu an toàn...',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _regObscure,
            onToggleObscure: () => setState(() => _regObscure = !_regObscure),
          ),
          const SizedBox(height: 14),

          // Vai trò
          const Text(
            'Vai trò người dùng',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildRoleRadio('PhuHuynh', 'Phụ Huynh', Icons.family_restroom_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleRadio('TreEm', 'Tài Khoản Trẻ Em', Icons.child_care_rounded),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tùy chọn kích hoạt vân tay khi đăng ký
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kích hoạt đăng nhập vân tay',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                      Text(
                        'Ghi nhớ & quét vân tay ngay sau khi đăng ký',
                        style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _enableFingerprintOnRegister,
                    activeThumbColor: const Color(0xFF2563EB),
                    onChanged: (val) => setState(() => _enableFingerprintOnRegister = val),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Register Button
          ElevatedButton(
            onPressed: _regLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _regLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'TẠO TÀI KHOẢN NGAY',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.person_add_alt_1_rounded, size: 20),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRoleRadio(String value, String title, IconData icon) {
    final isSelected = _selectedRole == value;
    return InkWell(
      onTap: () => setState(() => _selectedRole = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
