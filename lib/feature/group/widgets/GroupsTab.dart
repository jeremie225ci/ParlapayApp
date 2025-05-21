import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/group/screens/create_group_screen.dart';
import 'package:mk_mesenger/feature/group/screens/group_home_screen.dart';
import 'package:mk_mesenger/common/models/group.dart' as app_models;
import 'package:mk_mesenger/common/utils/colors.dart';

class GroupsTab extends ConsumerWidget {
  const GroupsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsStream = ref.watch(chatControllerProvider).chatGroups();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: StreamBuilder<List<app_models.Group>>(
        stream: groupsStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No perteneces a ningún grupo', style: TextStyle(color: textColor)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                    icon: const Icon(Icons.add, color: textColor),
                    label: const Text('Crear Grupo', style: TextStyle(color: textColor)),
                    onPressed: () => Navigator.pushNamed(context, CreateGroupScreen.routeName),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            separatorBuilder: (_, __) => Divider(color: dividerColor, indent: 72),
            itemBuilder: (_, i) {
              final g = groups[i];
              return ListTile(
                onTap: () => Navigator.pushNamed(
                  context, GroupHomeScreen.routeName,
                  arguments: {'groupId': g.groupId, 'name': g.name, 'profilePic': g.groupPic},
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: g.groupPic.isNotEmpty ? NetworkImage(g.groupPic) : null,
                  backgroundColor: unselectedItemColor.withOpacity(0.3),
                  child: g.groupPic.isEmpty ? const Icon(Icons.group, color: textColor) : null,
                ),
                title: Text(g.name, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text(g.lastMessage, style: const TextStyle(color: unselectedItemColor)),
                trailing: Text(
                  DateFormat.Hm().format(g.timeSent),
                  style: const TextStyle(color: unselectedItemColor, fontSize: 12),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        foregroundColor: textColor,
        onPressed: () => Navigator.pushNamed(context, CreateGroupScreen.routeName),
        child: const Icon(Icons.group_add),
      ),
    );
  }
}
