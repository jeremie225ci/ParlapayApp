// lib/feature/group/widgets/marketplace_tabs.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';
import 'package:mk_mesenger/main.dart';
import 'package:uuid/uuid.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/repositories/common_firebase_storage_repository.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';

final groupAvailableProductsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, groupId) => ref
      .read(marketplaceControllerProvider)
      .getGroupAvailableProducts(groupId),
);

final groupAllSalesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, groupId) => ref
      .read(marketplaceControllerProvider)
      .getAllGroupSales(groupId),
);

// Provider para el controlador del marketplace
final marketplaceControllerProvider = Provider((ref) {
  return MarketplaceController(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
});

class MarketplaceController {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Ref ref;

  MarketplaceController({
    required this.firestore,
    required this.auth,
    required this.ref,
  });

  // Crear un nuevo producto para vender
  Future<bool> createProduct({
    required BuildContext context,
    required String groupId,
    required String title,
    required double price,
    required String description,
    required File? imageFile,
    String? category,
    bool negotiable = false,
  }) async {
    try {
      print('Iniciando creación de producto: $title para grupo: $groupId');
      
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('Error: Usuario no autenticado');
        showSnackBar(context: context, content: 'Usuario no autenticado');
        return false;
      }

      // 1. Crear ID único para el producto
      final productId = const Uuid().v1();
      print('ID de producto generado: $productId');

      // 2. Subir imagen si existe
      String? imageUrl;
      if (imageFile != null) {
        print('Subiendo imagen...');
        imageUrl = await ref
            .read(commonFirebaseStorageRepositoryProvider)
            .storeFileToFirebase(
              'marketplace/$groupId/$productId',
              imageFile,
            );
        print('Imagen subida exitosamente: $imageUrl');
      }

      // 3. Crear el producto en Firestore
      print('Guardando producto en Firestore...');
      final data = {
        'productId': productId,
        'groupId': groupId,
        'sellerId': currentUser.uid,
        'title': title,
        'price': price,
        'description': description,
        'category': category,
        'imageUrl': imageUrl,
        'negotiable': negotiable,
        'status': 'available', // available, reserved, sold
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'interestedUsers': [],
      };
      print('Datos del producto: $data');
      
      await firestore.collection('marketplace_products').doc(productId).set(data);
      print('Producto guardado exitosamente');

      // 4. Crear una notificación en el grupo
     // 4. Crear una notificación en el grupo
    final notificationMsg = '¡Nuevo producto a la venta: $title! 💰 Precio: €$price';
    final messageId = const Uuid().v1();
    
    await firestore.collection('groups').doc(groupId).collection('chats').add({
      'senderId': currentUser.uid,
      'text': notificationMsg,
      'type': 'marketplace_notification',
      'timeSent': FieldValue.serverTimestamp(),
      'messageId': messageId,
      'isSeen': false,
      'repliedMessage': '',
      'repliedTo': '',
      'repliedMessageType': '',
      'productId': productId,
    });
    
    // IMPORTANTE: Actualizar el último mensaje
  
      print('Notificación creada exitosamente');

      showSnackBar(
        context: context, 
        content: 'Producto publicado con éxito'
      );
      return true;
    } catch (e) {
      print('Error al crear producto: $e');
      showSnackBar(context: context, content: 'Error: $e');
      return false;
    }
  }

  // Método mejorado para mostrar interés sin eliminar chats existentes
  Future<bool> showInterest({
    required BuildContext context,
    required String productId,
  }) async {
    try {
      print('Iniciando acción mostrar interés en producto: $productId');
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('Error: Usuario no autenticado');
        showSnackBar(context: context, content: 'Usuario no autenticado');
        return false;
      }

      // 1. Obtener datos del producto
      final productDoc = await firestore.collection('marketplace_products').doc(productId).get();
      if (!productDoc.exists) {
        print('Error: Producto no encontrado');
        showSnackBar(context: context, content: 'Producto no encontrado');
        return false;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final groupId = productData['groupId'];
      final sellerId = productData['sellerId'];
      final title = productData['title'];

      // No permitir mostrar interés en productos propios
      if (sellerId == currentUser.uid) {
        print('Error: Intento de mostrar interés en producto propio');
        showSnackBar(context: context, content: 'No puedes mostrar interés en tus propios productos');
        return false;
      }

      // Verificar si ya mostró interés
      final List<dynamic> interestedUsers = productData['interestedUsers'] ?? [];
      if (interestedUsers.contains(currentUser.uid)) {
        print('Usuario ya mostró interés previamente, abriendo chat directamente');
        // En lugar de mostrar error, podemos simplemente abrir el chat
        return openPrivateChat(context: context, sellerId: sellerId, productTitle: title);
      }

      // 2. Actualizar lista de interesados
      print('Actualizando lista de interesados');
      await firestore.collection('marketplace_products').doc(productId).update({
        'interestedUsers': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Abrir chat privado con el vendedor
      print('Abriendo chat privado');
      return openPrivateChat(context: context, sellerId: sellerId, productTitle: title);
    } catch (e) {
      print('Error al mostrar interés: $e');
      showSnackBar(context: context, content: 'Error: $e');
      return false;
    }
  }

  // Nuevo método para abrir chat privado sin modificar la lista de interesados
  Future<bool> openPrivateChat({
    required BuildContext context, 
    required String sellerId, 
    required String productTitle
  }) async {
    try {
      print('Abriendo chat privado con vendedor: $sellerId sobre producto: $productTitle');
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('Error: Usuario no autenticado');
        showSnackBar(context: context, content: 'Usuario no autenticado');
        return false;
      }

      // Crear ID de chat basado en IDs de usuarios
      String chatId = "";
      if (currentUser.uid.compareTo(sellerId) < 0) {
        chatId = currentUser.uid + "_" + sellerId;
      } else {
        chatId = sellerId + "_" + currentUser.uid;
      }
      print('ID de chat generado: $chatId');

      // Verificar si el chat ya existe
      final currentUserChatDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(chatId)
          .get();

      // Si no existe, crear entrada de chat para ambos usuarios
      if (!currentUserChatDoc.exists) {
        print('Chat no existe, creando nuevo chat');
        // Para el vendedor
        await firestore.collection('users').doc(sellerId).collection('chats').doc(chatId).set({
          'isGroup': false,
          'timeSent': FieldValue.serverTimestamp(),
          'lastMessage': 'Me interesa tu producto: $productTitle',
        });

        // Para el comprador
        await firestore.collection('users').doc(currentUser.uid).collection('chats').doc(chatId).set({
          'isGroup': false,
          'timeSent': FieldValue.serverTimestamp(),
          'lastMessage': 'Me interesa tu producto: $productTitle',
        });

        // Añadir mensaje a la colección de chat
        await firestore.collection('chat').doc(chatId).collection('messages').add({
          'senderId': currentUser.uid,
          'text': 'Hola, estoy interesado en tu producto: "$productTitle". ¿Podemos hablar sobre él?',
          'type': 'text',
          'timeSent': FieldValue.serverTimestamp(),
          'messageId': const Uuid().v1(),
          'isSeen': false,
          'repliedMessage': '',
          'repliedTo': '',
          'repliedMessageType': '',
        });
      } else {
        print('Chat ya existe, abriendo chat existente');
      }

      // Navegar a la pantalla de chat
      if (context.mounted) {
        print('Navegando a pantalla de chat');
        Navigator.pushNamed(
          context, 
          '/mobile-chat', // Ruta a tu pantalla de chat, ajusta según tu app
          arguments: {
            'name': await getUserName(sellerId),
            'uid': sellerId,
            'isGroupChat': false,
            'profilePic': await getUserProfilePic(sellerId),
          },
        );
      }

      return true;
    } catch (e) {
      print('Error al abrir chat privado: $e');
      showSnackBar(context: context, content: 'Error: $e');
      return false;
    }
  }

  // Método auxiliar para obtener nombre de usuario
  Future<String> getUserName(String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['name'] ?? 'Usuario';
      }
      return 'Usuario';
    } catch (e) {
      print('Error al obtener nombre de usuario: $e');
      return 'Usuario';
    }
  }

  // Método auxiliar para obtener foto de perfil
  Future<String> getUserProfilePic(String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['profilePic'] ?? '';
      }
      return '';
    } catch (e) {
      print('Error al obtener foto de perfil: $e');
      return '';
    }
  }

  // Nuevo método para comprar producto directamente
 // Nuevo método para comprar producto directamente
Future<bool> purchaseProduct({
  required BuildContext context,
  required String productId,
}) async {
  try {
    print('====== INICIO DE COMPRA DE PRODUCTO ======');
    
    // 1. Verificación inicial
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      print('Error: Usuario no autenticado');
      return false;
    }
    
    // 2. Obtener datos del producto
    final productDoc = await firestore.collection('marketplace_products').doc(productId).get();
    if (!productDoc.exists) {
      print('Error: Producto no encontrado');
      return false;
    }
    
    final productData = productDoc.data() as Map<String, dynamic>;
    final sellerId = productData['sellerId'];
    final title = productData['title'];
    final price = (productData['price'] as num).toDouble();
    final groupId = productData['groupId'];
    
    // Verificaciones adicionales
    if (sellerId == currentUser.uid || productData['status'] != 'available') {
      return false;
    }
    
    // 3. Realizar el pago usando el walletController pero SIN usar el contexto
    print('Realizando pago...');
    bool success = false;
    
    try {
      // NO PASAR CONTEXT, usar un Future para manejar el resultado
      final walletController = ref.read(walletControllerProvider.notifier);
      success = await Future(() async {
        try {
  return await walletController.sendMoney(sellerId, price, context);
} catch (e) {
  print('Error al intentar usar sendMoney: $e');
  // Verifica en Firestore si la transacción se completó a pesar del error
  final recentTx = await firestore
      .collection('wallets')
      .doc(currentUser.uid)
      .collection('transactions')
      .where('receiverId', isEqualTo: sellerId)
      .where('amount', isEqualTo: -price)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();
      
  return !recentTx.docs.isEmpty;
}
      });
    } catch (e) {
      print('Error en transferencia: $e');
      return false;
    }
    
    // 4. Si la transferencia fue exitosa, actualizar el producto
    if (success) {
      final ts = Timestamp.now();
      final transactionId = const Uuid().v1();
      
      // Marcar producto como vendido
      await firestore.collection('marketplace_products').doc(productId).update({
        'status': 'sold',
        'buyerId': currentUser.uid,
        'soldAt': ts,
        'transactionId': transactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Notificar en el chat del grupo
      await firestore.collection('groups').doc(groupId).collection('chats').add({
        'senderId': currentUser.uid,
        'text': '${currentUser.displayName ?? "Usuario"} ha comprado el producto "${title}" por €${price.toStringAsFixed(2)}',
        'type': 'marketplace_notification',
        'timeSent': FieldValue.serverTimestamp(),
        'messageId': const Uuid().v1(),
        'isSeen': false,
        'repliedMessage': '',
        'repliedTo': '',
        'repliedMessageType': '',
        'productId': productId,
      });
      
      // Chat privado con el vendedor
      String chatId = "";
      if (currentUser.uid.compareTo(sellerId) < 0) {
        chatId = currentUser.uid + "_" + sellerId;
      } else {
        chatId = sellerId + "_" + currentUser.uid;
      }
      
      // Verificar si el chat ya existe
      final currentUserChatDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(chatId)
          .get();

      // Si no existe, crear entrada de chat para ambos usuarios
      if (!currentUserChatDoc.exists) {
        // Para el vendedor
        await firestore.collection('users').doc(sellerId).collection('chats').doc(chatId).set({
          'isGroup': false,
          'timeSent': FieldValue.serverTimestamp(),
          'lastMessage': 'He comprado tu producto: $title',
        });

        // Para el comprador
        await firestore.collection('users').doc(currentUser.uid).collection('chats').doc(chatId).set({
          'isGroup': false,
          'timeSent': FieldValue.serverTimestamp(),
          'lastMessage': 'He comprado tu producto: $title',
        });
      }
      
      // Añadir mensaje a la colección de chat
      await firestore.collection('chat').doc(chatId).collection('messages').add({
        'senderId': currentUser.uid,
        'text': 'He comprado tu producto: "$title" por €${price.toStringAsFixed(2)}. ¡Gracias!',
        'type': 'text',
        'timeSent': FieldValue.serverTimestamp(),
        'messageId': const Uuid().v1(),
        'isSeen': false,
        'repliedMessage': '',
        'repliedTo': '',
        'repliedMessageType': '',
      });
      
      print('====== COMPRA COMPLETADA CON ÉXITO ======');
      return true;
    }
    
    print('La transferencia falló');
    return false;
  } catch (e) {
    print('====== ERROR EN COMPRA DE PRODUCTO ======');
    print('Error detallado: $e');
    return false;
  }
}

  // Marcar producto como vendido
  Future<bool> markAsSold({
    required BuildContext context,
    required String productId,
    String? buyerId, // Si no se especifica, solo se marca como vendido sin comprador
  }) async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        showSnackBar(context: context, content: 'Usuario no autenticado');
        return false;
      }

      // 1. Obtener datos del producto
      final productDoc = await firestore.collection('marketplace_products').doc(productId).get();
      if (!productDoc.exists) {
        showSnackBar(context: context, content: 'Producto no encontrado');
        return false;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final sellerId = productData['sellerId'];
      final groupId = productData['groupId'];

      // Solo el vendedor puede marcar como vendido
      if (sellerId != currentUser.uid) {
        showSnackBar(context: context, content: 'Solo el vendedor puede marcar el producto como vendido');
        return false;
      }

      // 2. Actualizar estado del producto
      final updateData = {
        'status': 'sold',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (buyerId != null) {
        updateData['buyerId'] = buyerId;
      }
      
      await firestore.collection('marketplace_products').doc(productId).update(updateData);

      // 3. Crear una notificación en el grupo
      final title = productData['title'];
      await firestore.collection('groups').doc(groupId).collection('chats').add({
        'senderId': currentUser.uid,
        'text': 'El producto "$title" ha sido vendido.',
        'type': 'marketplace_notification',
        'timeSent': FieldValue.serverTimestamp(),
        'messageId': const Uuid().v1(),
        'isSeen': false,
        'repliedMessage': '',
        'repliedTo': '',
        'repliedMessageType': '',
        'productId': productId,
      });

      showSnackBar(
        context: context, 
        content: 'Producto marcado como vendido'
      );
      return true;
    } catch (e) {
      showSnackBar(context: context, content: 'Error: $e');
      return false;
    }
  }

  // Obtener productos disponibles de un grupo
  Stream<List<Map<String, dynamic>>> getGroupAvailableProducts(String groupId) {
    print('Consultando productos disponibles para el grupo: $groupId');
    
    return firestore
        .collection('marketplace_products')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Productos encontrados: ${snapshot.docs.length}');
          
          return snapshot.docs.map((doc) {
            final data = doc.data();
            
            // Asegurarnos de manejar correctamente el timestamp
            DateTime createdAt;
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            } else {
              createdAt = DateTime.now();
              print('Warning: createdAt no es un Timestamp para el producto: ${data['productId']}');
            }
            
            return {
              ...data,
              'createdAt': createdAt,
            };
          }).toList();
        });
  }

  // Obtener productos vendidos de un grupo
  Stream<List<Map<String, dynamic>>> getGroupSoldProducts(String groupId) {
    return firestore
        .collection('marketplace_products')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'sold')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'updatedAt': data['updatedAt']?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Obtener productos del usuario actual
  Stream<List<Map<String, dynamic>>> getAllGroupSales(String groupId) {
    print('Consultando todas las ventas del grupo: $groupId');
    
    return firestore
        .collection('marketplace_products')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Ventas totales encontradas: ${snapshot.docs.length}');
          
          return snapshot.docs.map((doc) {
            final data = doc.data();
            
            // Asegurarnos de manejar correctamente el timestamp
            DateTime createdAt;
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            } else {
              createdAt = DateTime.now();
            }
            
            return {
              ...data,
              'createdAt': createdAt,
            };
          }).toList();
        });
  }

  // Obtener detalles de un producto específico
  Stream<Map<String, dynamic>?> getProductDetails(String productId) {
    return firestore
        .collection('marketplace_products')
        .doc(productId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data()!;
          return {
            ...data,
            'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
            'updatedAt': data['updatedAt']?.toDate() ?? DateTime.now(),
          };
        });
  }
}

class MarketplaceTab extends ConsumerStatefulWidget {
  final String groupId;
  
  const MarketplaceTab({
    Key? key, 
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends ConsumerState<MarketplaceTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  // Controladores para el formulario de nuevo producto
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Otros';
  bool _isNegotiable = true;
  File? _productImage;
  
  final List<String> _categories = [
    'Electrónica',
    'Moda',
    'Hogar',
    'Juguetes',
    'Deportes',
    'Libros',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _productImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitProduct() async {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty || priceText.isEmpty || description.isEmpty) {
      showSnackBar(context: context, content: 'Por favor completa todos los campos');
      return;
    }
    
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      showSnackBar(context: context, content: 'Ingresa un precio válido');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(marketplaceControllerProvider).createProduct(
      context: context,
      groupId: widget.groupId,
      title: title,
      price: price,
      description: description,
      imageFile: _productImage,
      category: _selectedCategory,
      negotiable: _isNegotiable,
    );

    if (success) {
      _titleController.clear();
      _priceController.clear();
      _descriptionController.clear();
      setState(() {
        _productImage = null;
        _selectedCategory = 'Otros';
        _isNegotiable = true;
        
        // Cambiar a la pestaña de productos disponibles
        _tabController.animateTo(1);
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final availableProducts = ref.watch(groupAvailableProductsProvider(widget.groupId));
    final myProducts = ref.watch(groupAllSalesProvider(widget.groupId));
    
    return Column(
      children: [
        Container(
          color: Color(0xFF1A1A1A),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Color(0xFF3E63A8),
            labelColor: Color(0xFF3E63A8),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Vender'),
              Tab(text: 'Productos'),
              Tab(text: 'Mis ventas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Publicar nuevo producto
              Container(
                color: Color(0xFF121212),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Publicar un producto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Imagen del producto
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: _productImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _productImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Agregar imagen',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Título
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dividerColor),
                        ),
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Título del producto',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Precio
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dividerColor),
                        ),
                        child: TextField(
                          controller: _priceController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Precio (€)',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: Icon(Icons.euro, color: accentColor),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Descripción
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dividerColor),
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Categoría
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dividerColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: Color(0xFF1E1E1E),
                            isExpanded: true,
                            value: _selectedCategory,
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                            hint: Text(
                              'Categoría',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Negociable
                      Card(
                        color: Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.zero,
                        child: SwitchListTile(
                          title: const Text(
                            'Precio negociable',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: _isNegotiable,
                          activeColor: accentColor,
                          onChanged: (value) {
                            setState(() {
                              _isNegotiable = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Botón publicar
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitProduct,
                        icon: const Icon(Icons.sell),
                        label: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('PUBLICAR PRODUCTO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab 2: Productos disponibles
              Container(
                color: Color(0xFF121212),
                child: availableProducts.when(
                  data: (products) => products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E1E1E).withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'No hay productos disponibles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sé el primero en publicar un producto',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _tabController.animateTo(0),
                                icon: const Icon(Icons.add),
                                label: const Text('PUBLICAR PRODUCTO'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : // Modifica el GridView.builder para añadir shrinkWrap y physics
GridView.builder(
  padding: const EdgeInsets.all(12),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.50, // Ajusta este valor para adaptarlo mejor (prueba con 0.8)
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  ),
  itemCount: products.length,
  itemBuilder: (context, index) => _buildProductCard(products[index]),
  // Añade estas dos líneas
  shrinkWrap: true,
  physics: const AlwaysScrollableScrollPhysics(),
),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: errorColor),
                        const SizedBox(height: 8),
                        Text(
                          'Error al cargar productos: ${error.toString()}',
                          style: TextStyle(color: errorColor),
                          textAlign: TextAlign.center,
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Recargar
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab 3: Mis productos
              Container(
                color: Color(0xFF121212),
                child: myProducts.when(
                  data: (products) => products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E1E1E).withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sell_outlined,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'No has publicado productos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Vende tus productos al grupo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _tabController.animateTo(0),
                                icon: const Icon(Icons.add),
                                label: const Text('PUBLICAR PRODUCTO'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: products.length,
                          itemBuilder: (context, index) => _buildMyProductCard(products[index]),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: errorColor),
                        const SizedBox(height: 8),
                        Text(
                          'Error al cargar productos: ${error.toString()}',
                          style: TextStyle(color: errorColor),
                          textAlign: TextAlign.center,
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Recargar
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? 'Sin título';
    final price = product['price'] ?? 0.0;
    final imageUrl = product['imageUrl'];
    final isNegotiable = product['negotiable'] ?? false;
    final sellerId = product['sellerId'];
    final productId = product['productId'];
    
    return GestureDetector(
      onTap: () => _showProductDetails(productId),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Color(0xFF1E1E1E),
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      color: Color(0xFF1E1E1E),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  if (isNegotiable)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Negociable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Información
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        fontSize: 16,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Vendedor
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(sellerId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        final sellerName = userData?['name'] ?? 'Usuario';
                        
                        return Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                sellerName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Botones de acción (no mostrar para productos propios)
                    FutureBuilder<User?>(
                      future: Future.value(FirebaseAuth.instance.currentUser),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final currentUserId = snapshot.data!.uid;
                        if (currentUserId == sellerId) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sell,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tu producto',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return Row(
                          children: [
                          Expanded(
  child: ElevatedButton.icon(
    icon: const Icon(Icons.chat, size: 16),
    label: const Text('Chat', style: TextStyle(fontSize: 12)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    // En el botón de Chat
onPressed: () async {
  final sellerName = await ref.read(marketplaceControllerProvider).getUserName(sellerId);
  final sellerProfilePic = await ref.read(marketplaceControllerProvider).getUserProfilePic(sellerId);
  
  // Si estamos en un diálogo, cerrarlo
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }
  
  // Usar el navegador global
  GlobalNavigation.push(
    MobileChatScreen(
      name: sellerName,
      uid: sellerId,
      isGroupChat: false,
      profilePic: sellerProfilePic,
    ),
  );
},
  ),
),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.shopping_cart, size: 16),
                                label: const Text('Comprar', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                 // Reemplaza el bloque que contiene el FutureBuilder con getUserWallet por este código
// Este código utiliza el stream del walletControllerProvider directamente, como se hace en RecordFundsTab

showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog(
    backgroundColor: Color(0xFF1A1A1A),
    title: const Text(
      'Confirmar compra',
      style: TextStyle(color: Colors.white),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Estás seguro de que quieres comprar "$title" por €${price.toStringAsFixed(2)}?',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        Consumer(
          builder: (context, ref, child) {
            final walletState = ref.watch(walletControllerProvider);
            
            return walletState.when(
              data: (wallet) {
                if (wallet == null) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: errorColor),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No tienes una wallet activa',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final balance = wallet.balance;
                
                if (balance < price) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo insuficiente: €${balance.toStringAsFixed(2)}',
                            style: TextStyle(color: errorColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo disponible: €${balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Container(
                padding: const EdgeInsets.all(8),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Verificando saldo...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              error: (_, __) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: errorColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: errorColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Error al verificar saldo',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(
          'Cancelar',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
      Consumer(
        builder: (context, ref, child) {
          final walletState = ref.watch(walletControllerProvider);
          
          return walletState.when(
            data: (wallet) {
              final hasEnoughBalance = wallet != null && wallet.balance >= price;
              
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3E63A8),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                onPressed: hasEnoughBalance 
                  ? () async {
                      Navigator.pop(dialogContext);
                      await ref.read(marketplaceControllerProvider).purchaseProduct(
                        context: context,
                        productId: productId,
                      );
                    }
                  : null,
                child: const Text('Comprar'),
              );
            },
            loading: () => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: null,
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            error: (_, __) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: null,
              child: const Text('Error'),
            ),
          );
        },
      ),
    ],
  ),
);
                                },
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _buildMyProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? 'Sin título';
    final price = product['price'] ?? 0.0;
    final imageUrl = product['imageUrl'];
    final status = product['status'] ?? 'available';
    final createdAt = product['createdAt'] as DateTime? ?? DateTime.now();
    final List<dynamic> interestedUsers = product['interestedUsers'] ?? [];
    final productId = product['productId'];
    
    // Formatear fecha
    final formattedDate = DateFormat('dd/MM/yyyy').format(createdAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Color(0xFF1A1A1A),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProductDetails(productId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen del producto
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Color(0xFF1E1E1E),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.image,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (status == 'sold')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VENDIDO',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Publicado: $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${interestedUsers.length} personas interesadas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (status == 'available')
                          TextButton(
                            onPressed: () => _showPopupMenu(context, product),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              'Opciones',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPopupMenu(BuildContext context, Map<String, dynamic> product) {
    final productId = product['productId'];
    final List<dynamic> interestedUsers = product['interestedUsers'] ?? [];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text('Editar producto', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Implementar edición
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Marcar como vendido', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showMarkAsSoldDialog(productId, interestedUsers);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: errorColor),
            title: Text('Eliminar producto', style: TextStyle(color: errorColor)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteProductDialog(productId);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showProductDetails(String productId) {
   showDialog(
  context: context,
  builder: (context) => StreamBuilder<Map<String, dynamic>?>(
    stream: ref.read(marketplaceControllerProvider).getProductDetails(productId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Dialog(
          backgroundColor: Color(0xFF1A1A1A),
          child: const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      
      final product = snapshot.data!;
      final title = product['title'] ?? 'Sin título';
      final price = product['price'] ?? 0.0;
      final description = product['description'] ?? '';
      final imageUrl = product['imageUrl'];
      final sellerId = product['sellerId'];
      final isNegotiable = product['negotiable'] ?? false;
      final status = product['status'] ?? 'available';
      final createdAt = product['createdAt'] as DateTime? ?? DateTime.now();
      final category = product['category'] ?? 'Otros';
      
      // Formatear fecha
      final formattedDate = DateFormat('dd/MM/yyyy').format(createdAt);
      
      return Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Color(0xFF1E1E1E),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Información del producto
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título y estado
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (status == 'sold')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'VENDIDO',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Precio y características
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '€${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isNegotiable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'Negociable',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Detalles
                    const Text(
                      'Detalles:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            icon: Icons.category,
                            label: 'Categoría:',
                            value: category,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.calendar_today,
                            label: 'Publicado:',
                            value: formattedDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Descripción
                    const Text(
                      'Descripción:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Vendedor
                    const Text(
                      'Vendedor:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(sellerId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text(
                            'Cargando información del vendedor...',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        final sellerName = userData?['name'] ?? 'Usuario';
                        final sellerPic = userData?['profilePic'];
                        
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: sellerPic != null ? NetworkImage(sellerPic) : null,
                                backgroundColor: sellerPic == null ? accentColor : null,
                                child: sellerPic == null
                                    ? Text(
                                        sellerName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                sellerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Botones de acción
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cerrar',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<User?>(
                      future: Future.value(FirebaseAuth.instance.currentUser),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final currentUserId = snapshot.data!.uid;
                        
                        // Si es el vendedor, mostrar botón de marcar como vendido
                        if (currentUserId == sellerId && status == 'available') {
                        return ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showMarkAsSoldDialog(
                              productId,
                              product['interestedUsers'] ?? [],
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Marcar como vendido'),
                        );
                      }
                      
                      // Si no es el vendedor y el producto está disponible, mostrar botones de acción
                      if (currentUserId != sellerId && status == 'available') {
                        return Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                // Navegar directamente a la pantalla de chat
                                Navigator.pushNamed(
                                  context,
                                  '/mobile-chat-screen',
                                  arguments: {
                                    'name': await ref.read(marketplaceControllerProvider).getUserName(sellerId),
                                    'uid': sellerId,
                                    'isGroupChat': false,
                                    'profilePic': await ref.read(marketplaceControllerProvider).getUserProfilePic(sellerId),
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Chat'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(  // CAMBIO AQUÍ: context -> dialogContext
                                    backgroundColor: Color(0xFF1A1A1A),
                                    title: const Text(
                                      'Confirmar compra',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '¿Estás seguro de que quieres comprar "$title" por €${price.toStringAsFixed(2)}?',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        const SizedBox(height: 16),
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final walletState = ref.watch(walletControllerProvider);
                                            
                                            return walletState.when(
                                              data: (wallet) {
                                                if (wallet == null) {
                                                  return Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: errorColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: errorColor),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.warning_amber_rounded, color: errorColor),
                                                        const SizedBox(width: 8),
                                                        const Expanded(
                                                          child: Text(
                                                            'No tienes una wallet activa',
                                                            style: TextStyle(color: Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                
                                                final balance = wallet.balance;
                                                
                                                if (balance < price) {
                                                  return Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: errorColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: errorColor),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.warning_amber_rounded, color: errorColor),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Saldo insuficiente: €${balance.toStringAsFixed(2)}',
                                                            style: TextStyle(color: errorColor),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                
                                                return Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.account_balance_wallet, color: Colors.green),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Saldo disponible: €${balance.toStringAsFixed(2)}',
                                                          style: const TextStyle(color: Colors.green),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              loading: () => Container(
                                                padding: const EdgeInsets.all(8),
                                                child: const Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Verificando saldo...',
                                                      style: TextStyle(color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              error: (_, __) => Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: errorColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: errorColor),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.error_outline, color: errorColor),
                                                    const SizedBox(width: 8),
                                                    const Expanded(
                                                      child: Text(
                                                        'Error al verificar saldo',
                                                        style: TextStyle(color: Colors.red),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),  // CAMBIO AQUÍ: context -> dialogContext
                                        child: Text(
                                          'Cancelar',
                                          style: TextStyle(color: Colors.grey[400]),
                                        ),
                                      ),
                                      Consumer(
                                        builder: (context, ref, child) {
                                          final walletState = ref.watch(walletControllerProvider);
                                          
                                          return walletState.when(
                                            data: (wallet) {
                                              final hasEnoughBalance = wallet != null && wallet.balance >= price;
                                              
                                              return ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Color(0xFF3E63A8),
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor: Colors.grey,
                                                ),
                                                onPressed: hasEnoughBalance 
                                                  ? () async {
                                                      // Guardar referencia al contexto principal
                                                      final outerContext = context;
                                                      
                                                      // Cerrar el diálogo usando dialogContext
                                                      Navigator.pop(dialogContext);  // CAMBIO AQUÍ: context -> dialogContext
                                                      
                                                      // Realizar la compra
                                                      bool success = false;
                                                      try {
                                                        success = await ref.read(marketplaceControllerProvider).purchaseProduct(
                                                          context: outerContext,
                                                          productId: productId,
                                                        );
                                                        
                                                        if (success && outerContext.mounted) {
                                                          showSnackBar(
                                                            context: outerContext,
                                                            content: 'Producto comprado con éxito',
                                                            backgroundColor: Colors.green,
                                                          );
                                                        }
                                                      } catch (e) {
                                                        print("Error en compra: $e");
                                                      }
                                                  }
                                                : null,
                                                child: const Text('Comprar'),
                                              );
                                            },
                                            loading: () => ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: null,
                                              child: const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                            ),
                                            error: (_, __) => ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: null,
                                              child: const Text('Error'),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3E63A8),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Comprar'),
                            ),
                          ],
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
  ),
);
}
Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 16,
        color: Colors.grey,
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey[400],
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}void _showDeleteProductDialog(String productId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF1A1A1A),
      title: const Text(
        'Eliminar producto',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        '¿Estás seguro de que deseas eliminar este producto? Esta acción no se puede deshacer.',
        style: TextStyle(color: Colors.grey),
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
            backgroundColor: errorColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context);
            setState(() => _isLoading = true);
            
            // Eliminar producto (lógicamente - cambiar estado a "deleted")
            await FirebaseFirestore.instance
                .collection('marketplace_products')
                .doc(productId)
                .update({
              'status': 'deleted',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            setState(() => _isLoading = false);
            
            if (mounted) {
              showSnackBar(context: context, content: 'Producto eliminado');
            }
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}void _showMarkAsSoldDialog(String productId, List<dynamic> interestedUsers) {
  if (interestedUsers.isEmpty) {
    // Si no hay interesados, mostrar diálogo simple
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: const Text(
          'Marcar como vendido',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que deseas marcar este producto como vendido?',
          style: TextStyle(color: Colors.grey),
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
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              await ref.read(marketplaceControllerProvider).markAsSold(
                context: context,
                productId: productId,
              );
              
              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Marcar como vendido'),
          ),
        ],
      ),
    );
  } else {
    // Si hay interesados, mostrar lista para seleccionar comprador
    String? selectedBuyerId;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          title: const Text(
            'Marcar como vendido',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿A quién le vendiste el producto?',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: interestedUsers.length + 1, // +1 para la opción "Otro"
                  itemBuilder: (context, index) {
                    if (index == interestedUsers.length) {
                      // Última opción: "Otro"
                      return RadioListTile<String?>(
                        title: const Text(
                          'Otro',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: null,
                        groupValue: selectedBuyerId,
                        activeColor: accentColor,
                        onChanged: (value) {
                          setState(() {
                            selectedBuyerId = value;
                          });
                        },
                      );
                    }
                    
                    final userId = interestedUsers[index];
                    
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            title: Text(
                              'Cargando...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        final name = userData?['name'] ?? 'Usuario';
                        final profilePic = userData?['profilePic'];
                        
                        return RadioListTile<String>(
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                                backgroundColor: profilePic == null ? accentColor : null,
                                child: profilePic == null
                                    ? Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          value: userId,
                          groupValue: selectedBuyerId,
                          activeColor: accentColor,
                          onChanged: (value) {
                            setState(() {
                              selectedBuyerId = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                
                await ref.read(marketplaceControllerProvider).markAsSold(
                  context: context,
                  productId: productId,
                  buyerId: selectedBuyerId, // Puede ser null si seleccionó "Otro"
                );
                
                setState(() => _isLoading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Marcar como vendido'),
            ),
          ],
        ),
      ),
    );
  }
}
}