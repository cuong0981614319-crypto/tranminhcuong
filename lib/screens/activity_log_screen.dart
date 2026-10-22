import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_sync_helper.dart';

class ActivityLogScreen extends StatefulWidget {
  final int treEmId;
  final String tenBe;
  final String? tenThietBi;

  const ActivityLogScreen({
    super.key,
    required this.treEmId,
    required this.tenBe,
    this.tenThietBi,
  });

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _logs = [];

  String _deviceName = 'Điện thoại OPPO (Android)';
  int _battery = 88;
  String _lastSyncTime = 'Vừa xong';

  @override
  void initState() {
    super.initState();
    if (widget.tenThietBi != null && widget.tenThietBi!.isNotEmpty) {
      _deviceName = widget.tenThietBi!;
    }
    _initDeviceAndFetchLogs();
  }

  Future<void> _initDeviceAndFetchLogs() async {
    // Phát hiện tên máy OPPO/Android thực tế của điện thoại
    final actualName = await DeviceSyncHelper.getActualDeviceName();
    final actualBat = await DeviceSyncHelper.getActualBattery();

    if (!mounted) return;
    setState(() {
      if (widget.tenThietBi == null ||
          widget.tenThietBi!.isEmpty ||
          widget.tenThietBi!.toLowerCase().contains('samsung')) {
        _deviceName = actualName;
      }
      _battery = actualBat;
    });

    _fetchLogs();
  }

  Future<void> _fetchLogs({bool autoSync = true}) async {
    setState(() => _isLoading = true);
    var list = await _apiService.getDeviceLogs(widget.treEmId);

    // Nếu chưa có nhật ký nào, tự động đồng bộ ngay từ máy của bé
    if (list.isEmpty && autoSync) {
      final actualPos = await DeviceSyncHelper.getActualLocation();
      await _apiService.syncAndroidActivity(
        treEmId: widget.treEmId,
        tenThietBi: _deviceName,
        mucPin: _battery,
        viTriHienTai: actualPos,
      );
      list = await _apiService.getDeviceLogs(widget.treEmId);
    }

    if (!mounted) return;
    setState(() {
      _logs = list;
      if (list.isNotEmpty) {
        _battery = list.first['mucPin'] ?? _battery;
        final savedName = list.first['tenThietBi'];
        if (savedName != null && savedName.toString().isNotEmpty) {
          _deviceName = savedName.toString();
        }
        _lastSyncTime = 'Vừa đồng bộ';
      }
      _isLoading = false;
    });
  }

  // Đồng bộ hoạt động từ thiết bị OPPO / Android của bé
  Future<void> _handleSyncFromAndroid() async {
    setState(() => _isSyncing = true);

    // Lấy thông tin phần cứng thực tế của máy (OPPO, Pin %, Tọa độ GPS)
    final actualName = await DeviceSyncHelper.getActualDeviceName();
    final actualBat = await DeviceSyncHelper.getActualBattery();
    final actualPos = await DeviceSyncHelper.getActualLocation();

    final res = await _apiService.syncAndroidActivity(
      treEmId: widget.treEmId,
      tenThietBi: actualName,
      mucPin: actualBat,
      viTriHienTai: actualPos,
    );

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _deviceName = actualName;
      _battery = actualBat;
      _lastSyncTime = 'Vừa cập nhật';
    });

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Đã đồng bộ hoạt động từ $actualName thành công!')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchLogs(autoSync: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Lỗi khi đồng bộ!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Nhật Ký: ${widget.tenBe}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            tooltip: 'Đồng bộ từ máy Android',
            onPressed: _isSyncing ? null : _handleSyncFromAndroid,
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _fetchLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Android Live Sync Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3DDC84).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 28),
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
                                          _deviceName,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Live Sync', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Đồng bộ: $_lastSyncTime • Pin: $_battery%',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 12),

                        // Action button inside card
                        ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _handleSyncFromAndroid,
                          icon: _isSyncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync_alt_rounded, size: 18),
                          label: Text(
                            _isSyncing ? 'Đang đồng bộ dữ liệu...' : 'ĐỒNG BỘ TỪ MÁY ANDROID NGAY',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App summary card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, color: Color(0xFF2563EB), size: 22),
                            SizedBox(width: 8),
                            Text('Ứng Dụng Sử Dụng Nhiều Hôm Nay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAppUsageRow('YouTube Kids', 40, 120, Colors.redAccent, 'Quá 30 phút'),
                        const SizedBox(height: 12),
                        _buildAppUsageRow('Roblox', 25, 120, Colors.orangeAccent, 'Bình thường'),
                        const SizedBox(height: 12),
                        _buildAppUsageRow('Duolingo (Học tiếng Anh)', 20, 120, const Color(0xFF10B981), 'Học tập tốt'),
                        const SizedBox(height: 12),
                        _buildAppUsageRow('TikTok', 15, 120, Colors.deepPurpleAccent, 'Cảnh báo nội dung'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chi tiết các phiên hoạt động',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${_logs.length} lượt ghi',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _logs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Chưa có nhật ký hoạt động nào.\nNhấn nút "ĐỒNG BỘ TỪ MÁY ANDROID NGAY" ở trên để nạp dữ liệu!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final app = log['ungDung'] ?? 'Ứng dụng';
                            final duration = log['thoiGianDungPhut'] ?? 15;
                            final battery = log['mucPin'] ?? 85;
                            final warning = log['canhBao'] ?? 'Bình thường';
                            final pos = log['viTriHienTai'] ?? '10.762622, 106.660172';

                            final isWarning = warning.toString().toLowerCase().contains('quá') ||
                                warning.toString().toLowerCase().contains('cảnh báo');

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isWarning ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isWarning
                                          ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                                          : const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isWarning ? Icons.warning_amber_rounded : Icons.phone_iphone_rounded,
                                      color: isWarning ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(app, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('Thời gian: $duration phút • Pin: $battery%', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text('Tọa độ: $pos', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isWarning ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isWarning ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
                                      ),
                                    ),
                                    child: Text(
                                      warning,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isWarning ? const Color(0xFFC2410C) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppUsageRow(String appName, int minutes, int totalLimit, Color color, String badge) {
    final double percent = (minutes / totalLimit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(appName, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text('$minutes phút', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            color: color,
          ),
        ),
      ],
    );
  }
}
