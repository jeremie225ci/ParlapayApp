import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/repositories/common_firebase_storage_repository.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/auth/screens/otp_screen.dart';
import 'package:mk_mesenger/feature/auth/screens/user_information_screen.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_layout_screen.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  ),
);

class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  
  // Caché local del usuario actual para acceso rápido
  UserModel? _currentUser;
  
  AuthRepository({
    required this.auth,
    required this.firestore,
  });
  
  // Método para obtener el usuario actual de forma sincrónica (desde caché si está disponible)
  UserModel? getCurrentUser() {
    return _currentUser;
  }
  
  // Método para obtener un usuario por su ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      var userData = await firestore.collection('users').doc(userId).get();
      if (userData.data() != null) {
        return UserModel.fromMap(userData.data()!);
      }
    } catch (e) {
      print('Error al obtener usuario por ID: $e');
    }
    return null;
  }
  
  Future<void> signOut() async {
    try {
      // Primero establecer estado como offline
      if (auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).update({
          'isOnline': false,
        });
      }
      
      // Guardar el uid actual para usar en limpieza específica
      final currentUid = auth.currentUser?.uid;
      
      // Limpiar caché local
      _currentUser = null;
      
      // Cerrar Firebase Auth
      await auth.signOut();
      
      // Limpiar caché de Firestore para este usuario específico
      if (currentUid != null) {
        try {
          // Eliminar documentos específicos de la caché local
          await firestore.collection('users').doc(currentUid).collection('chats').get().then((snapshot) {
            for (var doc in snapshot.docs) {
              // Solo marcar para eliminar de la caché, no eliminar realmente de Firestore
              firestore.collection('users').doc(currentUid).collection('chats').doc(doc.id);
            }
          });
        } catch (e) {
          print('Error al limpiar caché específica: $e');
        }
      }
      
      // Intenta forzar una recarga de todos los datos
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (e) {
        print('Error al limpiar persistencia: $e');
      }
    } catch (e) {
      print('Error en signOut: $e');
      throw e;
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    try {
      if (auth.currentUser == null) return null;
      
      var userData = await firestore.collection('users').doc(auth.currentUser?.uid).get();

      if (userData.data() != null) {
        _currentUser = UserModel.fromMap(userData.data()!);
        return _currentUser;
      }
    } catch (e) {
      print('Error al obtener datos del usuario actual: $e');
    }
    return null;
  }

  void signInWithPhone(BuildContext context, String phoneNumber) async {
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await auth.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          throw Exception(e.message);
        },
        codeSent: ((String verificationId, int? resendToken) async {
          Navigator.pushNamed(
            context,
            OTPScreen.routeName,
            arguments: {
              'verificationId': verificationId,
              'phoneNumber': phoneNumber,
            },
          );
        }),
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseAuthException catch (e) {
      showSnackBar(context: context, content: e.message!);
    }
  }

  void verifyOTP({
    required BuildContext context,
    required String verificationId,
    required String userOTP,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: userOTP,
      );
      await auth.signInWithCredential(credential);
      Navigator.pushNamedAndRemoveUntil(
        context,
        UserInformationScreen.routeName,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      showSnackBar(context: context, content: e.message!);
    }
  }

  void saveUserDataToFirebase({
    required String name,
    required File? profilePic,
    required Ref ref,
    required BuildContext context,
  }) async {
    try {
      String uid = auth.currentUser!.uid;
      String photoUrl = 'https://png.pngitem.com/pimgs/s/649-6490124_katie-notopoulos-katienotopoulos-i-write-about-tech-round.png';

      if (profilePic != null) {
        photoUrl = await ref
            .read(commonFirebaseStorageRepositoryProvider)
            .storeFileToFirebase(
              'profilePic/$uid',
              profilePic,
            );
      }

      var user = UserModel(
        name: name,
        uid: uid,
        profilePic: photoUrl,
        isOnline: true,
        phoneNumber: auth.currentUser!.phoneNumber!,
        groupId: [],
        status: 'Hola, estoy usando ParlaPay', // Valor por defecto para el estado
      );

      // Actualizar caché local
      _currentUser = user;

      await firestore.collection('users').doc(uid).set(user.toMap());

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MobileLayoutScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  Stream<UserModel> userData(String userId) {
    return firestore.collection('users').doc(userId).snapshots().map(
          (event) {
            var user = UserModel.fromMap(event.data()!);
            // Actualizar caché si es el usuario actual
            if (auth.currentUser?.uid == userId) {
              _currentUser = user;
            }
            return user;
          },
        );
  }

  void setUserState(bool isOnline) async {
    if (auth.currentUser == null) return;
    
    try {
      await firestore.collection('users').doc(auth.currentUser!.uid).update({
        'isOnline': isOnline,
      });
      
      // Actualizar caché local
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isOnline: isOnline);
      }
    } catch (e) {
      print('Error al actualizar estado del usuario: $e');
    }
  }
}
