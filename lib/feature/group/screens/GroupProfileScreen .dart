import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/group.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/group/controller/group_controller.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';

class GroupProfileScreen extends ConsumerWidget {
  final String groupId;
  final String name;
  final String profilePic;

  const GroupProfileScreen({
    Key? key,
    required this.groupId,
    required this.name,
    required this.profilePic,
  }) : super(key: key);

  void makeGroupCall(WidgetRef ref, BuildContext context) {
    ref.read(callControllerProvider).makeCall(
          context,
          name,
          groupId,
          profilePic,
          true,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: StreamBuilder<Group>(
        stream: ref.read(groupControllerProvider).getGroupById(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }
          
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'No se pudo cargar el grupo',
                style: TextStyle(color: textColor),
              ),
            );
          }
          
          final group = snapshot.data!;
          
          return CustomScrollView(
            slivers: [
              // App Bar con imagen de grupo
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: appBarColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo con gradiente
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: backgroundGradient,
                          ),
                        ),
                      ),
                      
                      // Imagen de grupo
                      Positioned.fill(
                        child: group.groupPic.isNotEmpty
                            ? Image.network(
                                group.groupPic,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: accentColor.withOpacity(0.2),
                                  child: Icon(
                                    Icons.group,
                                    size: 100,
                                    color: accentColor,
                                  ),
                                ),
                              )
                            : Container(
                                color: accentColor.withOpacity(0.2),
                                child: Icon(
                                  Icons.group,
                                  size: 100,
                                  color: accentColor,
                                ),
                              ),
                      ),
                      
                      // Gradiente oscuro en la parte inferior para mejorar legibilidad
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
                      
                      // Nombre del grupo
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${group.membersUid.length} miembros',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                    onPressed: () {
                      // Implementar edición de grupo
                    },
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
                      // Implementar menú de opciones
                    },
                  ),
                ],
              ),
              
              // Contenido del perfil de grupo
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.chat,
                            label: 'Mensaje',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                MobileChatScreen.routeName,
                                arguments: {
                                  'name': group.name,
                                  'uid': group.groupId,
                                  'isGroupChat': true,
                                  'profilePic': group.groupPic,
                                },
                              );
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.call,
                            label: 'Llamada',
                            onTap: () {
                              // Implementar llamada de grupo
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.video_call,
                            label: 'Video',
                            onTap: () => makeGroupCall(ref, context),
                          ),
                          _buildActionButton(
                            icon: Icons.person_add,
                            label: 'Invitar',
                            onTap: () {
                              // Implementar invitación
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Descripción del grupo
                      _buildInfoSection(
                        title: 'Información',
                        children: [
                          _buildInfoItem(
                            icon: Icons.info_outline,
                            title: 'Descripción',
                            subtitle: group.groupDescription ?? 'Sin descripción',
                          ),
                          _buildInfoItem(
                            icon: Icons.calendar_today,
                            title: 'Creado',
                            subtitle: 'Hace 2 días', // Simulado
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Miembros del grupo
                      _buildInfoSection(
                        title: 'Miembros',
                        children: [
                          _buildMembersList(group),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Medios compartidos
                      _buildInfoSection(
                        title: 'Medios compartidos',
                        children: [
                          _buildMediaGrid(),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Opciones adicionales
                      _buildInfoSection(
                        title: 'Opciones',
                        children: [
                          _buildOptionItem(
                            icon: Icons.notifications_off,
                            title: 'Silenciar notificaciones',
                            color: Colors.white,
                            onTap: () {
                              // Implementar silenciar
                            },
                          ),
                          _buildOptionItem(
                            icon: Icons.exit_to_app,
                            title: 'Abandonar grupo',
                            color: errorColor,
                            onTap: () {
                              // Implementar salir del grupo
                            },
                          ),
                          _buildOptionItem(
                            icon: Icons.report,
                            title: 'Reportar grupo',
                            color: errorColor,
                            onTap: () {
                              // Implementar reporte
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(Group group) {
    // Simulación de miembros
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: group.membersUid.length > 5 ? 6 : group.membersUid.length,
      itemBuilder: (context, index) {
        if (index == 5 && group.membersUid.length > 5) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                'Ver todos los miembros (${group.membersUid.length})',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor.withOpacity(0.2),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      index == 0 ? 'Administrador' : 'Miembro',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (index == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid() {
    // Simulación de medios compartidos
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: index == 5
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
                    index % 2 == 0 ? Icons.image : Icons.video_file,
                    color: Colors.grey[400],
                    size: 30,
                  ),
                ),
        );
      },
    );
  }
}
