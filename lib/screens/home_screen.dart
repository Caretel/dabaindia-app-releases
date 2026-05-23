import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'analyzer_tab.dart';
import 'leave_tab.dart';
import 'notification_screen.dart';
import 'admin_dashboard_tab.dart';
import '../providers/leave_provider.dart';

import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().fetchStatus();
      context.read<LeaveProvider>().fetchNotifications();
      UpdateService().checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.role == 'Admin';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: [
          isAdmin ? const AdminDashboardTab() : const HomeTab(),
          const AnalyzerTab(),
          const LeaveTab(),
          const NotificationScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final unread = context.watch<LeaveProvider>().unreadNotifCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(index, 
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryNavy,
        unselectedItemColor: AppTheme.textSecondary.withOpacity(0.5),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          const BottomNavigationBarItem(icon: Icon(Icons.event_available_rounded), label: 'Leave'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(unread.toString()),
              isLabelVisible: unread > 0,
              backgroundColor: AppTheme.errorRed,
              child: const Icon(Icons.notifications_none_rounded),
            ), 
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _handleAttendance(BuildContext context, bool isCheckIn) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;
    
    if (isCheckIn) {
      await Permission.notification.request();
      if (await Permission.locationAlways.isDenied) {
        await Permission.locationAlways.request();
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (context.mounted) {
        final provider = context.read<AttendanceProvider>();
        final result = isCheckIn 
          ? await provider.checkIn(lat: position.latitude, lng: position.longitude, accuracy: position.accuracy)
          : await provider.checkOut(lat: position.latitude, lng: position.longitude, accuracy: position.accuracy);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['success'] ? result['message'] : result['error']),
              backgroundColor: result['success'] ? Colors.green : AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final att = context.watch<AttendanceProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Profile and Date
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryNavy.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppTheme.primaryNavy, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${user?.name ?? "User"}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      Text(
                        '${DateTime.now().day} ${_getMonth(DateTime.now().month)} ${DateTime.now().year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                  onPressed: () => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Attendance',
                    att.isCheckedIn ? 'Checked In' : 'Checked Out',
                    att.isCheckedIn ? Colors.green : Colors.orange,
                    Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Remaining Leaves',
                    '12 Days',
                    Colors.purple,
                    Icons.event_note_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildWorkingHoursCard(context, att),
            const SizedBox(height: 32),
            
            // Main Action: Clock In/Out
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    att.isCheckedIn ? 'Working Duration' : 'System Ready',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    att.isCheckedIn ? (att.lastCheckInTime ?? "00:00") : "00:00:00",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: att.isLoading ? null : () => _handleAttendance(context, !att.isCheckedIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: att.isCheckedIn ? AppTheme.errorRed : AppTheme.primaryNavy,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: att.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            att.isCheckedIn ? 'CLOCK OUT' : 'CLOCK IN',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Recent Activity
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityItem('Clocked In', '09:15 AM', 'Oct 24, 2023', Colors.green),
            _buildActivityItem('Clocked Out', '06:30 PM', 'Oct 23, 2023', Colors.orange),
            _buildActivityItem('Clocked In', '09:05 AM', 'Oct 23, 2023', Colors.green),
          ],
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildWorkingHoursCard(BuildContext context, AttendanceProvider att) {
    final target    = att.targetHours;
    final achieved  = att.achievedHours;
    final remaining = att.remainingHours;
    final progress  = target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0;
    final pct       = (progress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Working Hours — This Month',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
            ),
          ),
          const SizedBox(height: 20),
          // Three stats in a row
          Row(
            children: [
              Expanded(child: _buildHourStat('Target', '${target}h', Colors.white70)),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(child: _buildHourStat('Achieved', '${achieved}h', const Color(0xFF4ADE80))),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(child: _buildHourStat('Remaining', '${remaining}h', const Color(0xFFFBBF24))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, String date, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(date, style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryNavy)),
        ],
      ),
    );
  }
}
