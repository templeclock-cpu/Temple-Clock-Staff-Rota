// lib/screens/staff/clock_in_screen.dart
//
// Phase 3: Camera clock-in / clock-out screen.
// Accepts the current RotaShift + a flag (isClockIn).
// On success, pops with the resulting AttendanceRecord.

import "dart:async";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "package:geolocator/geolocator.dart";

import "../../models/rota_model.dart";
import "../../models/attendance_model.dart";
import "../../services/attendance_service.dart";
import "../../widgets/shared_widgets.dart";

class ClockInScreen extends StatefulWidget {
  final RotaShift shift;
  final bool isClockIn;
  final String staffId;
  final String staffName;

  const ClockInScreen({
    super.key,
    required this.shift,
    required this.isClockIn,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  static const Color _navy = Color(0xFF1A2B4A);
  static const Color _teal = Color(0xFF00BFA5);

  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  XFile? _capturedPhoto;
  Uint8List? _photoBytes; // cross-platform photo bytes
  bool _isLoading = false;
  bool _photoSkipped = false;

  // ── Location state ────────────────────────────────────────────────────────
  Position? _currentPosition;
  bool _locationLoading = true;
  String? _locationError;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _fetchLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ─── Geolocation ─────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _locationError = "Location services are disabled. Please enable them.";
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationLoading = false;
              _locationError = "Location permission denied.";
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _locationError = "Location permission permanently denied.";
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _locationError = "Could not get location: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e}";
        });
      }
    }
  }

  // ─── Grace helpers ───────────────────────────────────────────────────────────

  int get _diffMinutes {
    if (widget.isClockIn) {
      return _now.difference(widget.shift.startTime).inMinutes;
    }
    return _now.difference(widget.shift.endTime).inMinutes;
  }

  String get _graceLabel {
    final diff = _diffMinutes;
    if (widget.isClockIn) {
      if (diff < -60) return "Very early";
      if (diff < 0) return (-diff).toString() + " min early";
      if (diff <= AttendanceService.gracePeriodMinutes) {
        return "On time (within " + AttendanceService.gracePeriodMinutes.toString() + " min grace)";
      }
      return diff.toString() + " min LATE";
    } else {
      if (diff < 0) return (-diff).toString() + " min before end";
      if (diff <= AttendanceService.gracePeriodMinutes) return "On time";
      return diff.toString() + " min overtime";
    }
  }

  Color get _graceColor {
    final diff = _diffMinutes;
    if (diff <= AttendanceService.gracePeriodMinutes) return _teal;
    return Colors.orange;
  }

  // ─── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    try {
      XFile? photo;
      try {
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
          preferredCameraDevice: CameraDevice.front,
        );
      } catch (_) {
        // Camera not available (common on web) — fall back to gallery
        photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
      }

      if (photo != null && mounted) {
        try {
          final bytes = await photo.readAsBytes();
          if (bytes.length < 4) throw Exception("Invalid image");
          setState(() {
            _capturedPhoto = photo;
            _photoBytes = bytes;
            _photoSkipped = false;
          });
        } catch (_) {
          if (mounted) {
            showAppSnackBar(
              context,
              "Invalid image format. Please select a JPG or PNG file.",
              isError: true,
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          "Camera unavailable — you can continue without a photo.",
          isError: true,
        );
        setState(() => _photoSkipped = true);
      }
    }
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_capturedPhoto == null && !_photoSkipped) {
      showAppSnackBar(
        context,
        "Please take a photo or tap Skip Photo.",
        isError: true,
      );
      return;
    }

    if (_locationLoading) {
      showAppSnackBar(
        context,
        "Waiting for location... Please wait.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);
      AttendanceRecord record;

      final lat = _currentPosition?.latitude;
      final lng = _currentPosition?.longitude;
      
      if (widget.isClockIn) {
        record = await attendanceService.clockIn(
          shiftId: widget.shift.id,
          latitude: lat,
          longitude: lng,
          photoPath: _capturedPhoto?.path,
        );
      } else {
        record = await attendanceService.clockOut(
          shiftId: widget.shift.id,
          latitude: lat,
          longitude: lng,
          photoPath: _capturedPhoto?.path,
        );
      }
      if (mounted) Navigator.of(context).pop(record);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppSnackBar(
          context,
          e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Text(
          widget.isClockIn ? "Clock In" : "Clock Out",
          style: const TextStyle(
            fontFamily: "Outfit",
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCurrentTimeCard(),
              const SizedBox(height: 14),
              _buildShiftCard(),
              const SizedBox(height: 14),
              _buildGraceCard(),
              const SizedBox(height: 14),
              _buildLocationCard(),
              const SizedBox(height: 14),
              _buildPhotoCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 8),
              if (_capturedPhoto == null && !_photoSkipped)
                TextButton(
                  onPressed: () => setState(() => _photoSkipped = true),
                  child: const Text(
                    "Skip Photo",
                    style: TextStyle(
                      fontFamily: "Outfit",
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeCard() {
    final tf = DateFormat("HH:mm:ss");
    final df = DateFormat("EEEE, d MMM yyyy");
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tf.format(_now),
            style: const TextStyle(
              fontFamily: "Outfit",
              fontSize: 46,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            df.format(_now),
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard() {
    final sf = DateFormat("HH:mm");
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.work_outline, color: _teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.shift.role,
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    Text(
                      (widget.shift.departmentName == null ||
                              widget.shift.departmentName!.isEmpty)
                          ? 'General'
                          : widget.shift.departmentName!,
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: _shiftStat(
                  "Start",
                  sf.format(widget.shift.startTime),
                  Icons.login,
                ),
              ),
              Expanded(
                child: _shiftStat(
                  "End",
                  sf.format(widget.shift.endTime),
                  Icons.logout,
                ),
              ),
              Expanded(
                child: _shiftStat(
                  "Hours",
                  widget.shift.scheduledHours.toStringAsFixed(1) + "h",
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shiftStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildGraceCard() {
    final color = _graceColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            color == _teal
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _graceLabel,
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  "Grace period: " + AttendanceService.gracePeriodMinutes.toString() + " minutes",
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 11,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? coordsText;

    if (_locationLoading) {
      statusColor = Colors.blue;
      statusIcon = Icons.my_location;
      statusText = "Fetching your location...";
    } else if (_locationError != null) {
      statusColor = Colors.orange;
      statusIcon = Icons.location_off;
      statusText = _locationError!;
    } else if (_currentPosition != null) {
      statusColor = _teal;
      statusIcon = Icons.location_on;
      statusText = "Location captured";
      coordsText =
          "${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}";
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.location_disabled;
      statusText = "Location unavailable";
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.share_location, color: _navy, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Geofence Location",
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_locationLoading)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: statusColor,
                        ),
                      )
                    else
                      Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _currentPosition != null
                          ? "Captured"
                          : _locationLoading
                              ? "Loading"
                              : "Error",
                      style: TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: "Outfit",
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                      if (coordsText != null)
                        Text(
                          coordsText,
                          style: TextStyle(
                            fontFamily: "Outfit",
                            fontSize: 11,
                            color: statusColor.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_locationError != null)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 18, color: statusColor),
                    onPressed: () {
                      setState(() {
                        _locationLoading = true;
                        _locationError = null;
                      });
                      _fetchLocation();
                    },
                    tooltip: "Retry",
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: _navy, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Identity Verification Photo",
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
              if (_photoSkipped)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Skipped",
                    style: TextStyle(
                      fontFamily: "Outfit",
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _photoBytes != null
                ? AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(
                      _photoBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF0F4F8),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  size: 40, color: Colors.red),
                              SizedBox(height: 6),
                              Text(
                                "Invalid image format",
                                style: TextStyle(
                                  fontFamily: "Outfit",
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 44,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "No photo captured",
                          style: TextStyle(
                            fontFamily: "Outfit",
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _capturePhoto,
              icon: Icon(
                _capturedPhoto != null ? Icons.refresh : Icons.camera_alt,
                size: 17,
              ),
              label: Text(
                _capturedPhoto != null ? "Retake Photo" : "Open Camera",
                style: const TextStyle(
                  fontFamily: "Outfit",
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: const BorderSide(color: _teal),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = !_isLoading;
    final color = widget.isClockIn ? _teal : Colors.redAccent;
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? _submit : null,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                widget.isClockIn ? Icons.login : Icons.logout,
                color: Colors.white,
                size: 20,
              ),
        label: Text(
          _isLoading
              ? "Processing..."
              : widget.isClockIn
                  ? "Confirm Clock In"
                  : "Confirm Clock Out",
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
