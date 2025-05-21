import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/widgets/error.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/select_contacts/controller/select_contact_controller.dart';

class SelectContactsScreen extends ConsumerWidget {
  static const String routeName = '/select-contacts';
  const SelectContactsScreen({Key? key}) : super(key: key);

  void selectContact(
    BuildContext context,
    WidgetRef ref,
    Contact selectedContact,
  ) {
    ref
        .read(selectContactControllerProvider)
        .selectContact(selectedContact, context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Seleccionar contacto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Implementar búsqueda
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              // Implementar filtro
            },
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
        ],
      ),
      body: ref.watch(getContactsProvider).when(
            data: (contactList) => _buildContactsList(context, ref, contactList),
            error: (err, trace) => ErrorScreen(error: err.toString()),
            loading: () => const Loader(),
          ),
    );
  }

  Widget _buildContactsList(
    BuildContext context,
    WidgetRef ref,
    List<Contact> contactList,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        image: DecorationImage(
          image: AssetImage('assets/images/chat_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.03,
        ),
      ),
      child: Column(
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
                  hintText: 'Buscar contactos...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Sección de acciones rápidas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildQuickActionButton(
                  icon: Icons.group,
                  label: 'Nuevo grupo',
                  onTap: () {
                    // Implementar creación de grupo
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.person_add,
                  label: 'Nuevo contacto',
                  onTap: () {
                    // Implementar añadir contacto
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.qr_code,
                  label: 'Escanear QR',
                  onTap: () {
                    // Implementar escaneo QR
                  },
                ),
              ],
            ),
          ),
          
          // Separador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Contactos en ParlaPay',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
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
                    '${contactList.length}',
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
          
          // Lista de contactos
          Expanded(
            child: ListView.builder(
              itemCount: contactList.length,
              itemBuilder: (context, index) {
                final contact = contactList[index];
                return _buildContactTile(context, ref, contact);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Color(0xFF3E63A8),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) {
    final displayName = contact.displayName;
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    
    return InkWell(
      onTap: () => selectContact(context, ref, contact),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              // Avatar del contacto
              Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF3E63A8), width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: Color(0xFF2A2A2A),
                  radius: 22,
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del contacto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (contact.phones.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contact.phones.first.number,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Icono de chat
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF3E63A8).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat,
                  color: Color(0xFF3E63A8),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
