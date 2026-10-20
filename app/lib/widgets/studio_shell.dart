import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../theme/brand.dart";

/// Phone layout from the live Studio: Fraunces title, credit counter, and a
/// horizontally scrolling tab bar in the same order as index.html.
class StudioShell extends StatelessWidget {
  const StudioShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const tabs = <(String, String, IconData)>[
    ("/models", "Models", Icons.person_outline),
    ("/clothing", "Clothing", Icons.checkroom_outlined),
    ("/try-on", "Try-On", Icons.auto_awesome_outlined),
    ("/discover", "Discover", Icons.search),
    ("/collages", "Collages", Icons.dashboard_customize_outlined),
    ("/photos", "Photos", Icons.photo_outlined),
    ("/outfits", "Outfits", Icons.grid_view_rounded),
    ("/reels", "Reels", Icons.play_circle_outline),
    ("/storefront", "Storefront", Icons.storefront_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = StudioScope.of(context).store?.snapshot.settings;
    final usage = settings?.usageLabel ?? "";
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Brand.cream,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.line))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "ClosetIQ Studio",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        usage,
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Brand.muted, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    IconButton(
                      key: const Key("open-account"),
                      tooltip: "Account",
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.go("/account"),
                      icon: const Icon(Icons.person_outline, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
          const _TabBar(),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Material(
      color: Brand.card,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Brand.line))),
          height: 64,
          child: ListView.separated(
            key: const Key("studio-tabs"),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: StudioShell.tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 0),
            itemBuilder: (context, index) {
              final (path, label, icon) = StudioShell.tabs[index];
              final selected = location == path;
              final color = selected ? Brand.gold : Brand.muted;
              return InkWell(
                key: Key("nav-${path.substring(1)}"),
                onTap: () => context.go(path),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void studioLater(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 12, letterSpacing: 0.6, color: Brand.muted, fontWeight: FontWeight.w600),
    );
  }
}

class DashedAddTile extends StatelessWidget {
  const DashedAddTile({required this.label, required this.onTap, this.tileKey, super.key});

  final String label;
  final VoidCallback onTap;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: const _DashPainter(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Brand.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SwatchCard extends StatelessWidget {
  const SwatchCard({required this.color, required this.label, this.badge, this.onTap, super.key});

  final int color;
  final String label;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Color(color)),
            if (badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                color: Colors.black45,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
