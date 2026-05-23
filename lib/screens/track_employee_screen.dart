import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/admin_provider.dart';

class TrackEmployeeScreen extends StatefulWidget {
  final EmployeeLocation employee;
  const TrackEmployeeScreen({super.key, required this.employee});

  @override
  State<TrackEmployeeScreen> createState() => _TrackEmployeeScreenState();
}

class _TrackEmployeeScreenState extends State<TrackEmployeeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _data;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  int _selectedTab = 0; // 0 = timeline, 1 = map link

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await AdminProvider.fetchEmployeeLocationData(widget.employee.id);
      if (mounted) setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _openInMaps(double lat, double lng, String label) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTrailInMaps(List locations) async {
    if (locations.isEmpty) return;
    // Latest point
    final latest = locations.first;
    await _openInMaps(latest['lat'], latest['lng'], widget.employee.name);
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null) return '—';
    try {
      final dt = DateTime.parse(rawTime);
      return DateFormat('d MMM, h:mm a').format(dt);
    } catch (_) {
      return rawTime;
    }
  }

  String _timeSince(String? rawTime) {
    if (rawTime == null) return 'Never';
    try {
      final dt = DateTime.parse(rawTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final isCheckedIn = _data?['is_checked_in'] == true;
    final locations = (_data?['locations'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNavy.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.primaryNavy, size: 18),
          ),
        ),
        actions: [
          if (!_isLoading && locations.isNotEmpty)
            GestureDetector(
              onTap: () => _openTrailInMaps(locations),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Maps', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    // Employee Card
                    _buildEmployeeHeader(emp, isCheckedIn, locations),
                    const SizedBox(height: 24),

                    // Quick Stats Row
                    if (!_isLoading && !_hasError)
                      _buildQuickStats(isCheckedIn, locations),

                    const SizedBox(height: 24),

                    if (_isLoading)
                      _buildLoadingState()
                    else if (_hasError)
                      _buildErrorState()
                    else if (locations.isEmpty)
                      _buildEmptyState()
                    else
                      _buildLocationTrail(locations),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader(EmployeeLocation emp, bool isCheckedIn, List locations) {
    final lastSeen = _data != null && locations.isNotEmpty
        ? locations.first['time'] as String?
        : emp.lastSeen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCheckedIn
              ? [const Color(0xFF0D1F3C), const Color(0xFF1A3A6B)]
              : [const Color(0xFF374151), const Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isCheckedIn ? AppTheme.primaryNavy : Colors.grey).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with pulse
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  if (isCheckedIn)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isCheckedIn ? Colors.greenAccent : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            emp.eid,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (emp.shop != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              emp.shop!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCheckedIn ? Colors.greenAccent : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Text(
                  isCheckedIn ? '● LIVE' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isCheckedIn ? Colors.greenAccent : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          if (lastSeen != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isCheckedIn
                        ? 'Last ping: ${_timeSince(lastSeen)}'
                        : 'Last seen: ${_timeSince(lastSeen)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isCheckedIn, List locations) {
    final latest = locations.isNotEmpty ? locations.first : null;
    final checkInTime = _data?['check_in_time'] as String?;

    return Row(
      children: [
        Expanded(child: _buildStatChip(
          icon: Icons.location_history_rounded,
          label: 'Pings',
          value: '${locations.length}',
          color: AppTheme.primaryNavy,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatChip(
          icon: Icons.login_rounded,
          label: 'Checked In',
          value: isCheckedIn && checkInTime != null ? _timeOnly(checkInTime) : '—',
          color: isCheckedIn ? Colors.green : Colors.grey,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatChip(
          icon: Icons.my_location_rounded,
          label: 'Last Ping',
          value: latest != null ? _timeSince(latest['time']) : '—',
          color: Colors.deepPurple,
        )),
      ],
    );
  }

  String _timeOnly(String dateTime) {
    try {
      return DateFormat('h:mm a').format(DateTime.parse(dateTime));
    } catch (_) {
      return dateTime;
    }
  }

  Widget _buildStatChip({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLocationTrail(List locations) {
    final latest = locations.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Open Latest in Maps Banner
        GestureDetector(
          onTap: () => _openInMaps(latest['lat'], latest['lng'], widget.employee.name),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF0D9E7E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4285F4).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.place_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open Latest Location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${latest['lat'].toStringAsFixed(5)}, ${latest['lng'].toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            const Text(
              'Location Trail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const Spacer(),
            Text(
              '${locations.length} pings',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Timeline
        ...locations.asMap().entries.map((entry) {
          final i = entry.key;
          final loc = entry.value;
          final isFirst = i == 0;
          final isLast = i == locations.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Line + Dot
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      if (!isFirst)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.primaryNavy.withOpacity(0.15),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isFirst ? Colors.greenAccent.shade700 : AppTheme.primaryNavy.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? Colors.greenAccent : AppTheme.primaryNavy.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.primaryNavy.withOpacity(0.15),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Location Card
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openInMaps(loc['lat'], loc['lng'], widget.employee.name),
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: isLast ? 0 : 8,
                        top: isFirst ? 0 : 0,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isFirst
                            ? AppTheme.primaryNavy.withOpacity(0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFirst
                              ? AppTheme.primaryNavy.withOpacity(0.15)
                              : Colors.transparent,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNavy.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isFirst)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'LATEST',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      _formatTime(loc['time']),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                                        color: isFirst ? AppTheme.primaryNavy : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(loc['lat'] as double).toStringAsFixed(6)}, ${(loc['lng'] as double).toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: <Widget>[
        ...List.generate(1, (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Failed to load location data'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Location Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'No location pings found for this employee.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
