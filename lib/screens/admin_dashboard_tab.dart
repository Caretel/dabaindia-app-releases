import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import 'track_employee_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AdminProvider>();
      prov.fetchDashboardStats();
      prov.fetchAllEmployeesLocation();
    });
  }

  Future<void> _onRefresh() async {
    final prov = context.read<AdminProvider>();
    await Future.wait([
      prov.fetchDashboardStats(),
      prov.fetchAllEmployeesLocation(),
    ]);
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
    final user = context.watch<AuthProvider>().user;
    final adminProv = context.watch<AdminProvider>();
    final stats = adminProv.stats;

    // Filter employees
    final allEmployees = adminProv.employees;
    final filtered = _searchQuery.isEmpty
        ? allEmployees
        : allEmployees
            .where((e) =>
                e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.eid.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.shop ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final presentCount = allEmployees.where((e) => e.isCheckedIn).length;
    final trackableCount = allEmployees.where((e) => e.lastLat != null).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primaryNavy.withOpacity(0.1),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: AppTheme.primaryNavy, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Dashboard',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              Text(
                                'Welcome, ${user?.name ?? "Admin"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: AppTheme.textSecondary),
                          onPressed: () =>
                              context.read<AuthProvider>().logout(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats Cards
                    if (adminProv.isLoading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ))
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total Employees',
                                  '${stats['total_employees'] ?? 0}',
                                  AppTheme.primaryNavy,
                                  Icons.people_alt_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Present Today',
                                  '${stats['present_today'] ?? 0}',
                                  Colors.green,
                                  Icons.check_circle_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Absent Today',
                                  '${stats['absent_today'] ?? 0}',
                                  AppTheme.errorRed,
                                  Icons.cancel_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'On Leave',
                                  '${stats['on_leave_today'] ?? 0}',
                                  Colors.orange,
                                  Icons.event_busy_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                    const SizedBox(height: 28),

                    // Live Tracking Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Live Location Tracking',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const Spacer(),
                        if (!adminProv.isLoadingEmployees)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$presentCount active',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNavy.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search employee...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Employee List
            if (adminProv.isLoadingEmployees)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No employees found'
                            : 'No matches for "$_searchQuery"',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final emp = filtered[i];
                      return _buildEmployeeCard(emp, i);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeLocation emp, int index) {
    final hasLocation = emp.lastLat != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackEmployeeScreen(employee: emp),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emp.isCheckedIn
                ? Colors.green.withOpacity(0.25)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryNavy.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: emp.isCheckedIn
                      ? Colors.green.withOpacity(0.12)
                      : AppTheme.primaryNavy.withOpacity(0.08),
                  child: Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: emp.isCheckedIn ? Colors.green : AppTheme.primaryNavy,
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: emp.isCheckedIn ? Colors.green : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        emp.eid,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500),
                      ),
                      if (emp.shop != null) ...[
                        Text(' · ',
                            style:
                                TextStyle(color: Colors.grey.shade400)),
                        Flexible(
                          child: Text(
                            emp.shop!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(
                          _timeSince(emp.lastSeen),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Track Button
            if (hasLocation || emp.isCheckedIn)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: emp.isCheckedIn
                        ? [const Color(0xFF0D1F3C), const Color(0xFF1A3A6B)]
                        : [Colors.grey.shade400, Colors.grey.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      emp.isCheckedIn
                          ? Icons.gps_fixed_rounded
                          : Icons.history_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      emp.isCheckedIn ? 'Track' : 'History',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'No Data',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
