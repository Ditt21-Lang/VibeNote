import 'package:flutter/material.dart';

import '../../data/models/study_session.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key, required this.loadSessions});

  final Future<List<StudySession>> Function() loadSessions;

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
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
    await future;
  }

  void _retry() {
    setState(() {
      _sessionsFuture = widget.loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Analytics'),
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
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: _AnalyticsContent(
                      snapshot: snapshot,
                      onRetry: _retry,
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

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.snapshot, required this.onRetry});

  final AsyncSnapshot<List<StudySession>> snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _StatePanel(
        icon: Icons.sync,
        title: 'Mengambil analytics...',
        message: 'Data logbook sedang dihitung.',
      );
    }

    if (snapshot.hasError) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Analytics belum tersedia',
        message: 'Cek koneksi internet, MONGO_URI, dan nama database.',
        actionLabel: 'Coba Lagi',
        onAction: onRetry,
      );
    }

    final sessions = snapshot.data ?? const <StudySession>[];
    if (sessions.isEmpty) {
      return const _StatePanel(
        icon: Icons.insights_outlined,
        title: 'Belum ada data',
        message: 'Buat logbook dulu supaya analytics bisa dihitung.',
      );
    }

    final summary = _AnalyticsSummary.fromSessions(sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageIntro(summary: summary),
        const SizedBox(height: 18),
        _OverviewBlock(summary: summary),
        const SizedBox(height: 16),
        _WeeklyTrendBlock(days: summary.weeklyDays),
        const SizedBox(height: 16),
        _TopObjectsBlock(objects: summary.topObjects),
        const SizedBox(height: 16),
        _VibeBreakdownBlock(vibes: summary.vibes),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.summary});

  final _AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF10BFAE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insight Logbook',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.totalSessions} sesi tercatat dengan ${summary.totalPhotos} foto dokumentasi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({required this.summary});

  final _AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Overview',
      icon: Icons.dashboard_outlined,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _MetricBox(label: 'Total sesi', value: '${summary.totalSessions}'),
          _MetricBox(
            label: 'Total durasi',
            value: _formatDuration(summary.totalMinutes),
          ),
          _MetricBox(
            label: 'Rata-rata',
            value: _formatDuration(summary.averageMinutes),
          ),
          _MetricBox(label: 'Minggu ini', value: '${summary.thisWeekSessions}'),
        ],
      ),
    );
  }
}

class _WeeklyTrendBlock extends StatelessWidget {
  const _WeeklyTrendBlock({required this.days});

  final List<_DayStat> days;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = days.fold<int>(
      0,
      (max, day) => day.minutes > max ? day.minutes : max,
    );

    return _AnalyticsCard(
      title: 'Weekly Trend',
      icon: Icons.stacked_bar_chart_outlined,
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days) ...[
              Expanded(
                child: _DayBar(
                  day: day,
                  ratio: maxMinutes == 0 ? 0 : day.minutes / maxMinutes,
                ),
              ),
              if (day != days.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopObjectsBlock extends StatelessWidget {
  const _TopObjectsBlock({required this.objects});

  final List<_RankedStat> objects;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Top Detected Objects',
      icon: Icons.center_focus_strong_outlined,
      child: objects.isEmpty
          ? const _EmptyBlock(message: 'Belum ada objek terdeteksi.')
          : _RankedList(stats: objects, color: const Color(0xFF238BFF)),
    );
  }
}

class _VibeBreakdownBlock extends StatelessWidget {
  const _VibeBreakdownBlock({required this.vibes});

  final List<_RankedStat> vibes;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Vibe Breakdown',
      icon: Icons.auto_awesome_outlined,
      child: vibes.isEmpty
          ? const _EmptyBlock(message: 'Belum ada vibe yang dianalisis.')
          : _RankedList(stats: vibes, color: const Color(0xFF10BFAE)),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E3E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF10BFAE)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8F1EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0B8E82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF696969),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.ratio});

  final _DayStat day;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final heightFactor = ratio.clamp(0.08, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          day.sessions.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF6A6A6A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: day.minutes == 0
                      ? const Color(0xFFE5E5E5)
                      : const Color(0xFF10BFAE),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.stats, required this.color});

  final List<_RankedStat> stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.first.count;

    return Column(
      children: [
        for (final stat in stats) ...[
          _RankedRow(stat: stat, color: color, maxCount: maxCount),
          if (stat != stats.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.stat,
    required this.color,
    required this.maxCount,
  });

  final _RankedStat stat;
  final Color color;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : stat.count / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${stat.count}x',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666666),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFEAEAEA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF686868),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF10BFAE)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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

class _AnalyticsSummary {
  const _AnalyticsSummary({
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageMinutes,
    required this.thisWeekSessions,
    required this.totalPhotos,
    required this.weeklyDays,
    required this.topObjects,
    required this.vibes,
  });

  final int totalSessions;
  final int totalMinutes;
  final int averageMinutes;
  final int thisWeekSessions;
  final int totalPhotos;
  final List<_DayStat> weeklyDays;
  final List<_RankedStat> topObjects;
  final List<_RankedStat> vibes;

  factory _AnalyticsSummary.fromSessions(List<StudySession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklyDays = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final daySessions = sessions.where(
        (session) => _sameDay(session.date, date),
      );
      return _DayStat(
        label: _shortDayName(date),
        date: date,
        sessions: daySessions.length,
        minutes: daySessions.fold<int>(
          0,
          (total, session) => total + session.durationMinutes,
        ),
      );
    });

    final totalMinutes = sessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );
    final thisWeekSessions = sessions.where((session) {
      final date = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      return !date.isBefore(weekStart) && !date.isAfter(today);
    }).length;

    return _AnalyticsSummary(
      totalSessions: sessions.length,
      totalMinutes: totalMinutes,
      averageMinutes: sessions.isEmpty ? 0 : totalMinutes ~/ sessions.length,
      thisWeekSessions: thisWeekSessions,
      totalPhotos: sessions.fold<int>(
        0,
        (total, session) => total + session.photos.length,
      ),
      weeklyDays: weeklyDays,
      topObjects: _rank(
        sessions.expand((session) => session.detectedObjects).toList(),
      ),
      vibes: _rank(
        sessions
            .map((session) => session.vibe.label.trim())
            .where((label) => label.isNotEmpty && label != 'Belum dianalisis')
            .toList(),
      ),
    );
  }

  static List<_RankedStat> _rank(List<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      final label = value.trim();
      if (label.isEmpty) continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final stats =
        counts.entries
            .map((entry) => _RankedStat(label: entry.key, count: entry.value))
            .toList()
          ..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            if (countCompare != 0) return countCompare;
            return a.label.compareTo(b.label);
          });

    return stats.take(5).toList();
  }

  static bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _shortDayName(DateTime date) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[date.weekday - 1];
  }
}

class _DayStat {
  const _DayStat({
    required this.label,
    required this.date,
    required this.sessions,
    required this.minutes,
  });

  final String label;
  final DateTime date;
  final int sessions;
  final int minutes;
}

class _RankedStat {
  const _RankedStat({required this.label, required this.count});

  final String label;
  final int count;
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) {
    return '${remainingMinutes}m';
  }
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainingMinutes}m';
}
