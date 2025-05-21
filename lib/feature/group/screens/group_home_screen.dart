import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/group.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/group/controller/group_controller.dart';

import 'package:mk_mesenger/feature/group/screens/create_group_screen.dart';
import 'package:mk_mesenger/feature/group/screens/group_info_screen.dart';
import 'package:mk_mesenger/feature/chat/widgets/bottom_chat_field.dart';
import 'package:mk_mesenger/feature/group/widgets/bottom_chat_fieeld_group.dart';
import 'package:mk_mesenger/feature/group/widgets/chat_list_group.dart';
import 'package:mk_mesenger/feature/group/widgets/event_history_screen.dart';
import 'package:mk_mesenger/feature/group/widgets/record_funds_tab.dart';
import 'package:mk_mesenger/feature/group/widgets/marketplace_tabs.dart';
import 'package:intl/intl.dart';

class GroupHomeScreen extends ConsumerStatefulWidget {
  static const String routeName = '/group-home';

  final String groupId;
  final String name;
  final String profilePic;

  const GroupHomeScreen({
    Key? key,
    required this.groupId,
    required this.name,
    required this.profilePic,
  }) : super(key: key);

  @override
  ConsumerState<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends ConsumerState<GroupHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Mis Grupos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implementar búsqueda de grupos
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              // Implementar filtrado de grupos
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFF121212),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.03,
          ),
        ),
        child: StreamBuilder<List<Group>>(
          stream: ref.watch(groupControllerProvider).chatGroups(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF3E63A8),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyGroupsState(context);
            }
            
            return _buildGroupsList(context, snapshot.data!);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, CreateGroupScreen.routeName);
        },
        backgroundColor: Color(0xFF3E63A8),
        child: const Icon(
          Icons.group_add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyGroupsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFF3E63A8).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_outlined,
              color: Color(0xFF3E63A8),
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes grupos aún',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Crea un grupo para chatear con varias personas a la vez',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, CreateGroupScreen.routeName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3E63A8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Crear un grupo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context, List<Group> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sección de búsqueda
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Color(0xFF333333)),
            ),
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar grupos...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        
        // Sección de grupos destacados
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Grupos destacados',
            style: TextStyle(
              color: Color(0xFF3E63A8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Lista horizontal de grupos destacados
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length > 5 ? 5 : groups.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildFeaturedGroupItem(context, group);
            },
          ),
        ),
        
        // Separador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Text(
                'Todos los grupos',
                style: TextStyle(
                  color: Color(0xFF3E63A8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF3E63A8).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${groups.length}',
                  style: TextStyle(
                    color: Color(0xFF3E63A8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Lista de todos los grupos
        Expanded(
          child: ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildGroupTile(context, group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedGroupItem(BuildContext context, Group group) {
    return GestureDetector(
      onTap: () {
        _navigateToGroupChat(context, group);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF3E63A8),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                backgroundImage: group.groupPic.isNotEmpty
                    ? NetworkImage(group.groupPic)
                    : null,
                backgroundColor: group.groupPic.isEmpty ? Color(0xFF3E63A8) : null,
                radius: 30,
                child: group.groupPic.isEmpty
                    ? Icon(Icons.group, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, Group group) {
    // Formatear la fecha del último mensaje
    String lastMessageTime = '';
    if (group.timeSent != null) {
      // Si el mensaje es de hoy, mostrar solo la hora
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(
        group.timeSent.year, 
        group.timeSent.month, 
        group.timeSent.day
      );
      
      if (messageDate == today) {
        lastMessageTime = DateFormat('HH:mm').format(group.timeSent);
      } else {
        lastMessageTime = DateFormat('dd/MM').format(group.timeSent);
      }
    }

    return InkWell(
      onTap: () {
        _navigateToGroupChat(context, group);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Avatar del grupo
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF3E63A8), width: 2),
                ),
                child: CircleAvatar(
                  backgroundImage: group.groupPic.isNotEmpty
                      ? NetworkImage(group.groupPic)
                      : null,
                  backgroundColor: group.groupPic.isEmpty ? Color(0xFF3E63A8) : null,
                  radius: 26,
                  child: group.groupPic.isEmpty
                      ? Icon(Icons.group, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // Información del grupo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.grey[400],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.membersUid.length} miembros',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (group.lastMessage != null && group.lastMessage!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.lastMessage!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Hora del último mensaje
              if (lastMessageTime.isNotEmpty)
                Text(
                  lastMessageTime,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              // Botón de opciones
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey[400],
                ),
                onPressed: () {
                  _showGroupOptions(context, group);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para navegar a la pantalla de chat de grupo
  void _navigateToGroupChat(BuildContext context, Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GroupChatScreen(
          groupId: group.groupId,
          name: group.name,
          profilePic: group.groupPic,
        ),
      ),
    );
  }

  void _showGroupOptions(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: group.groupPic.isNotEmpty
                      ? NetworkImage(group.groupPic)
                      : null,
                  backgroundColor: group.groupPic.isEmpty ? Color(0xFF3E63A8) : null,
                  child: group.groupPic.isEmpty
                      ? Icon(Icons.group, color: Colors.white)
                      : null,
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${group.membersUid.length} miembros',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              const Divider(color: Color(0xFF333333)),
              _buildOptionTile(
                icon: Icons.chat,
                title: 'Abrir chat',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToGroupChat(context, group);
                },
              ),
              _buildOptionTile(
                icon: Icons.attach_money,
                title: 'Eventos de financiación',
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de eventos
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordFundsTab(groupId: group.groupId),
                    ),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.history,
                title: 'Historial de eventos',
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de historial de eventos
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventHistoryScreen(groupId: group.groupId),
                    ),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.shopping_bag,
                title: 'Marketplace del grupo',
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de marketplace
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarketplaceTab(groupId: group.groupId),
                    ),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.info_outline,
                title: 'Ver información del grupo',
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de información del grupo
                  Navigator.pushNamed(
                    context, 
                    GroupInfoScreen.routeName,
                    arguments: {'groupId': group.groupId},
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.notifications_off_outlined,
                title: 'Silenciar notificaciones',
                onTap: () {
                  Navigator.pop(context);
                  // Implementar silenciar notificaciones
                },
              ),
              _buildOptionTile(
                icon: Icons.exit_to_app,
                title: 'Abandonar grupo',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveGroupConfirmation(context, group);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Método para mostrar confirmación de abandonar grupo
  void _showLeaveGroupConfirmation(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: const Text(
          '¿Abandonar grupo?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro que quieres abandonar el grupo "${group.name}"? Ya no recibirás mensajes de este grupo.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              // Implementar la función para abandonar el grupo
              Navigator.pop(context);
            },
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
        ),
      ),
      onTap: onTap,
    );
  }
}

// Widget para la pantalla de chat de grupo integrada (modificado para ser similar a MobileChatScreen)
class _GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String name;
  final String profilePic;
  
  const _GroupChatScreen({
    Key? key,
    required this.groupId,
    required this.name,
    required this.profilePic,
  }) : super(key: key);

  @override
  ConsumerState<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<_GroupChatScreen> {
  // Añadimos un estado para la pestaña activa
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.profilePic.isNotEmpty
                  ? NetworkImage(widget.profilePic)
                  : null,
              backgroundColor: widget.profilePic.isEmpty ? Color(0xFF3E63A8) : null,
              radius: 20,
              child: widget.profilePic.isEmpty
                  ? const Icon(Icons.group, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Grupo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.white),
            onPressed: () {
              // Implementar videollamada de grupo
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => EventHistoryScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                GroupInfoScreen.routeName,
                arguments: {
                  'groupId': widget.groupId,
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Contenido principal que cambia según la pestaña seleccionada
          Expanded(
            child: _buildCurrentView(),
          ),
          
          // Campo de chat y barra de navegación
          // Campo de chat y barra de navegación
Column(
  children: [
    // Solo mostrar el campo de chat cuando estamos en la pestaña de chat
    if (_currentIndex == 0)
      BottomChatFieldGroup(
        groupId: widget.groupId,
      ),
    
    // Barra de navegación personalizada
    _buildNavigationBar(),
  ],
),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0: // Chat
        return ChatListGroup(groupId: widget.groupId);
      case 1: // Eventos
        return RecordFundsTab(groupId: widget.groupId);
      case 2: // Marketplace
        return MarketplaceTab(groupId: widget.groupId);
      default:
        return ChatListGroup(groupId: widget.groupId);
    }
  }

  Widget _buildNavigationBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildNavButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: _currentIndex == 0,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          _buildNavButton(
            icon: Icons.attach_money,
            label: 'Evento',
            isActive: _currentIndex == 1,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          _buildNavButton(
            icon: Icons.shopping_bag,
            label: 'Mercado',
            isActive: _currentIndex == 2,
            onTap: () => setState(() => _currentIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Color(0xFF3E63A8) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Color(0xFF3E63A8) : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Color(0xFF3E63A8) : Colors.grey,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}