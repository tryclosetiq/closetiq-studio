import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../domain/models.dart";
import "../theme/brand.dart";

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final posts = [...snapshot.posts]..sort((a, b) => a.when.compareTo(b.when));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Schedule", style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: studioCard(),
            child: const Text("Reminders only. Auto-posting is not in this version. On iOS, a later update can notify you to post with the share sheet. Web auto-posting stays out of the phone app."),
          ),
          const SizedBox(height: 16),
          if (posts.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text("Nothing scheduled. Create a post and save a reminder."))
          else
            for (final post in posts) _row(context, post),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go("/create"), child: const Text("Create a post")),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ScheduledPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: studioCard(),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDay(post.when), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(formatTime(post.when), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(post.networks.isEmpty ? "Reminder" : post.networks.join(" · "), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(99)),
            child: const Text("Reminder", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
