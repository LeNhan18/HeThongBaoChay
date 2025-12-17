import 'dart:async';
import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class DebugPollingInfo extends StatefulWidget {
  const DebugPollingInfo({super.key});

  @override
  State<DebugPollingInfo> createState() => _DebugPollingInfoState();
}

class _DebugPollingInfoState extends State<DebugPollingInfo> {
  Timer? _refreshTimer;
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _updateStatus();
    _refreshTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => _updateStatus(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _updateStatus() {
    if (mounted) {
      setState(() {
        _status = AlertService().getPollingStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 Debug: Alert Polling Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('Polling Active: ${_status['isPolling'] ?? 'Unknown'}'),
            Text('Fetching Now: ${_status['isFetching'] ?? 'Unknown'}'),
            Text('Timer Active: ${_status['timerActive'] ?? 'Unknown'}'),
            Text(
              'Processed Alerts: ${_status['processedAlertCount'] ?? 'Unknown'}',
            ),
            if (_status['lastFetchTime'] != null)
              Text('Last Fetch: ${_formatTime(_status['lastFetchTime'])}'),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => AlertService().startLiveAlertPolling(),
                  child: Text('Start'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => AlertService().stopLiveAlertPolling(),
                  child: Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return 'Never';
    try {
      final time = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(time).inSeconds;
      return '${diff}s ago';
    } catch (e) {
      return 'Invalid';
    }
  }
}
