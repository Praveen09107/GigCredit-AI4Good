import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../models/guidelines.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const Map<int, Color> _stepAccents = {
  1: Color(0xFF3D7BFF),
  2: Color(0xFFEE2BF5),
  3: Color(0xFF00D4AA),
  4: Color(0xFFFFBA00),
  5: Color(0xFFFF6B3D),
  6: Color(0xFF7C3AED),
  7: Color(0xFF10B981),
  8: Color(0xFFF59E0B),
  9: Color(0xFF3D7BFF),
};

const Map<int, IconData> _stepIcons = {
  1: Icons.person_rounded,
  2: Icons.badge_rounded,
  3: Icons.account_balance_rounded,
  4: Icons.bolt_rounded,
  5: Icons.work_rounded,
  6: Icons.flag_rounded,
  7: Icons.health_and_safety_rounded,
  8: Icons.receipt_long_rounded,
  9: Icons.credit_card_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// MAIN GUIDELINES SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key, required this.onProceed});
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GigTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: GigTheme.bg,
        title: const Text('Input Guidelines',
            style: TextStyle(color: GigTheme.txtPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GigTheme.txtPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: GigTheme.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              children: [
                // Banner card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: GigTheme.glassCard(accent: GigTheme.blue),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/home/gigcredit_logo.jpeg',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: GigTheme.blue.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: GigTheme.blue, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: GigTheme.blue.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: GigTheme.blue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Before you start',
                                style: TextStyle(color: GigTheme.txtPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                            SizedBox(height: 3),
                            Text('Tap any step to see what inputs are needed and how to get each document.',
                                style: TextStyle(color: GigTheme.txtSecond, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('SELECT A STEP',
                    style: TextStyle(color: GigTheme.txtSecond, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                // 3-column step grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gigCreditGuidelines.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (ctx, index) {
                    final step   = gigCreditGuidelines[index];
                    final accent = _stepAccents[step.stepNumber] ?? GigTheme.blue;
                    final icon   = _stepIcons[step.stepNumber] ?? Icons.chevron_right;
                    return _StepCard(
                      step: step, accent: accent, icon: icon,
                      onTap: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                        builder: (_) => _StepDetailScreen(step: step, accent: accent),
                      )),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Bottom CTA
          Container(
            decoration: const BoxDecoration(
                color: GigTheme.bg, border: Border(top: BorderSide(color: GigTheme.divider))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: DecoratedBox(
                    decoration: GigTheme.accentButton(),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onProceed,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Proceed to Verification',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Grid Card
// ─────────────────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.accent, required this.icon, required this.onTap});
  final StepGuideline step;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // count total inputs including work type categories
    int total = step.inputs.length;
    if (step.workTypeCategories != null) {
      total += step.workTypeCategories!.fold(0, (sum, c) => sum + c.inputs.length);
    }
    final uploadCount = _countUploads(step);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: GigTheme.surfaceCard(accent: accent),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(step.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: accent.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: Text('Step ${step.stepNumber}',
                        style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 3),
                  Text(step.title,
                      style: const TextStyle(
                          color: GigTheme.txtPrimary, fontWeight: FontWeight.w800, fontSize: 10, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                _Chip(label: '${total}in', color: GigTheme.blue),
                if (uploadCount > 0) _Chip(label: '${uploadCount}doc', color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _countUploads(StepGuideline s) {
    int n = s.inputs.where((i) => i.type == InputType.upload).length;
    if (s.workTypeCategories != null) {
      for (final cat in s.workTypeCategories!) {
        n += cat.inputs.where((i) => i.type == InputType.upload).length;
      }
    }
    return n;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _StepDetailScreen extends StatelessWidget {
  const _StepDetailScreen({required this.step, required this.accent});
  final StepGuideline step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textInputs   = step.inputs.where((i) => i.type == InputType.text).toList();
    final uploadInputs = step.inputs.where((i) => i.type == InputType.upload).toList();
    final hasWorkTypes = step.workTypeCategories != null && step.workTypeCategories!.isNotEmpty;

    return Scaffold(
      backgroundColor: GigTheme.bgDeep,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: GigTheme.bg,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [GigTheme.bgDeep, accent.withAlpha(65)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 88, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(children: [
                      Text(step.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      _StepBadge(step.stepNumber, accent),
                    ]),
                    const SizedBox(height: 6),
                    Text(step.title,
                        style: const TextStyle(
                            color: GigTheme.txtPrimary, fontWeight: FontWeight.w900, fontSize: 22)),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Text Inputs section ──────────────────────────────────
                if (textInputs.isNotEmpty) ...[
                  const _SectionLabel(
                    icon: Icons.edit_note_rounded, color: GigTheme.blue,
                    title: 'Fields to Fill In',
                    subtitle: 'Enter your correct details as per official records.',
                  ),
                  const SizedBox(height: 10),
                  _TextInputsCard(inputs: textInputs, accent: GigTheme.blue),
                  const SizedBox(height: 22),
                ],

                // ── Upload inputs section ─────────────────────────────────
                if (uploadInputs.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.upload_file_rounded, color: accent,
                    title: 'Documents to Upload',
                    subtitle: 'Tap each card to see how to get it.',
                  ),
                  const SizedBox(height: 10),
                  ...uploadInputs.map((u) => _UploadCard(input: u, accent: accent)),
                  const SizedBox(height: 22),
                ],

                // ── Step 5 Work Type Categories ───────────────────────────
                if (hasWorkTypes) ...[
                  _SectionLabel(
                    icon: Icons.category_rounded, color: accent,
                    title: 'Select Your Work Type',
                    subtitle: 'Tap your category to see required documents.',
                  ),
                  const SizedBox(height: 12),
                  ...step.workTypeCategories!.map((cat) => _WorkTypeSection(cat: cat, accent: accent)),
                ],

                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text Inputs Card — all in one clean list
// ─────────────────────────────────────────────────────────────────────────────
class _TextInputsCard extends StatelessWidget {
  const _TextInputsCard({required this.inputs, required this.accent});
  final List<InputGuideline> inputs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GigTheme.surfaceCard(),
      child: Column(
        children: inputs.asMap().entries.map((entry) {
          final i      = entry.value;
          final isLast = entry.key == inputs.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(i.title,
                                  style: const TextStyle(
                                      color: GigTheme.txtPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                            if (!i.mandatory) _OptionalBadge(),
                          ]),
                          const SizedBox(height: 3),
                          Text(i.description,
                              style: const TextStyle(fontSize: 12, color: GigTheme.txtSecond, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: GigTheme.divider, indent: 35),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Card — expandable with procedure + YouTube
// ─────────────────────────────────────────────────────────────────────────────
class _UploadCard extends StatefulWidget {
  const _UploadCard({required this.input, required this.accent});
  final InputGuideline input;
  final Color accent;
  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  Future<void> _openYoutubeLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid YouTube link')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open YouTube link')), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i      = widget.input;
    final accent = widget.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GigTheme.surfaceCard(accent: accent),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: accent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.insert_drive_file_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(i.title,
                                  style: const TextStyle(
                                      color: GigTheme.txtPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                            if (!i.mandatory) ...[const SizedBox(width: 6), _OptionalBadge()],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(i.description,
                            style: const TextStyle(fontSize: 12, color: GigTheme.txtSecond, height: 1.4),
                            maxLines: _expanded ? 10 : 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: accent, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            const Divider(height: 1, color: GigTheme.divider),

            // Procedure
            if (i.procedure != null && i.procedure!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.format_list_numbered_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text('How to Get This',
                          style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12)),
                    ]),
                    const SizedBox(height: 10),
                    ...i.procedure!.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(color: accent.withAlpha(20), shape: BoxShape.circle),
                              child: Center(
                                child: Text('${entry.key + 1}',
                                    style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(entry.value,
                                  style: const TextStyle(fontSize: 12, color: GigTheme.txtSecond, height: 1.45)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // YouTube
            if (i.youtubeTitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF0000).withAlpha(45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_rounded, color: Color(0xFFFF0000), size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YouTube Guide',
                                style: TextStyle(
                                    color: Color(0xFFFF0000), fontSize: 10, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(i.youtubeTitle!,
                                style: const TextStyle(
                                    color: GigTheme.txtPrimary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
                            if (i.youtubeUrl != null) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _openYoutubeLink(context, i.youtubeUrl!),
                                child: Text(
                                  i.youtubeUrl!,
                                  style: const TextStyle(
                                    color: GigTheme.blue,
                                    fontSize: 11,
                                    height: 1.2,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (i.youtubeUrl != null)
                        IconButton(
                          tooltip: 'Open YouTube',
                          icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFFFF0000), size: 18),
                          onPressed: () => _openYoutubeLink(context, i.youtubeUrl!),
                        ),
                      if (i.youtubeUrl != null)
                        IconButton(
                          tooltip: 'Copy YouTube Link',
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFFFF0000), size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: i.youtubeUrl!));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('YouTube link copied')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Work Type Category Section (Step 5)
// ─────────────────────────────────────────────────────────────────────────────
class _WorkTypeSection extends StatefulWidget {
  const _WorkTypeSection({required this.cat, required this.accent});
  final WorkTypeCategory cat;
  final Color accent;
  @override
  State<_WorkTypeSection> createState() => _WorkTypeSectionState();
}

class _WorkTypeSectionState extends State<_WorkTypeSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cat    = widget.cat;
    final accent = widget.accent;
    final textInputs   = cat.inputs.where((i) => i.type == InputType.text).toList();
    final uploadInputs = cat.inputs.where((i) => i.type == InputType.upload).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: GigTheme.surfaceCard(accent: accent),
      child: Column(
        children: [
          // Category header
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: accent.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name,
                            style: const TextStyle(
                                color: GigTheme.txtPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${cat.inputs.length} inputs required',
                            style: const TextStyle(color: GigTheme.txtSecond, fontSize: 12)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: accent, size: 24),
                  ),
                ],
              ),
            ),
          ),

          if (_open) ...[
            const Divider(height: 1, color: GigTheme.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text inputs
                  if (textInputs.isNotEmpty) ...[
                    const _InlineLabel(icon: Icons.edit_note_rounded, color: GigTheme.blue, label: 'Fields to Fill'),
                    const SizedBox(height: 8),
                    _TextInputsCard(inputs: textInputs, accent: GigTheme.blue),
                    const SizedBox(height: 16),
                  ],
                  // Upload inputs
                  if (uploadInputs.isNotEmpty) ...[
                    _InlineLabel(icon: Icons.upload_file_rounded, color: accent, label: 'Documents to Upload'),
                    const SizedBox(height: 8),
                    ...uploadInputs.map((u) => _UploadCard(input: u, accent: accent)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared tiny widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.color, required this.title, required this.subtitle});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: GigTheme.txtPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: GigTheme.txtSecond)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    ]);
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge(this.stepNumber, this.color);
  final int stepNumber;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80))),
      child: Text('Step $stepNumber',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _OptionalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: GigTheme.teal.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GigTheme.teal.withAlpha(60))),
      child: const Text('Optional',
          style: TextStyle(fontSize: 9, color: GigTheme.teal, fontWeight: FontWeight.w700)),
    );
  }
}
