import "package:flutter/material.dart";

import "../app_state.dart";
import "../theme/brand.dart";

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final delta = snapshot.clickDeltaPercent;
    final top = [...snapshot.pages]..sort((a, b) => b.clicks7d.compareTo(a.clicks7d));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Insights", style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          const Text("Clicks on storefront and post links. Sales and commissions stay in each affiliate dashboard."),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: studioCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CLICKS · 7 DAYS", style: Theme.of(context).textTheme.bodySmall),
                Text("${snapshot.clicks7d}", style: Theme.of(context).textTheme.displaySmall),
                if (delta != null)
                  Text("${delta > 0 ? "+" : ""}$delta% vs the previous 7 days", style: const TextStyle(color: Brand.positive, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("Top looks", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          for (final page in top.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(page.title),
              trailing: Text(page.clicks7d > 0 ? "${page.clicks7d}" : "—"),
            ),
        ],
      ),
    );
  }
}
