import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OtpVerificationSheet extends StatefulWidget {
  final String username;
  final String? email;
  final String? otpDemo;
  final VoidCallback onSuccess;

  const OtpVerificationSheet({
    super.key,
    required this.username,
    this.email,
    this.otpDemo,
    required this.onSuccess,
  });

  @override
  State<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<OtpVerificationSheet> {
  final _otpController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  int _remainingSeconds = 300; // 5 phút
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Tự động điền nếu là demo để tiện test
    if (widget.otpDemo != null && widget.otpDemo!.isNotEmpty) {
      _otpController.text = widget.otpDemo!;
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _apiService.verifyOtp(widget.username, otp);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Xác thực không thành công!';
      });
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          const SizedBox(height: 20),
          // Icon badge
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                size: 38,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Xác thực mã OTP 2 lớp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.email != null && widget.email!.isNotEmpty
                ? 'Mã xác thực đã được gửi đến email:\n${widget.email}'
                : 'Vui lòng kiểm tra mã xác thực trong hộp thư Gmail của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Demo Badge nếu có
          if (widget.otpDemo != null && widget.otpDemo!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    'Mã OTP gửi từ server: ${widget.otpDemo}',
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Ô nhập OTP
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _errorMessage != null
                    ? Colors.red
                    : const Color(0xFF2563EB).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Color(0xFF1E1B4B),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '______',
                hintStyle: TextStyle(
                  letterSpacing: 14,
                  color: Colors.grey,
                  fontSize: 28,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _remainingSeconds > 0 ? Colors.grey[600] : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                _remainingSeconds > 0
                    ? 'Mã hết hạn sau ${_formatTime(_remainingSeconds)}'
                    : 'Mã đã hết hạn, vui lòng gửi lại!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _remainingSeconds > 0 ? Colors.grey[600] : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Nút xác thực
          ElevatedButton(
            onPressed: _isLoading ? null : _handleVerify,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Xác nhận đăng nhập',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  }
}
