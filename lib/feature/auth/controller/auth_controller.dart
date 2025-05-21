import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/feature/auth/repository/auth_repository.dart';
import 'package:mk_mesenger/feature/auth/screens/login_screen.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});

final userDataAuthProvider = FutureProvider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).getUserData();
});

class AuthController {
  final AuthRepository authRepository;
  final Ref ref;
  UserModel? _cachedUser;

  AuthController({
    required this.authRepository,
    required this.ref,
  });

  // Getter para acceder al usuario actual
  UserModel get user {
    if (_cachedUser == null) {
      throw Exception('Usuario no inicializado. Llama a getUserData() primero.');
    }
    return _cachedUser!;
  }

  Future<UserModel?> getUserData() async {
    _cachedUser = await authRepository.getCurrentUserData();
    return _cachedUser;
  }

  Future<UserModel?> getUserById(String userId) async {
    // Primero verificamos si es el usuario actual para evitar una llamada innecesaria
    if (_cachedUser != null && _cachedUser!.uid == userId) {
      return _cachedUser;
    }
    
    // Si no es el usuario actual, obtenemos los datos de Firestore
    return await authRepository.getUserById(userId);
  }

  void signInWithPhone(BuildContext context, String phoneNumber) {
    authRepository.signInWithPhone(context, phoneNumber);
  }

  void verifyOTP(BuildContext context, String verificationId, String userOTP) {
    authRepository.verifyOTP(
      context: context,
      verificationId: verificationId,
      userOTP: userOTP,
    );
  }

  void saveUserDataToFirebase(
      BuildContext context, String name, File? profilePic) {
    authRepository.saveUserDataToFirebase(
      name: name,
      profilePic: profilePic,
      ref: ref,
      context: context,
    );
  }

  Stream<UserModel> userDataById(String userId) {
    return authRepository.userData(userId);
  }

  void setUserState(bool isOnline) {
    authRepository.setUserState(isOnline);
  }

  Future<void> signOut() async {
    try {
      // Primero establecer el estado del usuario como offline
      authRepository.setUserState(false);
      
      // Cerrar sesión en Firebase Auth
      await authRepository.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }
}