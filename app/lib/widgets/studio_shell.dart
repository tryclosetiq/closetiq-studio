import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../theme/brand.dart";

class StudioShell extends StatelessWidget {
  const StudioShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  bool get _create => location.startsWith("/create");

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(location: location),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: _create ? null : _PhoneNav(location: location),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final settings = state.store?.snapshot.settings;
    return Container(
      width: 232,
      color: const Color(0xFFF8F3EB),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("ClosetIQ", style: Theme.of(context).textTheme.headlineSmall),
          Text("STUDIO", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.gold, letterSpacing: 1.4)),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key("nav-create"),
            onPressed: () => context.go("/create"),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Create a post"),
          ),
          const SizedBox(height: 12),
          _SideLink(location: location, path: "/home", label: "Home", icon: Icons.home_outlined),
          _SideLink(location: location, path: "/closet", label: "Closet", icon: Icons.checkroom_outlined),
          _SideLink(location: location, path: "/storefront", label: "Storefront", icon: Icons.storefront_outlined),
          _SideLink(location: location, path: "/schedule", label: "Schedule", icon: Icons.calendar_month_outlined),
          _SideLink(location: location, path: "/insights", label: "Insights", icon: Icons.bar_chart_rounded),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: studioCard(radius: 14),
            child: Row(
              children: [
                const Text("Credits"),
                const Spacer(),
                Text("${settings?.creditBalance ?? 0} / ${settings?.creditAllowance ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key("nav-settings"),
              onPressed: () => context.go("/account"),
              child: const Text("Creator plan · Settings"),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideLink extends StatelessWidget {
  const _SideLink({required this.location, required this.path, required this.label, required this.icon});

  final String location;
  final String path;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final selected = location == path;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        key: Key("nav-${path.substring(1)}"),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Brand.soft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Brand.ink),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneNav extends StatelessWidget {
  const _PhoneNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Brand.cream,
      child: SafeArea(
        top: false,
        child: Container(
          height: 86,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Brand.line))),
          child: Row(
            children: [
              _tab(context, "/home", "Home", Icons.home_outlined),
              _tab(context, "/closet", "Closet", Icons.checkroom_outlined),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: InkWell(
                        key: const Key("nav-create"),
                        onTap: () => context.go("/create"),
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(color: Brand.ink, shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Brand.cream, size: 28),
                        ),
                      ),
                    ),
                    const Text("Create", style: TextStyle(fontSize: 11, color: Brand.muted)),
                  ],
                ),
              ),
              _tab(context, "/storefront", "Storefront", Icons.storefront_outlined),
              _tab(context, "/schedule", "Schedule", Icons.calendar_month_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String path, String label, IconData icon) {
    final selected = location == path;
    return Expanded(
      child: InkWell(
        key: Key("nav-${path.substring(1)}"),
        onTap: () => context.go(path),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Brand.ink : Brand.muted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? Brand.ink : Brand.muted)),
          ],
        ),
      ),
    );
  }
}
