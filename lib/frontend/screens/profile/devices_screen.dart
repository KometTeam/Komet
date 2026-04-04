import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show accountModule;
import '../../../backend/modules/account.dart' show SessionInfo;
import '../../widgets/custom_notification.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<SessionInfo> _sessions = [];
  final Map<int, Map<String, dynamic>> _ipDetails = {};
  final Set<int> _loadingIps = {};
  final Set<int> _expandedSessions = {};
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadSessions();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await accountModule.getSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка загрузки: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _terminateOthers() async {
    try {
      await accountModule.terminateOtherSessions();
      if (mounted) {
        showCustomNotification(context, 'Все сессии завершены');
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка: $e');
      }
    }
  }

  Future<void> _lookupIp(int id, String location) async {
    if (_ipDetails.containsKey(id)) {
      setState(() => _expandedSessions.add(id));
      return;
    }

    final reg = RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b');
    final match = reg.firstMatch(location);
    if (match == null) return;
    final ip = match.group(0)!;

    if (mounted) {
      setState(() => _loadingIps.add(id));
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(
        Uri.parse(
          'http://ip-api.com/json/$ip?fields=status,message,country,city,isp,as,mobile,proxy,timezone',
        ),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (mounted) {
          setState(() {
            _ipDetails[id] = data;
            _expandedSessions.add(id);
            _loadingIps.remove(id);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingIps.remove(id));
        showCustomNotification(context, 'Ошибка IP: $e');
      }
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (now.year == date.year &&
        now.month == date.month &&
        now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    final months = [
      'янв.',
      'февр.',
      'мар.',
      'апр.',
      'мая',
      'июня',
      'июля',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.',
    ];

    if (now.year == date.year) {
      return '${date.day} ${months[date.month - 1]}';
    }

    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Устройства',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildPromoCard(context, cs),
            const SizedBox(height: 12),
            _buildDevicesList(context, cs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(Symbols.devices, color: cs.onSurface, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Устройства в KOMET',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Кто имеет доступ к вашему аккаунту?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (_isLoading)
            ...List.generate(5, (index) => _buildShimmerItem(cs))
          else
            ..._sessions.map(
              (session) => _buildDeviceItem(
                context,
                cs,
                id: session.uniqueId,
                title: session.client + (session.current ? ' (текущая)' : ''),
                platform: session.info,
                location: session.location,
                status: session.current ? 'В сети' : null,
                time: session.current ? null : _formatTime(session.time),
                isOnline: session.current,
              ),
            ),
          if (!_isLoading) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: cs.onSurface.withValues(alpha: 0.05),
              indent: 20,
              endIndent: 20,
            ),
            InkWell(
              onTap: _terminateOthers,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                child: Text(
                  'Завершить все сессии, кроме текущей',
                  style: TextStyle(
                    color: cs.error.withValues(alpha: 0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerItem(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + 0.2 * sin(_shimmerController.value * pi * 2);
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 180,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceItem(
    BuildContext context,
    ColorScheme cs, {
    required int id,
    required String title,
    required String platform,
    required String location,
    String? status,
    String? time,
    bool isOnline = false,
  }) {
    final details = _ipDetails[id];
    final isLoading = _loadingIps.contains(id);
    final isExpanded = _expandedSessions.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      platform,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.greenAccent : cs.outline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status,
                            style: TextStyle(
                              color: isOnline
                                  ? Colors.greenAccent
                                  : cs.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!isExpanded)
                    InkWell(
                      onTap: isLoading ? null : () => _lookupIp(id, location),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: isLoading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              )
                            : Icon(
                                Symbols.add_circle,
                                size: 20,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            child: isExpanded && details != null
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              cs,
                              Symbols.location_city,
                              '${details['city'] ?? 'Unknown'}, ${details['country'] ?? ''}',
                            ),
                            _buildDetailRow(
                              cs,
                              Symbols.dns,
                              details['isp'] ?? 'Unknown',
                            ),
                            _buildDetailRow(
                              cs,
                              Symbols.public,
                              details['as'] ?? 'Unknown',
                            ),
                            if (details['mobile'] == true)
                              _buildDetailRow(
                                cs,
                                Symbols.stay_current_portrait,
                                'Мобильная сеть',
                                color: Colors.blueAccent,
                              ),
                            if (details['proxy'] == true)
                              _buildDetailRow(
                                cs,
                                Symbols.vpn_lock,
                                'Обнаружен прокси/VPN',
                                color: Colors.orangeAccent,
                              ),
                            _buildDetailRow(
                              cs,
                              Symbols.schedule,
                              details['timezone'] ?? 'Unknown',
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _expandedSessions.remove(id)),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Symbols.do_not_disturb_on,
                                size: 20,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ColorScheme cs,
    IconData icon,
    String text, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color ?? cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
