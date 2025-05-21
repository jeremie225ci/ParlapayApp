import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/group/controller/group_controller.dart';
import 'package:mk_mesenger/feature/select_contacts/controller/select_contact_controller.dart';
import 'package:mk_mesenger/common/models/user_model.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create-group';

  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController groupNameController = TextEditingController();
  final TextEditingController groupDescriptionController = TextEditingController();
  File? image;
  List<UserModel> selectedContacts = [];
  bool isLoading = false;

  @override
  void dispose() {
    groupNameController.dispose();
    groupDescriptionController.dispose();
    super.dispose();
  }

  void selectImage() async {
    image = await pickImageFromGallery(context);
    setState(() {});
  }

  void createGroup() {
    if (groupNameController.text.trim().isEmpty) {
      showSnackBar(context: context, content: 'Por favor, ingresa un nombre para el grupo');
      return;
    }

    if (selectedContacts.isEmpty) {
      showSnackBar(context: context, content: 'Por favor, selecciona al menos un contacto');
      return;
    }

    setState(() => isLoading = true);
    
    // Generar un ID único para el grupo
    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Extraer solo los IDs de los usuarios seleccionados
    final selectedUserIds = selectedContacts.map((contact) => contact.uid).toList();
    
    ref.read(groupControllerProvider).createGroup(
          context,
          groupId,
          groupNameController.text.trim(),
          image,
          selectedUserIds,
        );
  }

  void toggleSelectContact(UserModel contact) {
    if (selectedContacts.contains(contact)) {
      setState(() {
        selectedContacts.remove(contact);
      });
    } else {
      setState(() {
        selectedContacts.add(contact);
      });
    }
  }

  Widget _buildContactTile(dynamic userData) {
    final user = userData as UserModel;
    final isSelected = selectedContacts.contains(user);
    
    return InkWell(
      onTap: () => toggleSelectContact(user),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: accentColor)
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: user.profilePic.isNotEmpty
                  ? NetworkImage(user.profilePic)
                  : null,
              backgroundColor: user.profilePic.isEmpty ? accentColor : null,
              radius: 20,
              child: user.profilePic.isEmpty
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
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
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (user.phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.phoneNumber,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.grey[700],
                border: Border.all(
                  color: isSelected ? accentColor : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Crear grupo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: createGroup,
            child: Text(
              'Crear',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Loader()
          : Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                image: DecorationImage(
                  image: AssetImage('assets/images/chat_bg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.03,
                ),
              ),
              child: Column(
                children: [
                  // Sección de información del grupo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Imagen del grupo
                        Stack(
                          children: [
                            image != null
                                ? CircleAvatar(
                                    backgroundImage: FileImage(image!),
                                    radius: 50,
                                  )
                                : CircleAvatar(
                                    backgroundColor: accentColor.withOpacity(0.2),
                                    radius: 50,
                                    child: Icon(
                                      Icons.group,
                                      color: accentColor,
                                      size: 50,
                                    ),
                                  ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: selectImage,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: backgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Campo de nombre del grupo
                        Container(
                          decoration: BoxDecoration(
                            color: inputBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: inputBorderColor),
                          ),
                          child: TextField(
                            controller: groupNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Nombre del grupo',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              prefixIcon: Icon(Icons.group, color: Colors.grey[500]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Campo de descripción del grupo
                        Container(
                          decoration: BoxDecoration(
                            color: inputBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: inputBorderColor),
                          ),
                          child: TextField(
                            controller: groupDescriptionController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Descripción del grupo (opcional)',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                child: Icon(Icons.description, color: Colors.grey[500]),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Lista de contactos
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar contactos',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ref.watch(getContactsProvider).when(
                                  data: (userList) {
                                    return ListView.builder(
                                      itemCount: userList.length,
                                      itemBuilder: (context, index) {
                                        final userData = userList[index];
                                        return _buildContactTile(userData);
                                      },
                                    );
                                  },
                                  error: (err, trace) {
                                    return Center(
                                      child: Text(
                                        'Error al cargar contactos: $err',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  },
                                  loading: () => const Loader(),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
