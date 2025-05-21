import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  static const String routeName = '/language';

  const LanguageScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'es'; // Español por defecto
  bool _isLoading = false;

  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'es',
      'name': 'Español',
      'nativeName': 'Español',
      'flag': '🇪🇸',
    },
    {
      'code': 'en',
      'name': 'Inglés',
      'nativeName': 'English',
      'flag': '🇬🇧',
    },
    {
      'code': 'fr',
      'name': 'Francés',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    {
      'code': 'de',
      'name': 'Alemán',
      'nativeName': 'Deutsch',
      'flag': '🇩🇪',
    },
    {
      'code': 'it',
      'name': 'Italiano',
      'nativeName': 'Italiano',
      'flag': '🇮🇹',
    },
    {
      'code': 'pt',
      'name': 'Portugués',
      'nativeName': 'Português',
      'flag': '🇵🇹',
    },
    {
      'code': 'ru',
      'name': 'Ruso',
      'nativeName': 'Русский',
      'flag': '🇷🇺',
    },
    {
      'code': 'zh',
      'name': 'Chino',
      'nativeName': '中文',
      'flag': '🇨🇳',
    },
    {
      'code': 'ja',
      'name': 'Japonés',
      'nativeName': '日本語',
      'flag': '🇯🇵',
    },
    {
      'code': 'ar',
      'name': 'Árabe',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'nativeName': 'हिन्दी',
      'flag': '🇮🇳',
    },
    {
      'code': 'ko',
      'name': 'Coreano',
      'nativeName': '한국어',
      'flag': '🇰🇷',
    },
  ];

  void _changeLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
      _isLoading = true;
    });

    // Simulación de carga
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Idioma cambiado correctamente'),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Idioma',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información sobre idiomas
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: accentColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Selecciona el idioma en el que deseas utilizar ParlaPay. La aplicación se reiniciará para aplicar los cambios.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Lista de idiomas
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _languages.length,
                      itemBuilder: (context, index) {
                        final language = _languages[index];
                        final isSelected = _selectedLanguage == language['code'];
                        
                        return RadioListTile<String>(
                          title: Row(
                            children: [
                              Text(
                                language['flag'],
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                language['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            language['nativeName'],
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          value: language['code'],
                          groupValue: _selectedLanguage,
                          activeColor: accentColor,
                          onChanged: (value) {
                            setState(() {
                              _selectedLanguage = value!;
                            });
                          },
                          secondary: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botón de aplicar cambios
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _changeLanguage(_selectedLanguage),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Aplicar cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Overlay de carga
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: accentColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cambiando idioma...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
