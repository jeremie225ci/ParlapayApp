import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/group.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/group/controller/group_controller.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  static const String routeName = '/group-info';
  final String groupId;

  const GroupInfoScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isEditing = false;
  late TextEditingController nameController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    nameController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _toggleEditing(Group group) {
    if (isEditing) {
      // Guardar cambios
      if (nameController.text.trim().isNotEmpty &&
          (nameController.text.trim() != group.name ||
              descriptionController.text.trim() != (group.groupDescription ?? ''))) {
        ref.read(groupControllerProvider).updateGroupInfo(
              context,
              group.groupId,
              nameController.text.trim(),
              descriptionController.text.trim(),
              null, // profilePic
            );
      }
    } else {
      // Iniciar edición
      nameController.text = group.name;
      descriptionController.text = group.groupDescription ?? '';
    }

    setState(() {
      isEditing = !isEditing;
    });
  }

  void _leaveGroup(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          '¿Abandonar grupo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Si abandonas este grupo, ya no recibirás mensajes de este grupo.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(groupControllerProvider).leaveGroup(
                    context,
                    group.groupId,
                    ref.read(authControllerProvider).user.uid,
                  );
            },
            child: Text(
              'Abandonar',
              style: TextStyle(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: StreamBuilder<Group>(
        stream: ref.read(groupControllerProvider).getGroupById(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'No se pudo cargar la información del grupo',
                style: TextStyle(color: textColor),
              ),
            );
          }

          final group = snapshot.data!;
          final currentUserId = ref.read(authControllerProvider).user.uid;
          final isAdmin = group.admin == currentUserId;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: appBarColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagen de grupo
                        group.groupPic.isNotEmpty
                            ? Image.network(
                                group.groupPic,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: accentColor.withOpacity(0.2),
                                  child: Icon(
                                    Icons.group,
                                    size: 80,
                                    color: accentColor,
                                  ),
                                ),
                              )
                            : Container(
                                color: accentColor.withOpacity(0.2),
                                child: Icon(
                                  Icons.group,
                                  size: 80,
                                  color: accentColor,
                                ),
                              ),
                        
                        // Gradiente oscuro para mejorar legibilidad
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (isAdmin)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEditing ? Icons.check : Icons.edit,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () => _toggleEditing(group),
                      ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                      onPressed: () {
                        // Mostrar menú de opciones
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del grupo
                        if (isEditing) ...[
                          TextField(
                            controller: nameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Nombre del grupo',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: inputBorderColor),
                              ),
                              filled: true,
                              fillColor: inputBackgroundColor,
                            ),
                          ),
                        ] else ...[
                          Text(
                            group.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        
                        // Información del grupo
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Grupo · ${group.membersUid.length} participantes',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Descripción del grupo
                        if (isEditing) ...[
                          TextField(
                            controller: descriptionController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Descripción del grupo (opcional)',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: inputBorderColor),
                              ),
                              filled: true,
                              fillColor: inputBackgroundColor,
                            ),
                          ),
                        ] else if (group.groupDescription != null && group.groupDescription!.isNotEmpty) ...[
                          Text(
                            group.groupDescription!,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Sin descripción',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: accentColor,
                      labelColor: accentColor,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: 'PARTICIPANTES'),
                        Tab(text: 'MEDIOS'),
                        Tab(text: 'AJUSTES'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Pestaña de participantes
                _buildMembersTab(group, isAdmin),
                
                // Pestaña de medios compartidos
                _buildMediaTab(),
                
                // Pestaña de ajustes
                _buildSettingsTab(group),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersTab(Group group, bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.membersUid.length + 1, // +1 para el botón de añadir
      itemBuilder: (context, index) {
        if (index == 0) {
          // Botón de añadir participantes
          return InkWell(
            onTap: isAdmin
                ? () {
                    // Implementar añadir participantes
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isAdmin ? accentColor.withOpacity(0.2) : cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isAdmin
                    ? Border.all(color: accentColor)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin ? accentColor : Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Añadir participantes',
                    style: TextStyle(
                      color: isAdmin ? Colors.white : Colors.grey[500],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Mostrar miembros
        final memberId = group.membersUid[index - 1];
        final isCurrentUser = memberId == ref.read(authControllerProvider).user.uid;
        
        return FutureBuilder<UserModel?>(
          future: ref.read(authControllerProvider).getUserById(memberId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[700],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  'Usuario desconocido',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              );
            }
            
            final member = snapshot.data!;
            final isGroupAdmin = group.admin == member.uid;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: member.profilePic.isNotEmpty
                        ? NetworkImage(member.profilePic)
                        : null,
                    backgroundColor: member.profilePic.isEmpty ? accentColor : null,
                    radius: 20,
                    child: member.profilePic.isEmpty
                        ? Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isCurrentUser ? '${member.name} (Tú)' : member.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (isGroupAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (member.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            member.phoneNumber,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isAdmin && !isCurrentUser)
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Text(
                            isGroupAdmin ? 'Quitar admin' : 'Hacer admin',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            // Implementar cambio de admin
                          },
                        ),
                        PopupMenuItem(
                          child: Text(
                            'Eliminar del grupo',
                            style: TextStyle(color: errorColor),
                          ),
                          onTap: () {
                            // Implementar eliminación de miembro
                          },
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaTab() {
    // Simulación de medios compartidos
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fotos y videos',
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: index == 8
                      ? Center(
                          child: Text(
                            'Ver más',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            index % 3 == 0 ? Icons.image : Icons.video_file,
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(Group group) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notificaciones
          _buildSettingsSection(
            title: 'Notificaciones',
            children: [
              _buildSettingsSwitchTile(
                icon: Icons.notifications,
                title: 'Notificaciones de mensajes',
                subtitle: 'Recibir notificaciones de este grupo',
                value: true,
                onChanged: (value) {
                  // Implementar cambio de notificaciones
                },
              ),
              _buildSettingsSwitchTile(
                icon: Icons.vibration,
                title: 'Vibración',
                subtitle: 'Vibrar al recibir mensajes',
                value: true,
                onChanged: (value) {
                  // Implementar cambio de vibración
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Privacidad
          _buildSettingsSection(
            title: 'Privacidad',
            children: [
              _buildSettingsSwitchTile(
                icon: Icons.lock,
                title: 'Grupo privado',
                subtitle: 'Solo los administradores pueden añadir participantes',
                value: false,
                onChanged: (value) {
                  // Implementar cambio de privacidad
                },
              ),
              _buildSettingsSwitchTile(
                icon: Icons.message,
                title: 'Solo admins pueden enviar mensajes',
                subtitle: 'Solo los administradores pueden enviar mensajes al grupo',
                value: false,
                onChanged: (value) {
                  // Implementar cambio de permisos de mensajes
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Acciones
          _buildSettingsSection(
            title: 'Acciones',
            children: [
              _buildSettingsActionTile(
                icon: Icons.delete_outline,
                title: 'Borrar chat',
                subtitle: 'Eliminar todos los mensajes',
                onTap: () {
                  // Implementar borrado de chat
                },
              ),
              _buildSettingsActionTile(
                icon: Icons.report,
                title: 'Reportar grupo',
                subtitle: 'Reportar contenido inapropiado',
                onTap: () {
                  // Implementar reporte de grupo
                },
              ),
              _buildSettingsActionTile(
                icon: Icons.exit_to_app,
                title: 'Abandonar grupo',
                subtitle: 'Salir de este grupo',
                textColor: errorColor,
                onTap: () => _leaveGroup(group),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (textColor ?? accentColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: textColor ?? accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: cardColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
