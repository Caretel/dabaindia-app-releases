import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/leave_provider.dart';
import '../widgets/status_badge.dart';

class LeaveTab extends StatefulWidget {
  const LeaveTab({super.key});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveProvider>().fetchMyRequests();
      context.read<LeaveProvider>().fetchPendingApprovals();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leave Management', 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                  Text('Request time off or approve peers', 
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorColor: AppTheme.primaryNavy,
              labelColor: AppTheme.primaryNavy,
              unselectedLabelColor: AppTheme.textSecondary.withOpacity(0.5),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Request'),
                Tab(text: 'Approvals'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const RequestLeaveView(),
                  const PeerApprovalsView(),
                  const MyRequestsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestLeaveView extends StatefulWidget {
  const RequestLeaveView({super.key});

  @override
  State<RequestLeaveView> createState() => _RequestLeaveViewState();
}

class _RequestLeaveViewState extends State<RequestLeaveView> {
  String _selectedType = 'Sick';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _noteController = TextEditingController();

  final List<String> _leaveTypes = ['Swap', 'Sick', 'Casual', 'Paid', 'Other'];

  Future<void> _submit() async {
    final provider = context.read<LeaveProvider>();
    final result = await provider.submitRequest(
      type: _selectedType,
      date: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: _selectedType == 'Swap' ? null : DateFormat('yyyy-MM-dd').format(_endDate),
      note: _noteController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] ? result['message'] : result['error']),
          backgroundColor: result['success'] ? Colors.green : AppTheme.errorRed,
        ),
      );
      if (result['success']) {
        _noteController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Leave Type'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                dropdownColor: Colors.white,
                items: _leaveTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(color: AppTheme.textMain)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(_selectedType == 'Swap' ? 'Swap Date' : 'From Date'),
                    _buildDatePicker(_startDate, (d) => setState(() => _startDate = d)),
                  ],
                ),
              ),
              if (_selectedType != 'Swap') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('To Date'),
                      _buildDatePicker(_endDate, (d) => setState(() => _endDate = d)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          _buildLabel('Reason / Note'),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter reason for leave...',
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryNavy.withOpacity(0.1)),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          Consumer<LeaveProvider>(
            builder: (context, lp, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: lp.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: lp.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SUBMIT REQUEST', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(text, style: TextStyle(color: AppTheme.primaryNavy.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDatePicker(DateTime date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (d != null) onSelect(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM, yyyy').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryNavy),
          ],
        ),
      ),
    );
  }
}

class PeerApprovalsView extends StatelessWidget {
  const PeerApprovalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<LeaveProvider>().pendingApprovals;

    if (pending.isEmpty) {
      return Center(
        child: Text('No pending peer approvals.', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final req = pending[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primaryNavy.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req.requesterName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryNavy)),
                    Text(req.startDate ?? '', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.6))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Wants to swap off day to ${req.startDate}', style: const TextStyle(fontSize: 14)),
                if (req.note != null && req.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('"${req.note}"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.read<LeaveProvider>().respondToRequest(req.id, 'rejected'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.errorRed),
                          foregroundColor: AppTheme.errorRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.read<LeaveProvider>().respondToRequest(req.id, 'approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, 
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MyRequestsView extends StatelessWidget {
  const MyRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<LeaveProvider>().myRequests;

    if (requests.isEmpty) {
      return Center(
        child: Text('You haven\'t made any requests yet.', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primaryNavy.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req.leaveType, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, fontSize: 16)),
                    StatusBadge(status: req.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      req.endDate != null && req.endDate != req.startDate
                        ? '${req.startDate} to ${req.endDate}'
                        : '${req.startDate}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (req.note != null && req.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(req.note!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.8))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
