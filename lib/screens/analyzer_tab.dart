import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/attendance_provider.dart';

class AnalyzerTab extends StatefulWidget {
  const AnalyzerTab({super.key});

  @override
  State<AnalyzerTab> createState() => _AnalyzerTabState();
}

class _AnalyzerTabState extends State<AnalyzerTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchData();
  }

  void _fetchData() {
    final monthStr = DateFormat('yyyy-MM').format(_focusedDay);
    context.read<AttendanceProvider>().fetchHistory(monthStr);
  }

  Future<void> _onRefresh() async {
    final monthStr = DateFormat('yyyy-MM').format(_focusedDay);
    await context.read<AttendanceProvider>().fetchHistory(monthStr);
  }

  // ── Status colour ──────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'Excellent': return const Color(0xFF4ADE80);
      case 'Good':      return const Color(0xFF60A5FA);
      case 'Moderate':  return const Color(0xFFFBBF24);
      case 'Low':       return const Color(0xFFF97316);
      default:          return const Color(0xFFEF4444); // Critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = context.watch<AttendanceProvider>();
    final ana = att.historyAnalytics;

    // Analytics values
    final daysPresent   = (ana['days_present']            ?? 0) as int;
    final targetDays    = (ana['adjusted_target_days']    ?? 0) as int;
    final totalHours    = ((ana['total_hours']            ?? 0) as num).toDouble();
    final targetHours   = ((ana['full_month_target_hours']?? 0) as num).toDouble();
    final dutyHrs       = ((ana['duty_hours']             ?? 8) as num).toDouble();
    final woLimit       = (ana['wo_limit']                ?? 0) as int;
    final holidayCount  = (ana['holiday_count']           ?? 0) as int;
    final absentDays    = (ana['absent_days']             ?? 0) as int;
    final leaveCount    = (ana['leave_count']             ?? 0) as int;
    final excessHours   = ((ana['excess_hours']           ?? 0) as num).toDouble();
    final perfStatus    = (ana['performance_status']      ?? '--') as String;

    final hoursProgress = targetHours > 0 ? (totalHours / targetHours).clamp(0.0, 1.0) : 0.0;
    final statusColor   = _statusColor(perfStatus);
    final isAhead       = excessHours >= 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryNavy,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Analytics',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                      Text('Dashboard-aligned performance',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // Performance badge
                if (perfStatus != '--')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(perfStatus,
                      style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Hours Progress Card ──────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withOpacity(0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primaryNavy.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMMM yyyy').format(_focusedDay),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Target: ${targetHours}h',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: hoursProgress,
                            minHeight: 9,
                            backgroundColor: Colors.white.withOpacity(0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isAhead ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${(hoursProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Excess / Deficit
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isAhead ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (isAhead ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)).withOpacity(0.4)),
                    ),
                    child: Text(
                      isAhead ? '+${excessHours}h Ahead of target' : '${excessHours.abs()}h Behind target',
                      style: TextStyle(
                        color: isAhead ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                        fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _statPill('Achieved', '${totalHours}h', const Color(0xFF4ADE80))),
                      Container(width: 1, height: 38, color: Colors.white24),
                      Expanded(child: _statPill('Target Days', '$targetDays d', Colors.white70)),
                      Container(width: 1, height: 38, color: Colors.white24),
                      Expanded(child: _statPill('Daily Duty', '${dutyHrs}h', const Color(0xFF93C5FD))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Days Breakdown Grid ──────────────────
            Row(
              children: [
                Expanded(child: _dayCard('Present',  '$daysPresent',   Colors.green,              Icons.check_circle_outline)),
                const SizedBox(width: 10),
                Expanded(child: _dayCard('Absent',   '$absentDays',    AppTheme.errorRed,          Icons.cancel_outlined)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dayCard('Week Off',  '$woLimit',      Colors.purple,             Icons.weekend_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _dayCard('Leave',     '$leaveCount',   Colors.orange,             Icons.event_available_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _dayCard('Holiday',   '$holidayCount', const Color(0xFF60A5FA),  Icons.celebration_outlined)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Calendar ────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primaryNavy.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _fetchData();
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: Color(0xFFEAF1FE), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: AppTheme.primaryNavy, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                  selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  defaultTextStyle: TextStyle(color: AppTheme.textMain),
                  weekendTextStyle: TextStyle(color: AppTheme.errorRed),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, _) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    final isPresent = att.history.any((r) => r.checkIn?.startsWith(dateStr) == true);
                    final isLeave   = att.leaves.contains(dateStr);
                    if (isPresent) {
                      return Positioned(bottom: 4, child: Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ));
                    }
                    if (isLeave) {
                      return Positioned(bottom: 4, child: Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      ));
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Daily Records ────────────────────────
            if (_selectedDay != null) ...[
              Text('Records for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
              const SizedBox(height: 12),
              _buildDailyRecords(_selectedDay!, att),
            ],
            const SizedBox(height: 40),
          ],
        ),
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _dayCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRecords(DateTime day, AttendanceProvider att) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final records = att.history.where((r) => r.checkIn?.startsWith(dateStr) == true).toList();
    final isLeave  = att.leaves.contains(dateStr);

    if (records.isEmpty && isLeave) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_available_outlined, color: Colors.orange),
            SizedBox(width: 12),
            Text('Approved Leave', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange)),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('No records for this day.',
            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5))),
        ),
      );
    }

    return Column(
      children: records.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PRESENT', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.checkIn?.split(' ').last.substring(0, 5) ?? '--:--',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, fontSize: 15)),
                const Text('Clock In', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.black12, size: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(r.checkOut?.split(' ').last.substring(0, 5) ?? '--:--',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, fontSize: 15)),
                const Text('Clock Out', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            if (r.duration != null) ...[
              const SizedBox(width: 10),
              Text(r.duration!.substring(0, 5),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      )).toList(),
    );
  }
}
