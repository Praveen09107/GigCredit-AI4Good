import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onContinue, required this.onGuidelines});

  final VoidCallback onContinue;
  final VoidCallback onGuidelines;
  static final AuthService _authService = AuthService();

  static const _cards = <Map<String, dynamic>>[
    {
      'title': 'Real User Testing',
      'sub': 'Tested with real gig workers',
      'icon': Icons.people_rounded,
      'accent': Color(0xFF3D7BFF),
      'image': 'assets/home/WhatsApp Image 2026-03-15 at 10.16.06 PM.jpeg',
    },
    {
      'title': 'Real User Testing',
      'sub': 'Validated with real financial data',
      'icon': Icons.account_balance_rounded,
      'accent': Color(0xFFEE2BF5),
      'image': 'assets/home/WhatsApp Image 2026-03-15 at 5.38.15 PM.jpeg',
    },
    {
      'title': 'Real User Testing',
      'sub': 'Used by delivery & freelance workers',
      'icon': Icons.delivery_dining_rounded,
      'accent': Color(0xFF00D4AA),
      'image': 'assets/home/WhatsApp Image 2026-03-15 at 5.38.17 PM.jpeg',
    },
    {
      'title': 'Real User Testing',
      'sub': 'Built for real-world scenarios',
      'icon': Icons.handshake_rounded,
      'accent': Color(0xFFFFBA00),
      'image': 'assets/home/WhatsApp Image 2026-03-15 at 7.53.24 PM.jpeg',
    },
  ];

  static const _pillars = <Map<String, dynamic>>[
    {'icon': Icons.shield_rounded,      'label': 'Privacy-First',      'accent': Color(0xFF3D7BFF)},
    {'icon': Icons.phone_android_rounded,'label': 'On-Device AI',       'accent': Color(0xFFEE2BF5)},
    {'icon': Icons.verified_rounded,    'label': 'Multi-Layer KYC',    'accent': Color(0xFF00D4AA)},
    {'icon': Icons.credit_score_rounded,'label': '300–900 Score',      'accent': Color(0xFFFFBA00)},
  ];

  void _showGetStartedPopup(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => Dialog(
        backgroundColor: GigTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: GigTheme.accentGrad,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: GigTheme.magenta.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                'Start Verification',
                style: TextStyle(
                  color: GigTheme.txtPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete 9 steps to receive your GigCredit\nscore. Takes about 10–15 minutes.',
                style: TextStyle(color: GigTheme.txtSecond, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Continue CTA
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: GigTheme.accentButton(),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onContinue();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Continue to Verification',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Input Guidelines option
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GigTheme.blue,
                    side: const BorderSide(color: GigTheme.blue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onGuidelines();
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text(
                    'View Input Guidelines',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GigTheme.bgDeep,
      body: Stack(
        children: [
          // Background gradient overlay
          Container(
            decoration: const BoxDecoration(gradient: GigTheme.heroGrad),
          ),
          // Decorative glowing circles
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigTheme.blue.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigTheme.magenta.withAlpha(15),
              ),
            ),
          ),
          // Main scroll content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildPillarsRow()),
                SliverToBoxAdapter(child: _buildSectionLabel('Real World Evidence')),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ImageCard(card: _cards[i]),
                      childCount: _cards.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSectionLabel('Why GigCredit')),
                SliverToBoxAdapter(child: _buildWhySection()),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          // Floating bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo mark
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: GigTheme.accentGrad,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/home/gigcredit_logo.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'GigCredit',
                style: TextStyle(
                  color: GigTheme.txtPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Logout
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: GigTheme.txtSecond, size: 22),
                onPressed: () async {
                  await _authService.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Your financial\nidentity, scored.',
            style: TextStyle(
              color: GigTheme.txtPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.2,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Complete the 9-step verification to receive\nyour accurate GigCredit score (300–900).',
            style: TextStyle(
              color: GigTheme.txtSecond,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildPillarsRow() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _pillars.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = _pillars[i];
          final accent = p['accent'] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: GigTheme.glassCard(accent: accent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(p['icon'] as IconData, color: accent, size: 20),
                const SizedBox(height: 6),
                Text(
                  p['label'] as String,
                  style: const TextStyle(
                    color: GigTheme.txtPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Text(
        label,
        style: const TextStyle(
          color: GigTheme.txtSecond,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildWhySection() {
    const items = [
      {'icon': Icons.phone_android_rounded, 'title': 'On-Device Processing', 'sub': 'OCR and scoring run locally — no cloud dependency.'},
      {'icon': Icons.shield_rounded,        'title': 'Privacy-First by Design', 'sub': 'Your documents never leave your device.'},
      {'icon': Icons.verified_rounded,      'title': 'Multi-Layer Verification', 'sub': 'Identity, bank, utility and work proof all verified.'},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: GigTheme.surfaceCard(),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: GigTheme.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: GigTheme.blue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: GigTheme.txtPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['sub'] as String,
                        style: const TextStyle(
                          color: GigTheme.txtSecond,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GigTheme.bg,
        border: const Border(top: BorderSide(color: GigTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Guidelines shortcut
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GigTheme.blue,
                      side: const BorderSide(color: GigTheme.blue, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onGuidelines,
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text(
                      'Guidelines',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Get Started CTA
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: GigTheme.accentButton(),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _showGetStartedPopup(context),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Image Card Widget
// ─────────────────────────────────────────────
class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.card});
  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final accent = card['accent'] as Color;
    return Container(
      decoration: BoxDecoration(
        color: GigTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Image.asset(
            card['image'] as String,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: GigTheme.surfaceUp,
              child: Icon(card['icon'] as IconData, color: accent, size: 36),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  GigTheme.bgDeep.withAlpha(200),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Text label
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withAlpha(80)),
                    ),
                    child: Text(
                      card['sub'] as String,
                      style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    card['title'] as String,
                    style: const TextStyle(
                      color: GigTheme.txtPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
