import 'package:flutter/material.dart';

import '../data/models/study_session.dart';
import '../data/remote/study_log_repository.dart';
import 'detail_session_view.dart';
import '../features/logbook/analytics_view.dart';
import '../features/logbook/create_logbook_view.dart';
import '../features/detection/camera_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, this.loadSessions});

  final Future<List<StudySession>> Function()? loadSessions;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Future<List<StudySession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<List<StudySession>> _loadSessions() {
    return widget.loadSessions?.call() ?? StudyLogRepository().fetchStudyLogs();
  }

  Future<void> _refreshSessions() async {
    final future = _loadSessions();
    setState(() {
      _sessionsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder handles the visible error state.
    }
  }

  void _retry() {
    setState(() {
      _sessionsFuture = _loadSessions();
    });
  }

  Future<void> _openAllSessions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _AllSessionsView(loadSessions: _loadSessions),
      ),
    );

    if (!mounted) return;
    await _refreshSessions();
  }

  Future<void> _openCreateLogbook() async {
    final session = await Navigator.of(context).push<StudySession>(
      MaterialPageRoute(builder: (_) => const CreateLogbookView()),
    );

    if (session == null || !mounted) return;

    await _refreshSessions();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Logbook berhasil disimpan!'),
          ],
        ),
        backgroundColor: const Color(0xFF10BFAE),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openAnalytics() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnalyticsView(loadSessions: _loadSessions),
      ),
    );

    if (!mounted) return;
    await _refreshSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: FutureBuilder<List<StudySession>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? const <StudySession>[];

                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF10BFAE),
                        onRefresh: _refreshSessions,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              _Header(sessions: sessions),
                              _QuickActions(
                                onCreateLogbook: _openCreateLogbook,
                                onOpenAnalytics: _openAnalytics,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  24,
                                ),
                                child: Column(
                                  children: [
                                    _SectionTitle(
                                      onViewAll: sessions.isNotEmpty
                                          ? _openAllSessions
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _SessionList(
                                      snapshot: snapshot,
                                      onRetry: _retry,
                                      onChanged: _refreshSessions,
                                      maxItems: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _BottomNavigation(
                      onCreateLogbook: _openCreateLogbook,
                      onOpenAnalytics: _openAnalytics,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final todaySessions = sessions.where(_isToday).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final todayDuration = todaySessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );
    final todayStatus = todaySessions.firstOrNull?.vibe.label ?? 'Kosong';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 38),
      decoration: const BoxDecoration(
        color: Color(0xFF10BFAE),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VibeNote',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _dayAndDate(DateTime.now()),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Waktu beraktivitas',
                  value: _formatDuration(todayDuration),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricTile(label: 'Status', value: todayStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  bool _isToday(StudySession session) {
    final now = DateTime.now();
    return session.date.year == now.year &&
        session.date.month == now.month &&
        session.date.day == now.day;
  }

  String _dayAndDate(DateTime date) {
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCreateLogbook,
    required this.onOpenAnalytics,
  });

  final VoidCallback onCreateLogbook;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mulai Sesi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ActionButton(
                    label: 'Kamera',
                    icon: Icons.camera_alt_outlined,
                    backgroundColor: Color(0xFFC9E3FF),
                    iconColor: Color(0xFF0B89FF),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CameraView(mode: CameraViewMode.standalone),
                      ),
                    ),
                  ),
                  _ActionButton(
                    label: 'Logbook',
                    icon: Icons.book_outlined,
                    backgroundColor: Color(0xFFB6ECE7),
                    iconColor: Color(0xFF03BCA9),
                    onTap: onCreateLogbook,
                  ),
                  _ActionButton(
                    label: 'Review',
                    icon: Icons.trending_up,
                    backgroundColor: Color(0xFFC5C5C5),
                    iconColor: Colors.black,
                    onTap: onOpenAnalytics,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor == Colors.black
                        ? Colors.white
                        : Colors.black,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Sesi terakhir',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0B7BFF),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Lihat Semua',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: onViewAll == null
                    ? const Color(0xFF8E8E8E)
                    : const Color(0xFF0B7BFF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.snapshot,
    required this.onRetry,
    required this.onChanged,
    this.maxItems,
  });

  final AsyncSnapshot<List<StudySession>> snapshot;
  final VoidCallback onRetry;
  final Future<void> Function() onChanged;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _StatusMessage(
        icon: Icons.sync,
        title: 'Mengambil logbook...',
        message: 'Data kegiatan sedang dibaca dari penyimpanan.',
      );
    }

    if (snapshot.hasError) {
      return _StatusMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal mengambil data',
        message: 'Cek koneksi internet, MONGO_URI, dan nama database.',
        actionLabel: 'Coba Lagi',
        onAction: onRetry,
      );
    }

    final sessions = snapshot.data ?? const <StudySession>[];
    if (sessions.isEmpty) {
      return const _StatusMessage(
        icon: Icons.library_books_outlined,
        title: 'Belum ada sesi',
        message: 'Belum ada logbook kegiatan yang tersimpan.',
      );
    }

    final displayedSessions = maxItems == null
        ? sessions
        : sessions.take(maxItems!);

    return Column(
      children: [
        for (final session in displayedSessions) ...[
          _SessionCard(session: session, onChanged: onChanged),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _AllSessionsView extends StatefulWidget {
  const _AllSessionsView({required this.loadSessions});

  final Future<List<StudySession>> Function() loadSessions;

  @override
  State<_AllSessionsView> createState() => _AllSessionsViewState();
}

class _AllSessionsViewState extends State<_AllSessionsView> {
  late Future<List<StudySession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.loadSessions();
  }

  Future<void> _refreshSessions() async {
    final future = widget.loadSessions();
    setState(() {
      _sessionsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder handles the visible error state.
    }
  }

  void _retry() {
    setState(() {
      _sessionsFuture = widget.loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Logbook'),
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: FutureBuilder<List<StudySession>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                return RefreshIndicator(
                  color: const Color(0xFF10BFAE),
                  onRefresh: _refreshSessions,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: _SessionList(
                      snapshot: snapshot,
                      onRetry: _retry,
                      onChanged: _refreshSessions,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF10BFAE)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6A6A6A)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onChanged});

  final StudySession session;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => DetailSessionView(session: session),
              ),
            );
            if (changed == true) {
              await onChanged();
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      session.type,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _typeColor(session.type),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _dayAndDate(session.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A6A6A),
                    height: 1.05,
                  ),
                ),
                Text(
                  session.timeRange,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A6A6A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final object in session.detectedObjects)
                      _ObjectChip(label: object),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'Kuliah' => const Color(0xFF087DFF),
      'Organisasi' => const Color(0xFF00B73C),
      'Pribadi' => const Color(0xFF5900FF),
      _ => const Color(0xFF333333),
    };
  }

  String _dayAndDate(DateTime date) {
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}

class _ObjectChip extends StatelessWidget {
  const _ObjectChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9,
          height: 1,
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.onCreateLogbook,
    required this.onOpenAnalytics,
  });

  final VoidCallback onCreateLogbook;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _NavItem(
            label: 'Beranda',
            icon: Icons.home_outlined,
            selected: true,
          ),
          _NavItem(
            label: 'Logbook',
            icon: Icons.book_outlined,
            onTap: onCreateLogbook,
          ),
          _NavItem(
            label: 'Kamera',
            icon: Icons.camera_alt_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const CameraView(mode: CameraViewMode.standalone),
              ),
            ),
          ),
          _NavItem(
            label: 'Statistik',
            icon: Icons.trending_up,
            onTap: onOpenAnalytics,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF14BFB0) : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : color,
                size: 30,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
