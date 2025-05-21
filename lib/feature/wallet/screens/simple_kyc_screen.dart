import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_layout_screen.dart';

class KYCScreen extends ConsumerStatefulWidget {
  static const String routeName = '/kyc';

  const KYCScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCScreen> createState() => _KYCScreenState();
}

class _KYCScreenState extends ConsumerState<KYCScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _identificationNumberController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedGender = 'male';
  String _selectedNationality = 'ES';
  String _selectedIdentificationType = 'passport';

  final List<String> _genders = ['male', 'female', 'other'];
  final List<String> _identificationTypes = ['passport', 'driving_license', 'national_id'];
  final List<String> _countries = ['ES', 'FR', 'DE', 'IT', 'UK', 'US'];

  @override
  void initState() {
    super.initState();
    logInfo('KYCScreen', 'Inicializando KYCScreen');
    _loadWalletData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _ibanController.dispose();
    _identificationNumberController.dispose();
    super.dispose();
  }

  void _loadWalletData() {
    logInfo('KYCScreen', 'Cargando datos de wallet en KYCScreen');
    final walletState = ref.read(walletControllerProvider);
    
    walletState.whenData((wallet) {
      if (wallet != null) {
        logInfo('KYCScreen', 'Datos de wallet encontrados: ${wallet.toMap()}');
        
        // Pre-llenar los campos con datos existentes si están disponibles
        if (wallet.firstName != null && wallet.firstName!.isNotEmpty) {
          _firstNameController.text = wallet.firstName!;
        }
        if (wallet.lastName != null && wallet.lastName!.isNotEmpty) {
          _lastNameController.text = wallet.lastName!;
        }
        if (wallet.email != null && wallet.email!.isNotEmpty) {
          _emailController.text = wallet.email!;
        }
        if (wallet.birthDate != null) {
          _selectedDate = wallet.birthDate;
          _birthDateController.text = DateFormat('dd/MM/yyyy').format(wallet.birthDate!);
        }
        if (wallet.address != null && wallet.address!.isNotEmpty) {
          _addressController.text = wallet.address!;
        }
        if (wallet.city != null && wallet.city!.isNotEmpty) {
          _cityController.text = wallet.city!;
        }
        if (wallet.postalCode != null && wallet.postalCode!.isNotEmpty) {
          _postalCodeController.text = wallet.postalCode!;
        }
        if (wallet.country != null && wallet.country!.isNotEmpty) {
          _countryController.text = wallet.country!;
          _selectedNationality = wallet.country!;
        } else {
          _countryController.text = 'ES'; // Default para España
        }
        if (wallet.iban != null && wallet.iban!.isNotEmpty) {
          _ibanController.text = wallet.iban!;
        }
      } else {
        logWarning('KYCScreen', 'No se encontraron datos de wallet');
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    logInfo('KYCScreen', 'Seleccionando fecha de nacimiento');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      logInfo('KYCScreen', 'Fecha seleccionada: ${_birthDateController.text}');
    }
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) {
      logWarning('KYCScreen', 'Formulario inválido');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      logInfo('KYCScreen', 'Enviando datos KYC...');
      
      // Verificar conexión con el servidor
      final isConnected = await ref.read(walletControllerProvider.notifier).checkServerConnection();
      logInfo('KYCScreen', 'Conexión con el servidor: ${isConnected ? 'OK' : 'Fallida'}');
      
      if (!isConnected) {
        showSnackBar(
          context: context,
          content: 'No hay conexión con el servidor. Los datos se guardarán localmente.',
        );
      }
      
      // Preparar datos personales
      final personalData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'email': _emailController.text,
        'birthDate': _selectedDate?.toIso8601String(),
        'address': _addressController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
        'country': _countryController.text,
        'iban': _ibanController.text,
        'gender': _selectedGender,
        'nationality': _selectedNationality,
        'identificationType': _selectedIdentificationType,
        'identificationNumber': _identificationNumberController.text,
      };
      
      logInfo('KYCScreen', 'Datos personales a enviar: $personalData');

      // Obtener el ID del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      
      if (userId == null) {
        logError('KYCScreen', 'No se pudo obtener el ID del usuario');
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Iniciar KYC
      final result = await ref.read(walletControllerProvider.notifier).initiateSimpleKYC(
        userId: userId,
        personalData: personalData,
      );
      
      logInfo('KYCScreen', 'Resultado de initiateSimpleKYC: $result');

      if (result['success'] == true) {
        logInfo('KYCScreen', 'KYC iniciado correctamente');
        
        // Validar KYC para crear la cuenta en Rapyd
        logInfo('KYCScreen', 'Validando KYC...');
        final validationResult = await ref.read(walletControllerProvider.notifier).validateKYC(
          userId: userId,
        );
        
        logInfo('KYCScreen', 'Resultado de validateKYC: $validationResult');
        
        if (validationResult['success'] == true) {
          logInfo('KYCScreen', 'KYC validado correctamente');
          
          if (mounted) {
            showSnackBar(
              context: context,
              content: 'Verificación completada correctamente',
            );
            
            // MODIFICACIÓN: En lugar de simplemente hacer pop,
            // redirigir al usuario a la pantalla principal
            Navigator.pushNamedAndRemoveUntil(
              context, 
              MobileLayoutScreen.routeName, // Usar la ruta de la pantalla principal
              (route) => false // Eliminar todas las rutas anteriores
            );
          }
        } else {
          logError('KYCScreen', 'Error en validación KYC: ${validationResult['error']}');
          if (mounted) {
            showSnackBar(
              context: context,
              content: 'Error en validación: ${validationResult['error']}',
            );
          }
        }
      } else {
        logError('KYCScreen', 'Error al iniciar KYC: ${result['error']}');
        if (mounted) {
          showSnackBar(
            context: context,
            content: 'Error: ${result['error']}',
          );
        }
      }
    } catch (e, stack) {
      logError('KYCScreen', 'Error en _submitKYC', e, stack);
      if (mounted) {
        showSnackBar(
          context: context,
          content: 'Error: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Identidad'),
      ),
      body: _isLoading
          ? const Loader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Para activar tu cuenta, necesitamos verificar tu identidad',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    
                    // Nombre
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Apellido
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Apellido',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu apellido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu email';
                        }
                        if (!value.contains('@')) {
                          return 'Por favor ingresa un email válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Fecha de nacimiento
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _birthDateController,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor selecciona tu fecha de nacimiento';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Género
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Género',
                        border: OutlineInputBorder(),
                      ),
                      items: _genders.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender == 'male' ? 'Masculino' : 
                                      gender == 'female' ? 'Femenino' : 'Otro'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona tu género';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Nacionalidad
                    DropdownButtonFormField<String>(
                      value: _selectedNationality,
                      decoration: const InputDecoration(
                        labelText: 'Nacionalidad',
                        border: OutlineInputBorder(),
                      ),
                      items: _countries.map((country) {
                        return DropdownMenuItem(
                          value: country,
                          child: Text(country),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedNationality = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona tu nacionalidad';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Tipo de identificación
                    DropdownButtonFormField<String>(
                      value: _selectedIdentificationType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de identificación',
                        border: OutlineInputBorder(),
                      ),
                      items: _identificationTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type == 'passport' ? 'Pasaporte' : 
                                      type == 'driving_license' ? 'Licencia de conducir' : 'DNI'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedIdentificationType = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona el tipo de identificación';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Número de identificación
                    TextFormField(
                      controller: _identificationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Número de identificación',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu número de identificación';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Dirección
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu dirección';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Ciudad
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu ciudad';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Código postal
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código Postal',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu código postal';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // País
                    TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'País (código ISO, ej: ES)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa el código de tu país';
                        }
                        if (value.length != 2) {
                          return 'Usa el código ISO de 2 letras (ej: ES)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // IBAN
                    TextFormField(
                      controller: _ibanController,
                      decoration: const InputDecoration(
                        labelText: 'IBAN',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: ES91 2100 0418 4502 0005 1332',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu IBAN';
                        }
                        // Validación básica de IBAN
                        if (value.length < 15) {
                          return 'IBAN demasiado corto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Botón de envío
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitKYC,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Enviar Verificación',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}