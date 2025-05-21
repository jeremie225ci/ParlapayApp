// lib/feature/group/providers.dart
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/feature/group/repository/group_repository.dart';

/// Estado global de contactos seleccionados para crear un grupo
final selectedGroupContactsProvider = StateProvider<List<Contact>>((_) => []);

/// Proveedor del repositorio de grupos
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
});