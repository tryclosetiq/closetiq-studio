import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../domain/models.dart";
import "../theme/brand.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final snapshot = state.store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, wide ? 28 : 12, wide ? 28 : 16, 24),
        children: [
          if (snapshot.example)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                "Example studio · connect a Supabase project to use your own account",
                style: TextStyle(color: Brand.cream, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          _Header(snapshot: snapshot, wide: wide),
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _IdeaCard(snapshot: snapshot, wide: true)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _Stats(snapshot: snapshot, wide: true),
                      const SizedBox(height: 12),
                      _Attention(snapshot: snapshot),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _IdeaCard(snapshot: snapshot, wide: false),
            const SizedBox(height: 12),
            _Stats(snapshot: snapshot, wide: false),
            const SizedBox(height: 12),
            _Attention(snapshot: snapshot),
          ],
          const SizedBox(height: 22),
          _Recent(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.wide});

  final StudioSnapshot snapshot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final name = snapshot.settings.displayName;
    final title = wide ? "${greetingFor(DateTime.now())}, $name" : "Hi, $name";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!wide)
          Text("CLOSETIQ STUDIO", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.muted, letterSpacing: 1.2)),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: wide ? 40 : 34)),
              ),
            ),
            if (wide) ...[
              OutlinedButton(onPressed: () => context.go("/storefront"), child: const Text("View storefront")),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.go("/create"),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Create a post"),
              ),
            ] else ...[
              _round(context, Icons.bar_chart_rounded, "open-insights", () => context.go("/insights")),
              const SizedBox(width: 8),
              _round(context, Icons.person_outline, "open-account", () => context.go("/account")),
            ],
          ],
        ),
        if (wide)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              snapshot.clicks7d == 0
                  ? "Your storefront is ready for its first clicks."
                  : "Your storefront earned clicks this week. ${snapshot.attention.length} ${snapshot.attention.length == 1 ? "link needs" : "links need"} a look.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Brand.muted),
            ),
          ),
      ],
    );
  }

  Widget _round(BuildContext context, IconData icon, String keyName, VoidCallback onTap) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Ink(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(color: Brand.card, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Brand.line))),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.snapshot, required this.wide});

  final StudioSnapshot snapshot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final idea = snapshot.outfits.isEmpty ? "" : snapshot.outfits.first.idea;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: studioCard(color: Brand.ink, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("IDEA  ·  POST IN 4 STEPS", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.gold, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Text(
            wide ? "What do you want to post today?" : "What are we posting today?",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Brand.cream),
          ),
          const SizedBox(height: 14),
          Material(
            color: const Color(0xFF2A251F),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go("/create"),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(
                  idea.isEmpty ? "e.g. 3 cozy fall looks under \$100, espresso and cream" : idea,
                  style: TextStyle(color: idea.isEmpty ? Brand.muted : Brand.cream),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in ["Office", "Date night", "Restyle", if (wide) "Weekend casual"])
                ActionChip(
                  label: Text(chip),
                  backgroundColor: const Color(0xFF2A251F),
                  labelStyle: const TextStyle(color: Brand.cream),
                  side: const BorderSide(color: Color(0xFF3A342C)),
                  onPressed: () => context.go("/create"),
                ),
            ],
          ),
          if (wide) ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC4A574), foregroundColor: Brand.ink),
              onPressed: () => context.go("/create"),
              child: const Text("Style it for me  →"),
            ),
            const SizedBox(height: 8),
            Text("AI picks real products · you approve every piece", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFB7AA9A))),
          ],
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.snapshot, required this.wide});

  final StudioSnapshot snapshot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final delta = snapshot.clickDeltaPercent;
    final next = snapshot.upNext;
    final scheduled = snapshot.posts.where((post) => post.status != "cancelled").length;
    return Row(
      children: [
        Expanded(child: _stat(
          context,
          wide ? "STOREFRONT CLICKS · 7 DAYS" : "CLICKS · 7D",
          "${snapshot.clicks7d}",
          delta == null ? null : "${delta > 0 ? "+" : ""}$delta%",
        )),
        const SizedBox(width: 10),
        Expanded(child: _stat(
          context,
          wide ? "POSTS SCHEDULED" : "UP NEXT",
          wide ? "$scheduled" : (next == null ? "—" : formatTime(next.when)),
          wide ? (next == null ? "Nothing queued" : "Next: today ${formatTime(next.when)}") : (next?.title ?? "Nothing queued"),
        )),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value, String? foot) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: studioCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          if (foot != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: foot.startsWith("+") || foot.startsWith("-")
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Brand.positiveBg, borderRadius: BorderRadius.circular(99)),
                      child: Text(foot, style: const TextStyle(color: Brand.positive, fontWeight: FontWeight.w600, fontSize: 12)),
                    )
                  : Text(foot, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.snapshot});

  final StudioSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: studioCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "NEEDS ATTENTION · ${snapshot.attention.length}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 0.6),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: snapshot.attention.isEmpty
                    ? null
                    : () => _note(context, "Automatic sold-out checks arrive in a later update. Items without an affiliate link are listed here now."),
                child: const Text("Fix all"),
              ),
            ],
          ),
          if (snapshot.attention.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text("Nothing needs a fix. Link health checks arrive in a later update."),
            )
          else
            for (final item in snapshot.attention)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _swatch(item.swatch),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _note(
                        context,
                        item.actionLabel == "Swap"
                            ? "Finding a replacement uses Discover, which is not connected in this version."
                            : "Open the item in Closet and add an affiliate link, or mark it as not monetized by leaving the link empty.",
                      ),
                      child: Text(item.actionLabel),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _note(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.snapshot});

  final StudioSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [...snapshot.pages]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      children: [
        Row(
          children: [
            Text("Recent looks", style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            TextButton(onPressed: () => context.go("/storefront"), child: Text(wide ? "All looks" : "See all")),
          ],
        ),
        const SizedBox(height: 8),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final page in pages.take(4))
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _LookCard(page: page, tall: true))),
            ],
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(width: 150, child: _LookCard(page: pages[index], tall: false)),
            ),
          ),
      ],
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({required this.page, required this.tall});

  final ShopPage page;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final status = page.published ? "Live" : (page.title.toLowerCase().contains("date") ? "Scheduled" : "Draft");
    return InkWell(
      onTap: () => context.go("/storefront"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: tall ? 280 : 140,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Color(page.swatch), borderRadius: BorderRadius.circular(18)),
            child: const Text("EXAMPLE", style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: Text("${page.pieceCount} pieces${page.clicks7d > 0 ? " · ${page.clicks7d} clicks" : ""}", style: Theme.of(context).textTheme.bodySmall)),
              Text(status, style: TextStyle(color: page.published ? Brand.positive : Brand.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _swatch(int color) {
  return Container(width: 44, height: 44, decoration: BoxDecoration(color: Color(color), borderRadius: BorderRadius.circular(12)));
}
