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

  @override
  Widget build(BuildContext context) {
    final att = context.watch<AttendanceProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your monthly performance',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            
            // Performance Summary Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Days Worked', '${att.history.length}', Icons.work_outline),
                      _buildSummaryItem('Late', '2', Icons.timer_outlined),
                      _buildSummaryItem('Early', '1', Icons.login_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Calendar Section
            Container(
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
              child: TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
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
                  markerBuilder: (context, day, events) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    final isPresent = att.history.any((r) => r.checkIn != null && r.checkIn!.startsWith(dateStr));
                    if (isPresent) {
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Selection Detail
            if (_selectedDay != null) ...[
              Text(
                'Records for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 16),
              _buildDailyRecords(_selectedDay!, att),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildDailyRecords(DateTime day, AttendanceProvider att) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final records = att.history.where((r) => r.checkIn != null && r.checkIn!.startsWith(dateStr)).toList();

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No attendance records found.',
            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
          ),
        ),
      );
    }

    return Column(
      children: records.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PRESENT', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.checkIn?.split(' ')[1] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                  const Text('Clock In', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.black12, size: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(r.checkOut?.split(' ')[1] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                  const Text('Clock Out', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
