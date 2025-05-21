// lib/feature/wallet/screens/withdraw_funds_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';


class WithdrawFundsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/withdraw-funds';
  const WithdrawFundsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends ConsumerState<WithdrawFundsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _ibanController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isLoading = false;
  String _withdrawMethod = 'card';
  bool _saveDetails = false;

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final wallet = await ref.read(walletStreamProvider.future);
      if (wallet == null) throw Exception('No se encontró wallet');
      final amount = double.parse(_amountController.text);
      if (wallet.balance < amount) {
        showSnackBar(context: context, content: 'Saldo insuficiente');
        return;
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      Map<String, String>? accountInfo;
      if (_withdrawMethod == 'bank') {
        final iban = _ibanController.text.trim();
        final holder = _accountHolderController.text.trim();
        if (iban.isEmpty || holder.isEmpty) {
          showSnackBar(context: context, content: 'Ingresa IBAN y titular');
          return;
        }
        accountInfo = {'iban': iban, 'accountHolder': holder};
      }

      final success = await ref.read(walletControllerProvider.notifier).withdrawFunds(
        amount: amount,
        method: _withdrawMethod,
        accountInfo: accountInfo,
        context: context,
      );
      if (success) {
        Navigator.pop(context);
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error: \$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _ibanController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Retirar Fondos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              walletAsync.when(
                data: (w) => w == null
                    ? const SizedBox.shrink()
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Saldo Disponible', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('€\${w.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error al cargar saldo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Monto (€)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa monto';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Reembolso a tarjeta'),
                      value: 'card', groupValue: _withdrawMethod,
                      onChanged: (v) => setState(() => _withdrawMethod = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Transferencia bancaria'),
                      value: 'bank', groupValue: _withdrawMethod,
                      onChanged: (v) => setState(() => _withdrawMethod = v!),
                    ),
                  ],
                ),
              ),
              if (_withdrawMethod == 'bank') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ibanController,
                  decoration: const InputDecoration(labelText: 'IBAN', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa IBAN' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountHolderController,
                  decoration: const InputDecoration(labelText: 'Titular', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa titular' : null,
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Guardar detalles'),
                value: _saveDetails,
                onChanged: (v) => setState(() => _saveDetails = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitWithdrawal,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Retirar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
