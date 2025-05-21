import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/utils/utils.dart';

final selectContactsRepositoryProvider = Provider(
  (ref) => SelectContactRepository(
    firestore: FirebaseFirestore.instance,
  ),
);

class SelectContactRepository {
  final FirebaseFirestore firestore;

  SelectContactRepository({
    required this.firestore,
  });

  Future<List<Contact>> getContacts() async {
    List<Contact> contacts = [];
    try {
      if (await FlutterContacts.requestPermission()) {
        contacts = await FlutterContacts.getContacts(withProperties: true);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return contacts;
  }

  void selectContact(Contact selectedContact, BuildContext context) async {
  try {
    var userCollection = await firestore.collection('users').get();
    bool isFound = false;

    for (var document in userCollection.docs) {
      var userData = UserModel.fromMap(document.data());
      String selectedPhoneNum = selectedContact.phones[0].number.replaceAll(
        ' ',
        '',
      );
      if (selectedPhoneNum == userData.phoneNumber) {
        isFound = true;
        // Usar el nombre del contacto local
        final contactName = selectedContact.displayName;
        
        Navigator.pushNamed(
          context,
          MobileChatScreen.routeName,
          arguments: {
            'name': contactName,
            'uid': userData.uid,
            'isGroupChat': false,
            'profilePic': userData.profilePic,
            'phoneNumber': userData.phoneNumber, // Añadir número de teléfono
          },
        );
      }
    }

    if (!isFound) {
      showSnackBar(
        context: context,
        content: 'Este número no existe en esta aplicación.',
      );
    }
  } catch (e) {
    showSnackBar(context: context, content: e.toString());
  }
}
}