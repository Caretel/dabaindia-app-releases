import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/leave_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveProvider>().fetchNotifications();
      context.read<LeaveProvider>().markNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<LeaveProvider>().notifications;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Alerts', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay updated with your status', 
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withOpacity(0.6)),
              ),
              
              const SizedBox(height: 32),
              
              if (notifications.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.primaryNavy.withOpacity(0.05)),
                        const SizedBox(height: 16),
                        Text('No alerts yet.', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5))),
                      ],
                    ),
                  ),
                )
              else
                ...notifications.map((notif) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded, 
                          size: 20, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.message, 
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.createdAt, 
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: AppTheme.errorRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                )),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
