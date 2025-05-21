// lib/feature/group/widgets/select_contacts_group.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/feature/group/providers.dart';
import 'package:mk_mesenger/feature/select_contacts/controller/select_contact_controller.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/common/utils/widgets/error.dart';

/// Lista de contactos disponibles y seleccionables para el grupo
class SelectContactsGroup extends ConsumerWidget {
  const SelectContactsGroup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allContactsAsync = ref.watch(getContactsProvider);
    final selected = ref.watch(selectedGroupContactsProvider);

    return allContactsAsync.when(
      data: (contacts) => ListView.builder(
        shrinkWrap: true,
        itemCount: contacts.length,
        itemBuilder: (ctx, i) {
          final contact = contacts[i];
          final isSelected = selected.contains(contact);
          return ListTile(
            title: Text(contact.displayName),
            trailing: isSelected ? const Icon(Icons.check_circle) : null,
            onTap: () {
              ref.read(selectedGroupContactsProvider.notifier).update((state) {
                if (isSelected) return [...state]..remove(contact);
                return [...state, contact];
              });
            },
          );
        },
      ),
      loading: () => const Loader(),
      error: (err, _) => ErrorScreen(error: err.toString()),
    );
  }
}