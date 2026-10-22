import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class ChildLocationScreen extends StatefulWidget {
  final int treEmId;
  final String tenBe;
  final String tenThietBi;

  const ChildLocationScreen({
    super.key,
    required this.treEmId,
    required this.tenBe,
    required this.tenThietBi,
  });

  @override
  State<ChildLocationScreen> createState() => _ChildLocationScreenState();
}

class _ChildLocationScreenState extends State<ChildLocationScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;

  String _currentCoordinates = '10.762622, 106.660172';
  String _currentAddress = '280 An Dương Vương, Phường 4, Quận 5, TP. Hồ Chí Minh';
  int _batteryPercent = 85;
  String _safetyStatus = 'Trong Vùng An Toàn (Trường Học)';
  bool _isInSafeZone = true;
  String _lastUpdate = 'Vừa xong';

  List<Map<String, dynamic>> _locationHistory = [];
  late AnimationController _pulseController;
  final MapController _mapController = MapController();
  double _currentZoom = 16.5;
  int _mapLayerType = 0; // 0: Google Street, 1: Google Satellite, 2: OpenStreetMap
  bool _isExpandedMap = false;

  LatLng _getLatLng(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (_) {}
    return const LatLng(10.762622, 106.660172);
  }

  List<LatLng> _getRoutePoints() {
    final points = <LatLng>[];
    for (final item in _locationHistory.reversed) {
      final pos = item['viTriHienTai'] ?? item['toaDo'];
      if (pos != null) {
        points.add(_getLatLng(pos.toString()));
      }
    }
    final cur = _getLatLng(_currentCoordinates);
    if (points.isEmpty || points.last != cur) {
      points.add(cur);
    }
    return points;
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(4.0, 19.0);
      _mapController.move(_getLatLng(_currentCoordinates), _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(4.0, 19.0);
      _mapController.move(_getLatLng(_currentCoordinates), _currentZoom);
    });
  }

  void _recenter() {
    final target = _getLatLng(_currentCoordinates);
    _mapController.move(target, _currentZoom);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetchLocationData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationData() async {
    setState(() => _isLoading = true);
    final history = await _apiService.getLocationHistory(widget.treEmId);

    if (!mounted) return;

    if (history.isNotEmpty) {
      final latest = history.first;
      setState(() {
        _currentCoordinates = latest['viTriHienTai'] ?? '10.762622, 106.660172';
        _batteryPercent = latest['mucPin'] ?? 85;
        _safetyStatus = latest['canhBao'] ?? 'Trong Vùng An Toàn';
        _isInSafeZone = !_safetyStatus.toLowerCase().contains('vượt') && !_safetyStatus.toLowerCase().contains('nguy');
        _lastUpdate = latest['gioGhi'] ?? (latest['ngayGhi'] != null ? 'Hôm nay' : 'Vừa xong');
        _locationHistory = history;
      });
    } else {
      final logs = await _apiService.getDeviceLogs(widget.treEmId);
      if (logs.isNotEmpty) {
        final latest = logs.first;
        setState(() {
          _currentCoordinates = latest['viTriHienTai'] ?? '10.762622, 106.660172';
          _batteryPercent = latest['mucPin'] ?? 85;
          _safetyStatus = latest['canhBao'] ?? 'Trong Vùng An Toàn';
          _isInSafeZone = !_safetyStatus.toLowerCase().contains('vượt') && !_safetyStatus.toLowerCase().contains('nguy');
          _lastUpdate = latest['ngayGhi'] != null ? 'Hôm nay' : 'Vừa xong';
          _locationHistory = logs;
        });
      }
    }

    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recenter();
    });
  }

  // Lấy tọa độ GPS thực tế từ chip định vị của thiết bị
  Future<Position?> _getRealDeviceGPS({bool showDialogIfDisabled = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showDialogIfDisabled && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text('Chưa Bật Định Vị GPS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Điện thoại của bạn đang tắt Dịch vụ Vị trí (GPS).\n\nVui lòng gạt BẬT "Vị trí" trong cài đặt để ứng dụng xác định đúng vị trí chỗ bạn đang ở!',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bỏ qua')),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openLocationSettings();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Bật Vị Trí Ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vui lòng cấp quyền vị trí để ứng dụng định vị đúng chỗ bạn đang ở!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Cần Quyền Vị Trí'),
              content: const Text('Quyền vị trí đã bị chặn. Vui lòng mở Cài đặt ứng dụng để cho phép truy cập vị trí!'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  child: const Text('Mở Cài Đặt'),
                ),
              ],
            ),
          );
        }
        return null;
      }

      // Lấy vị trí GPS chính xác cao nhất
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // Cập nhật vị trí GPS mới (lấy từ GPS thực tế hoặc vị trí chọn)
  Future<void> _refreshGPSLocation({String? manualCoords, String? manualAddress}) async {
    setState(() => _isRefreshing = true);

    String newCoords = manualCoords ?? _currentCoordinates;
    String newAddress = manualAddress ?? _currentAddress;
    bool isFromHardwareGPS = false;

    if (manualCoords == null) {
      // Thử lấy vị trí GPS thực tế từ chip định vị thiết bị
      final pos = await _getRealDeviceGPS();
      if (pos != null) {
        newCoords = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        newAddress = 'Vị trí GPS thực tế của bạn (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
        isFromHardwareGPS = true;
      } else {
        setState(() => _isRefreshing = false);
        return;
      }
    }

    // Gửi ping vị trí mới lên server
    await _apiService.sendLocationPing(
      treEmId: widget.treEmId,
      viTriHienTai: newCoords,
      mucPin: _batteryPercent,
      canhBao: 'Trong vùng an toàn',
    );

    await _fetchLocationData();

    if (!mounted) return;
    setState(() {
      _currentCoordinates = newCoords;
      _currentAddress = newAddress;
      _isRefreshing = false;
      _currentZoom = 17.0; // Phóng to chi tiết đường phố chỗ bạn đang ở
    });

    _recenter();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFromHardwareGPS
                    ? 'Đã ghim đúng vị trí thực tế của bạn: $newCoords!'
                    : 'Đã cập nhật vị trí GPS thành công: $newCoords!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Hộp thoại chọn địa điểm thực tế nhanh để kiểm tra bản đồ
  void _showLocationPickerSheet() {
    final sampleLocations = [
      {'name': '🎯 Vị trí GPS thật của máy hiện tại', 'coords': 'REAL_GPS', 'address': 'Định vị từ chip GPS điện thoại'},
      {'name': '🏫 ĐH Sài Gòn (280 An Dương Vương, Q.5)', 'coords': '10.762622, 106.660172', 'address': '280 An Dương Vương, Phường 4, Quận 5, TP.HCM'},
      {'name': '🏙️ Landmark 81 (Vinhomes Central Park)', 'coords': '10.795150, 106.721860', 'address': '720A Điện Biên Phủ, Phường 22, Bình Thạnh, TP.HCM'},
      {'name': '🚶 Phố đi bộ Nguyễn Huệ (Quận 1)', 'coords': '10.774260, 106.703750', 'address': 'Đường Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM'},
      {'name': '🌳 Thảo Cầm Viên Sài Gòn (Quận 1)', 'coords': '10.787620, 106.705290', 'address': '2 Nguyễn Bỉnh Khiêm, Bến Nghé, Quận 1, TP.HCM'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.place_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Chọn Vị Trí Thực Tế Cho Bé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Chọn vị trí để kiểm tra định vị và xem bản đồ cập nhật ngay lập tức:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            ...sampleLocations.map((loc) {
              final isReal = loc['coords'] == 'REAL_GPS';
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isReal ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF2563EB).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isReal ? Icons.gps_fixed_rounded : Icons.location_on_rounded, color: isReal ? const Color(0xFF059669) : const Color(0xFF2563EB), size: 20),
                ),
                title: Text(loc['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isReal ? const Color(0xFF059669) : const Color(0xFF0F172A))),
                subtitle: Text(loc['address']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isReal) {
                    _refreshGPSLocation();
                  } else {
                    _refreshGPSLocation(manualCoords: loc['coords'], manualAddress: loc['address']);
                  }
                },
              );
            }),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              title: const Text('Nhập tọa độ chỗ bạn ở tùy ý', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED))),
              subtitle: const Text('Nhập vĩ độ, kinh độ hoặc địa chỉ nhà bạn', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomCoordinatesDialog();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Hộp thoại nhập tọa độ tùy ý
  void _showCustomCoordinatesDialog() {
    final coordController = TextEditingController(text: _currentCoordinates);
    final addressController = TextEditingController(text: _currentAddress);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_location_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Nhập Vị Trí Chỗ Bạn Ở', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập tọa độ GPS (Vĩ độ, Kinh độ):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: coordController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '10.762622, 106.660172',
                prefixIcon: const Icon(Icons.pin_drop_rounded),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Tên địa chỉ hiển thị:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Nhà riêng của tôi',
                prefixIcon: const Icon(Icons.home_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _refreshGPSLocation(
                manualCoords: coordController.text.trim(),
                manualAddress: addressController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Định Vị Ngay'),
          ),
        ],
      ),
    );
  }

  // Phát chuông tìm điện thoại của bé
  void _ringPhone() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.ring_volume_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Phát Chuông Tìm Máy'),
          ],
        ),
        content: Text(
          'Đang gửi tín hiệu phát chuông lớn đến điện thoại "${widget.tenThietBi}" của ${widget.tenBe}. Chuông sẽ đổ ở mức âm lượng cao nhất trong 1 phút.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Định Vị: ${widget.tenBe}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            tooltip: 'Làm mới vị trí',
            onPressed: _isRefreshing ? null : _refreshGPSLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bản đồ GPS Trực Quan & Tương Tác Thực
                  _buildModernInteractiveMap(),

                  const SizedBox(height: 20),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isInSafeZone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isInSafeZone ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                                color: _isInSafeZone ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _safetyStatus,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _isInSafeZone ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cập nhật: $_lastUpdate',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Address & Coordinates
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place_rounded, color: Color(0xFF2563EB), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentAddress,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tọa độ GPS: $_currentCoordinates',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Telemetries row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTelemetryItem(
                              icon: Icons.battery_charging_full_rounded,
                              color: const Color(0xFF10B981),
                              label: 'Mức Pin',
                              value: '$_batteryPercent%',
                            ),
                            _buildTelemetryItem(
                              icon: Icons.speed_rounded,
                              color: const Color(0xFF2563EB),
                              label: 'Tốc độ',
                              value: '0 km/h (Dừng)',
                            ),
                            _buildTelemetryItem(
                              icon: Icons.wifi_rounded,
                              color: const Color(0xFF8B5CF6),
                              label: 'Mạng',
                              value: '4G / Wi-Fi',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _ringPhone,
                          icon: const Icon(Icons.ring_volume_rounded, size: 17),
                          label: const Text('Tìm Máy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _refreshGPSLocation(),
                          icon: const Icon(Icons.gps_fixed_rounded, size: 17),
                          label: const Text('GPS Thực Tế', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showLocationPickerSheet,
                        icon: const Icon(Icons.add_location_alt_rounded, size: 17),
                        label: const Text('Đổi Điểm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Location History Timeline
                  const Text(
                    'Lịch sử di chuyển gần đây',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  _locationHistory.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Chưa có thêm điểm lịch sử nào ghi nhận hôm nay.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _locationHistory.length > 5 ? 5 : _locationHistory.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = _locationHistory[index];
                            final pos = log['viTriHienTai'] ?? '10.762622, 106.660172';
                            final app = log['ungDung'] ?? 'Hệ thống';
                            final bat = log['mucPin'] ?? 85;
                            final time = log['gioGhi'] ?? (log['ngayGhi'] != null ? 'Hôm nay' : 'Vừa xong');
                            final canhBao = log['canhBao'] ?? '';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Tọa độ: $pos',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '$time',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ứng dụng: $app • Pin: $bat%${canhBao.isNotEmpty ? " • $canhBao" : ""}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
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

  Widget _buildModernInteractiveMap() {
    final childPos = _getLatLng(_currentCoordinates);
    final routePoints = _getRoutePoints();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpandedMap ? 380 : 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Bản đồ tương tác thực tế với Tile Layer (Đường phố / Vệ tinh tối)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: childPos,
                initialZoom: _currentZoom,
                minZoom: 4,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapLayerType == 0
                      ? 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'
                      : _mapLayerType == 1
                          ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tranminhcuong.nhomhhcc',
                  maxZoom: 20,
                ),
                // Vùng an toàn 120m (Safe Zone)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: childPos,
                      radius: 120,
                      useRadiusInMeter: true,
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderColor: const Color(0xFF059669),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                // Lộ trình di chuyển nối các điểm
                if (routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color(0xFF2563EB),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                // Các điểm mốc và Vị trí của bé
                MarkerLayer(
                  markers: [
                    for (int i = 0; i < routePoints.length - 1; i++)
                      Marker(
                        point: routePoints[i],
                        width: 14,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Marker thời gian thực của bé
                    Marker(
                      point: childPos,
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      child: _buildChildMapPin(),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Huy hiệu trạng thái GPS Trực Tuyến góc trên bên trái
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.8 - (_pulseController.value * 0.4)),
                              blurRadius: 4 + (_pulseController.value * 6),
                              spreadRadius: _pulseController.value * 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'GPS Trực Tuyến',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Nút đổi chế độ bản đồ & phóng to toàn màn hình góc trên bên phải
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => setState(() => _mapLayerType = (_mapLayerType + 1) % 3),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              _mapLayerType == 0
                                  ? Icons.map_rounded
                                  : _mapLayerType == 1
                                      ? Icons.satellite_alt_rounded
                                      : Icons.public_rounded,
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _mapLayerType == 0
                                  ? 'Bản đồ Google'
                                  : _mapLayerType == 1
                                      ? 'Google Vệ tinh'
                                      : 'OpenStreetMap',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => setState(() => _isExpandedMap = !_isExpandedMap),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          _isExpandedMap ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          size: 18,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Các nút điều khiển thu phóng & định tâm góc dưới bên phải
            Positioned(
              bottom: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapCircleButton(
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFF2563EB),
                    tooltip: 'Đến vị trí của bé',
                    onTap: _recenter,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 20),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          tooltip: 'Phóng to',
                          onPressed: _zoomIn,
                        ),
                        const Divider(height: 1, thickness: 1),
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          tooltip: 'Thu nhỏ',
                          onPressed: _zoomOut,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 5. Thẻ hiển thị vùng an toàn góc dưới bên trái
            Positioned(
              bottom: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Vùng an toàn 120m',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildMapPin() {
    final staticAvatar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF2563EB),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              widget.tenBe.isNotEmpty ? widget.tenBe[0].toUpperCase() : 'B',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.tenBe,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _pulseController,
      child: staticAvatar,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Vòng sóng radar lan tỏa
            Container(
              width: 36 + (_pulseController.value * 36),
              height: 36 + (_pulseController.value * 36),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(
                  alpha: (1.0 - _pulseController.value) * 0.35,
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }

  Widget _buildMapCircleButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
