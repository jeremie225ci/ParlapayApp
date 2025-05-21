import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mk_mesenger/common/models/chat_contact.dart';
import 'package:mk_mesenger/common/models/search_result.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';

class ContactsList extends ConsumerStatefulWidget {
  const ContactsList({Key? key}) : super(key: key);

  @override
  ConsumerState<ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends ConsumerState<ContactsList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hasPermission = false;
  List<Contact> _deviceContacts = [];
  bool _isLoadingContacts = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        // Activar modo búsqueda cuando hay texto
        _isSearching = _searchQuery.isNotEmpty;
      });
    });
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceContacts() async {
    try {
      // Verificar permisos de contactos
      _hasPermission = await FlutterContacts.requestPermission();
      
      if (_hasPermission) {
        // Cargar todos los contactos del dispositivo
        _deviceContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
      }
    } catch (e) {
      // En caso de error, manejarlo silenciosamente
      debugPrint('Error al cargar contactos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  // Método para verificar si un número de teléfono está en la agenda
  bool _isContactInAddressBook(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty || !_hasPermission) {
      return false;
    }
    
    // Normalizar el número quitando espacios, '+', etc.
    final String normalizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Comparar con los contactos en la agenda
    for (final contact in _deviceContacts) {
      for (final phone in contact.phones) {
        final String contactPhone = phone.number.replaceAll(RegExp(r'[^0-9]'), '');
        if (contactPhone.endsWith(normalizedPhone) || normalizedPhone.endsWith(contactPhone)) {
          return true;
        }
      }
    }
    return false;
  }

  // Método para obtener el nombre de un contacto desde la agenda
  String _getContactNameFromAddressBook(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty || !_hasPermission) {
      return phoneNumber ?? '';
    }
    
    // Normalizar el número quitando espacios, '+', etc.
    final String normalizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Buscar el contacto en la agenda
    for (final contact in _deviceContacts) {
      for (final phone in contact.phones) {
        final String contactPhone = phone.number.replaceAll(RegExp(r'[^0-9]'), '');
        if (contactPhone.endsWith(normalizedPhone) || normalizedPhone.endsWith(contactPhone)) {
          return contact.displayName;
        }
      }
    }
    return phoneNumber;
  }

  // Formatear fecha/hora para resultados de búsqueda
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat.Hm().format(dateTime); // Hoy: hora:minuto
    } else if (messageDate == yesterday) {
      return 'Ayer'; // Ayer
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat.E().format(dateTime); // Día de la semana
    } else {
      return DateFormat.yMd().format(dateTime); // Fecha completa
    }
  }

  // Método para mostrar opciones de un chat (anclado/destacado)
  void _showContactOptions(BuildContext context, ChatContact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  contact.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white,
                ),
                title: Text(
                  contact.isPinned ? 'Quitar de destacados' : 'Agregar a destacados',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(chatControllerProvider)
                      .togglePinnedChat(contact.contactId, !contact.isPinned);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Eliminar conversación',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  // Implementar eliminación de conversación
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        image: DecorationImage(
          image: AssetImage('assets/images/chat_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.03,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Sección de búsqueda
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Color(0xFF333333)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar conversaciones...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[500]),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              
              // Si hay una búsqueda activa, mostrar resultados de búsqueda
              if (_isSearching)
                _buildSearchResults(ref)
              else
                Column(
                  children: [
                    // Sección de chats destacados
                    StreamBuilder<List<ChatContact>>(
                      stream: ref.watch(chatControllerProvider).chatContacts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingContacts) {
                          return SizedBox();
                        }
                        
                        final contacts = snapshot.data ?? [];
                        return _buildFeaturedChatsSection(contacts);
                      },
                    ),
                    
                    // Lista de contactos
                    _buildContactsSection(ref),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedChatsSection(List<ChatContact> allContacts) {
    // Filtrar solo los contactos destacados/anclados
    final pinnedContacts = allContacts
        .where((contact) => contact.isPinned)
        .toList()
      ..sort((a, b) => a.pinnedOrder.compareTo(b.pinnedOrder));
    
    // Si no hay contactos destacados, no mostrar la sección
    if (pinnedContacts.isEmpty) {
      return SizedBox();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Destacados',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pinnedContacts.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final contact = pinnedContacts[index];
              return _buildPinnedContactItem(contact);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedContactItem(ChatContact contact) {
    final displayName = _isContactInAddressBook(contact.phoneNumber)
        ? _getContactNameFromAddressBook(contact.phoneNumber)
        : contact.phoneNumber ?? '';
    
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          MobileChatScreen.routeName,
          arguments: {
            'name': displayName,
            'uid': contact.contactId,
            'isGroupChat': contact.isGroup,
            'profilePic': contact.profilePic,
          },
        );
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
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
                    backgroundImage: contact.profilePic.isNotEmpty
                        ? NetworkImage(contact.profilePic)
                        : null,
                    backgroundColor: contact.profilePic.isEmpty ? Color(0xFF3E63A8) : null,
                    radius: 26,
                    child: contact.profilePic.isEmpty
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                if (contact.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        contact.unreadCount.toString(),
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
            SizedBox(height: 4),
            Text(
              displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(WidgetRef ref) {
    return StreamBuilder<List<SearchResult>>(
      stream: ref.watch(chatControllerProvider).searchMessages(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                color: Color(0xFF3E63A8),
              ),
            ),
          );
        }
        
        final results = snapshot.data ?? [];
        
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30),
                Icon(
                  Icons.search_off,
                  size: 70,
                  color: Colors.grey[700],
                ),
                SizedBox(height: 16),
                Text(
                  'No se encontraron resultados para "$_searchQuery"',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Resultados de búsqueda',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (context, index) {
                return _buildSearchResultItem(results[index]);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    // Para resultados de búsqueda, usamos phoneNumber si está disponible
    final displayName = _isContactInAddressBook(result.phoneNumber)
        ? _getContactNameFromAddressBook(result.phoneNumber)
        : result.phoneNumber ?? result.contactName; // Usar phoneNumber o contactName como respaldo
    
    // Crear un RichText para destacar la palabra buscada
    final snippet = result.snippet;
    final matchIndex = snippet.toLowerCase().indexOf(_searchQuery.toLowerCase());
    
    Widget snippetWidget;
    
    if (matchIndex >= 0) {
      // La palabra buscada está en el snippet, resaltarla
      final beforeMatch = snippet.substring(0, matchIndex);
      final match = snippet.substring(matchIndex, matchIndex + _searchQuery.length);
      final afterMatch = snippet.substring(matchIndex + _searchQuery.length);
      
      snippetWidget = RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
          children: [
            TextSpan(text: beforeMatch),
            TextSpan(
              text: match,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                backgroundColor: Color(0xFF3E63A8).withOpacity(0.3),
              ),
            ),
            TextSpan(text: afterMatch),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // Si por alguna razón no podemos encontrar la coincidencia en el snippet
      snippetWidget = Text(
        snippet,
        style: TextStyle(color: Colors.grey[400], fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          MobileChatScreen.routeName,
          arguments: {
            'name': displayName,
            'uid': result.contactId,
            'isGroupChat': result.isGroup,
            'profilePic': result.contactProfilePic,
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: result.contactProfilePic.isNotEmpty
                    ? NetworkImage(result.contactProfilePic)
                    : null,
                backgroundColor: result.contactProfilePic.isEmpty ? Color(0xFF3E63A8) : null,
                radius: 24,
                child: result.contactProfilePic.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Indicador de enviado/recibido
                        Icon(
                          result.isSentByMe ? Icons.north_east : Icons.south_west,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        // Snippet con palabra resaltada
                        Expanded(child: snippetWidget),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatDateTime(result.timeSent),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsSection(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Conversaciones recientes',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        StreamBuilder<List<ChatContact>>(
          stream: ref.watch(chatControllerProvider).chatContacts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _isLoadingContacts) {
              return const Loader();
            }
            
            if (snapshot.data == null || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 30),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 70,
                      color: Colors.grey[700],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay conversaciones aún',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Toca el botón + para iniciar un chat',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // No filtrar contactos anclados aquí, mostrar todos ordenados
            final allContacts = snapshot.data!;
            
            // Si la lista está vacía después de filtrar
            if (allContacts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 70, color: Colors.grey[700]),
                    SizedBox(height: 16),
                    Text(
                      'No se encontraron resultados para "$_searchQuery"',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: allContacts.length,
              itemBuilder: (context, index) {
                var chatContactData = allContacts[index];
                return _buildContactTile(context, chatContactData);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactTile(BuildContext context, ChatContact contact) {
    // Determinar qué mostrar: nombre desde la agenda o número de teléfono
    final String displayName = _isContactInAddressBook(contact.phoneNumber)
        ? _getContactNameFromAddressBook(contact.phoneNumber)
        : contact.phoneNumber ?? '';
    
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          MobileChatScreen.routeName,
          arguments: {
            'name': displayName, // Usar el nombre correcto
            'uid': contact.contactId,
            'isGroupChat': contact.isGroup,
            'profilePic': contact.profilePic,
          },
        );
      },
      onLongPress: () {
        _showContactOptions(context, contact);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              // Avatar con indicador de anclado
              Stack(
                children: [
                  // Avatar del contacto
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFF3E63A8), width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundImage: contact.profilePic.isNotEmpty
                              ? NetworkImage(contact.profilePic)
                              : null,
                          backgroundColor: contact.profilePic.isEmpty ? Color(0xFF3E63A8) : null,
                          radius: 24,
                          child: contact.profilePic.isEmpty
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // Indicador de estado (online/offline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(0xFF1A1A1A),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Indicador de contacto anclado/destacado
                  if (contact.isPinned)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Color(0xFF3E63A8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFF1A1A1A), width: 1),
                        ),
                        child: Icon(
                          Icons.push_pin,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Información del contacto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName, // Usar displayName en lugar de contact.name
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: contact.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: contact.unreadCount > 0 ? Colors.white : Colors.grey[400],
                        fontSize: 13,
                        fontWeight: contact.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              // Hora y contador de mensajes
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat.Hm().format(contact.timeSent),
                    style: TextStyle(
                      color: contact.unreadCount > 0 ? Color(0xFF3E63A8) : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: contact.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Contador de mensajes no leídos
                  contact.unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFF3E63A8),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            contact.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox(height: 16), // Espacio para mantener la alineación
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}