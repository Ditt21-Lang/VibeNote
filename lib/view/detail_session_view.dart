import 'package:flutter/material.dart';

import '../data/models/study_session.dart';

class DetailSessionView extends StatelessWidget {
  const DetailSessionView({super.key, required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _DetailHeader(session: session),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SessionSummaryCard(session: session),
                        const SizedBox(height: 22),
                        const _SectionLabel(
                          icon: Icons.camera_alt_outlined,
                          label: 'Foto Sesi',
                        ),
                        const SizedBox(height: 14),
                        const _PhotoPlaceholderRow(),
                        const SizedBox(height: 34),
                        const _SectionLabel(
                          icon: Icons.lightbulb_outline,
                          label: 'Insight sesi',
                        ),
                        const SizedBox(height: 16),
                        _VibePanel(vibe: session.vibe),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFD8D8D8))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: Color(0x33000000),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.arrow_back, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Sesi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _dayAndDate(session.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E3E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(type: session.type),
              const Spacer(),
              const Icon(Icons.schedule, size: 23, color: Color(0xFF777777)),
              const SizedBox(width: 8),
              Text(
                _formatDuration(session.durationMinutes),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF777777),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _MutedLabel('Event'),
          const SizedBox(height: 3),
          Text(
            session.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          const _MutedLabel('Objek Terdeteksi'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final object in session.detectedObjects)
                _ObjectChip(label: object),
            ],
          ),
          const SizedBox(height: 18),
          const _MutedLabel('Deskripsi'),
          const SizedBox(height: 6),
          Text(
            session.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF238BFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MutedLabel extends StatelessWidget {
  const _MutedLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: const Color(0xFF8C8C8C),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ObjectChip extends StatelessWidget {
  const _ObjectChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 16,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PhotoPlaceholderRow extends StatelessWidget {
  const _PhotoPlaceholderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _PhotoPlaceholder()),
        SizedBox(width: 16),
        Expanded(child: _PhotoPlaceholder()),
        SizedBox(width: 16),
        Expanded(child: _PhotoPlaceholder()),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8D8D8)),
        ),
      ),
    );
  }
}

class _VibePanel extends StatelessWidget {
  const _VibePanel({required this.vibe});

  final VibeAnalysis vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFB7EEE6),
        borderRadius: BorderRadius.circular(10),
        border: const Border(bottom: BorderSide(width: 2, color: Colors.black)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vibe: ${vibe.label}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (vibe.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              vibe.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
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

String _dayAndDate(DateTime date) {
  final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
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
