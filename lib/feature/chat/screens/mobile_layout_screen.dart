import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';
import 'package:mk_mesenger/feature/call/screens/call_history_tab.dart';
import 'package:mk_mesenger/feature/chat/widgets/contacts_list.dart';
import 'package:mk_mesenger/feature/group/screens/create_group_screen.dart';
import 'package:mk_mesenger/feature/group/screens/group_home_screen.dart';
import 'package:mk_mesenger/feature/select_contacts/screens/select_contacts_screen.dart';
import 'package:mk_mesenger/feature/status/screens/confirm_status_screen.dart';
import 'package:mk_mesenger/feature/status/screens/status_contacts_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/wallet_screen.dart';
import 'package:mk_mesenger/feature/settings/screens/settings_screen.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';

class MobileLayoutScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mobile-layout';
  const MobileLayoutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MobileLayoutScreen> createState() => _MobileLayoutScreenState();
}

class _MobileLayoutScreenState extends ConsumerState<MobileLayoutScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void navigateToContactsScreen() {
    Navigator.pushNamed(context, SelectContactsScreen.routeName);
  }

  void navigateToStatusScreen() async {
    final pickedImage = await pickImageFromGallery(context);
    if (pickedImage != null) {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        ConfirmStatusScreen.routeName,
        arguments: pickedImage,
      );
    }
  }

  void navigateToCreateGroupScreen() {
    Navigator.pushNamed(context, CreateGroupScreen.routeName);
  }
  
  void navigateToSettingsScreen() {
    Navigator.pushNamed(context, SettingsScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF1A1A1A),
        title: Text(
          'ParlaPay',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implementar búsqueda
            },
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: _buildPopupMenuItem(
                  icon: Icons.group,
                  text: 'Crear grupo',
                ),
                onTap: navigateToCreateGroupScreen,
              ),
              PopupMenuItem(
                child: _buildPopupMenuItem(
                  icon: Icons.settings,
                  text: 'Configuración',
                ),
                onTap: navigateToSettingsScreen,
              ),
              PopupMenuItem(
                child: _buildPopupMenuItem(
                  icon: Icons.logout,
                  text: 'Cerrar sesión',
                ),
                onTap: () => ref.read(authControllerProvider).signOut(),
              ),
            ],
          ),
        ],
      ),
      body: _buildCurrentBody(),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentBody() {
    switch (_currentIndex) {
      case 0:
        return const ContactsList();
      case 1:
        return const GroupHomeScreen(groupId: '', name: '', profilePic: '');
      case 2:
        return const StatusContactsScreen();
      case 3:
        return const Center(
          child: Text(
            'Historial de llamadas',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        );
      default:
        return const ContactsList();
    }
  }

  Widget _buildPopupMenuItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 0: // Chats
        return FloatingActionButton(
          onPressed: navigateToContactsScreen,
          backgroundColor: Color(0xFF3E63A8),
          child: const Icon(
            Icons.chat,
            color: Colors.white,
          ),
        );
      case 1: // Grupos
        return FloatingActionButton(
          onPressed: navigateToCreateGroupScreen,
          backgroundColor: Color(0xFF3E63A8),
          child: const Icon(
            Icons.group_add,
            color: Colors.white,
          ),
        );
      case 2: // Estados
        return FloatingActionButton(
          onPressed: navigateToStatusScreen,
          backgroundColor: Color(0xFF3E63A8),
          child: const Icon(
            Icons.camera_alt,
            color: Colors.white,
          ),
        );
     case 3:
  return CallHistoryTab();
      default:
        return FloatingActionButton(
          onPressed: navigateToContactsScreen,
          backgroundColor: Color(0xFF3E63A8),
          child: const Icon(
            Icons.chat,
            color: Colors.white,
          ),
        );
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: StreamBuilder<int>(
        stream: ref.watch(chatControllerProvider).unreadChatsCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          
          return BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Color(0xFF3E63A8),
            unselectedItemColor: Colors.grey,
            currentIndex: _currentIndex > 3 ? 3 : _currentIndex,
            onTap: (index) {
              setState(() {
                if (index == 4) { // Wallet (índice 4 es el 5º botón)
                  // Navegar a la pantalla de wallet
                  Navigator.pushNamed(context, WalletScreen.routeName);
                } else {
                  _currentIndex = index;
                }
              });
            },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    Icon(Icons.chat),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Grupos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.photo_camera),
                label: 'Estados',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.call),
                label: 'Llamadas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: 'Wallet',
              ),
            ],
          );
        },
      ),
    );
  }
}