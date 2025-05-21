// lib/feature/wallet/screens/restricted_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';

class RestrictedAccountScreen extends ConsumerStatefulWidget {
  static const String routeName = '/restricted-account';
  
  const RestrictedAccountScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RestrictedAccountScreen> createState() => _RestrictedAccountScreenState();
}

class _RestrictedAccountScreenState extends ConsumerState<RestrictedAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ibanController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _routingNumberController = TextEditingController();
  String _selectedAccountType = 'iban';
  bool _isLoading = false;

  Future<void> _submitBankInfo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      Map<String, String> bankInfo = {};
      
      if (_selectedAccountType == 'iban') {
        bankInfo['iban'] = _ibanController.text.trim();
      } else {
        bankInfo['accountNumber'] = _accountNumberController.text.trim();
        bankInfo['routingNumber'] = _routingNumberController.text.trim();
      }
      
      final result = await ref.read(walletControllerProvider.notifier).updateBankInfo(bankInfo);
      
      if (result['success'] == true) {
        if (mounted) {
          showSnackBar(
            context: context,
            content: 'Información bancaria actualizada correctamente',
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(result['error'] ?? 'Error al actualizar información bancaria');
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar cuenta'),
        backgroundColor: Colors.amber,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cuenta restringida',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu cuenta tiene pagos y transferencias restringidas porque necesitamos tu información bancaria para continuar.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Información bancaria',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAccountType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de cuenta bancaria',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'iban',
                        child: Text('IBAN (Europa)'),
                      ),
                      DropdownMenuItem(
                        value: 'us_bank',
                        child: Text('Cuenta bancaria US'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedAccountType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedAccountType == 'iban')
                    TextFormField(
                      controller: _ibanController,
                      decoration: const InputDecoration(
                        labelText: 'IBAN',
                        helperText: 'Ejemplo: ES9121000418450200051332',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => 
                        value?.isEmpty ?? true ? 'IBAN requerido' : null,
                    )
                  else
                    Column(
                      children: [
                        TextFormField(
                          controller: _accountNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Número de cuenta',
                            helperText: 'Sin guiones ni espacios',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => 
                            value?.isEmpty ?? true ? 'Número de cuenta requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _routingNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Routing Number',
                            helperText: '9 dígitos',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => 
                            value?.isEmpty ?? true || (value!.length != 9) ? 'Routing number inválido' : null,
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _submitBankInfo,
                      child: const Text('Completar información', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Stripe requiere esta información para procesar pagos y transferencias en tu nombre. Esta información es segura y está protegida.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _accountNumberController.dispose();
    _routingNumberController.dispose();
    super.dispose();
  }
}