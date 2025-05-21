import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class StickersScreen extends ConsumerStatefulWidget {
  static const String routeName = '/stickers';

  const StickersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StickersScreen> createState() => _StickersScreenState();
}

class _StickersScreenState extends ConsumerState<StickersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Datos simulados de paquetes de stickers
  final List<Map<String, dynamic>> _myStickerPacks = [
    {
      'id': '1',
      'name': 'Emojis animados',
      'author': 'ParlaPay',
      'count': 30,
      'thumbnail': 'assets/stickers/emoji_pack.png',
      'stickers': List.generate(30, (index) => 'assets/stickers/emoji_$index.png'),
    },
    {
      'id': '2',
      'name': 'Animales divertidos',
      'author': 'Sticker Studio',
      'count': 24,
      'thumbnail': 'assets/stickers/animals_pack.png',
      'stickers': List.generate(24, (index) => 'assets/stickers/animal_$index.png'),
    },
    {
      'id': '3',
      'name': 'Memes populares',
      'author': 'Meme Factory',
      'count': 40,
      'thumbnail': 'assets/stickers/memes_pack.png',
      'stickers': List.generate(40, (index) => 'assets/stickers/meme_$index.png'),
    },
  ];

  final List<Map<String, dynamic>> _trendingStickerPacks = [
    {
      'id': '4',
      'name': 'Personajes de anime',
      'author': 'Anime World',
      'count': 35,
      'thumbnail': 'assets/stickers/anime_pack.png',
      'stickers': List.generate(35, (index) => 'assets/stickers/anime_$index.png'),
    },
    {
      'id': '5',
      'name': 'Comida deliciosa',
      'author': 'Food Lovers',
      'count': 28,
      'thumbnail': 'assets/stickers/food_pack.png',
      'stickers': List.generate(28, (index) => 'assets/stickers/food_$index.png'),
    },
    {
      'id': '6',
      'name': 'Frases motivadoras',
      'author': 'Inspiration',
      'count': 20,
      'thumbnail': 'assets/stickers/quotes_pack.png',
      'stickers': List.generate(20, (index) => 'assets/stickers/quote_$index.png'),
    },
    {
      'id': '7',
      'name': 'Deportes',
      'author': 'Sports Fan',
      'count': 32,
      'thumbnail': 'assets/stickers/sports_pack.png',
      'stickers': List.generate(32, (index) => 'assets/stickers/sport_$index.png'),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Stickers',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implementar búsqueda de stickers
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Mis stickers'),
            Tab(text: 'Tendencias'),
            Tab(text: 'Crear'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña de Mis stickers
          _buildMyStickerPacksTab(),
          
          // Pestaña de Tendencias
          _buildTrendingStickerPacksTab(),
          
          // Pestaña de Crear
          _buildCreateStickerTab(),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {
          // Implementar añadir nuevo paquete de stickers
        },
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildMyStickerPacksTab() {
    return _myStickerPacks.isEmpty
        ? _buildEmptyState(
            icon: Icons.emoji_emotions_outlined,
            title: 'No tienes stickers',
            subtitle: 'Añade paquetes de stickers para usarlos en tus conversaciones',
            buttonText: 'Explorar stickers',
            onPressed: () {
              _tabController.animateTo(1);
            },
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus paquetes de stickers',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myStickerPacks.length,
                  itemBuilder: (context, index) {
                    final pack = _myStickerPacks[index];
                    return _buildStickerPackItem(pack, isInstalled: true);
                  },
                ),
                const SizedBox(height: 80), // Espacio para el FAB
              ],
            ),
          );
  }

  Widget _buildTrendingStickerPacksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner destacado
          Container(
            width: double.infinity,
            height: 150,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paquete destacado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Descubre los stickers más populares del momento',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            'Paquetes populares',
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trendingStickerPacks.length,
            itemBuilder: (context, index) {
              final pack = _trendingStickerPacks[index];
              return _buildStickerPackItem(pack, isInstalled: false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateStickerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información sobre creación de stickers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: accentColor,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Crea tus propios stickers',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Personaliza tus conversaciones con stickers únicos creados por ti. Puedes usar tus propias fotos o diseños.',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Opciones de creación
          Text(
            'Opciones de creación',
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Opción de crear desde foto
          _buildCreationOption(
            icon: Icons.photo_library,
            title: 'Crear desde galería',
            description: 'Selecciona fotos de tu galería para convertirlas en stickers',
            onTap: () {
              // Implementar creación desde galería
            },
          ),
          
          const SizedBox(height: 12),
          
          // Opción de crear desde cámara
          _buildCreationOption(
            icon: Icons.camera_alt,
            title: 'Tomar foto',
            description: 'Toma una foto con tu cámara para convertirla en sticker',
            onTap: () {
              // Implementar creación desde cámara
            },
          ),
          
          const SizedBox(height: 12),
          
          // Opción de crear desde texto
          _buildCreationOption(
            icon: Icons.text_fields,
            title: 'Crear desde texto',
            description: 'Convierte texto y emojis en stickers personalizados',
            onTap: () {
              // Implementar creación desde texto
            },
          ),
          
          const SizedBox(height: 24),
          
          // Mis creaciones
          Text(
            'Mis creaciones',
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Lista vacía de creaciones
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_emotions_outlined,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No has creado ningún sticker',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus stickers personalizados aparecerán aquí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPackItem(Map<String, dynamic> pack, {required bool isInstalled}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con información del paquete
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.emoji_emotions,
                  color: Colors.grey[600],
                  size: 30,
                ),
              ),
            ),
            title: Text(
              pack['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Por ${pack['author']}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pack['count']} stickers',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: isInstalled
                ? IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // Mostrar opciones del paquete
                    },
                  )
                : ElevatedButton(
                    onPressed: () {
                      // Implementar añadir paquete
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'Añadir',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          
          // Vista previa de stickers
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 8, // Mostrar solo los primeros 8 stickers
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.emoji_emotions,
                      color: Colors.grey[600],
                      size: 30,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Botón para ver todos
          if (pack['count'] > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton(
                onPressed: () {
                  // Implementar ver todos los stickers
                },
                child: Text(
                  'Ver todos los ${pack["count"]} stickers',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreationOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.grey[600],
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
