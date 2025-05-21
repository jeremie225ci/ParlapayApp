import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/common/utils/widgets/error.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/auth/screens/login_screen.dart';
import 'package:mk_mesenger/feature/auth/screens/otp_screen.dart';
import 'package:mk_mesenger/feature/auth/screens/user_information_screen.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_layout_screen.dart';
import 'package:mk_mesenger/feature/group/screens/create_group_screen.dart';
import 'package:mk_mesenger/feature/group/screens/group_home_screen.dart';
import 'package:mk_mesenger/feature/select_contacts/screens/select_contacts_screen.dart';
import 'package:mk_mesenger/feature/settings/screens/settings_screen.dart';
import 'package:mk_mesenger/feature/status/screens/confirm_status_screen.dart';
import 'package:mk_mesenger/feature/status/screens/status_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/payment_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/simple_kyc_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/wallet_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/withdraw_funds_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/restricted_account_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/debug_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/checkout_payment_screen.dart';
import 'package:mk_mesenger/common/models/status_model.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';
import 'package:mk_mesenger/common/models/call.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  logInfo('Router', '🧭 Navegando a: ${settings.name}');
  
  switch (settings.name) {
    case LoginScreen.routeName:
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    case OTPScreen.routeName:
      final arguments = settings.arguments as Map<String, dynamic>;
      final String verificationId = arguments['verificationId'] ?? '';
      final String phoneNumber = arguments['phoneNumber'] ?? '';
      return MaterialPageRoute(
        builder: (_) => OTPScreen(
          verificationId: verificationId,
          phoneNumber: phoneNumber,
        ),
      );
    case UserInformationScreen.routeName:
      return MaterialPageRoute(builder: (_) => const UserInformationScreen());
    case SelectContactsScreen.routeName:
      return MaterialPageRoute(builder: (_) => const SelectContactsScreen());
    case MobileChatScreen.routeName:
      final arguments = settings.arguments as Map<String, dynamic>;
      final String name = arguments['name'] ?? '';
      final String uid = arguments['uid'] ?? '';
      final bool isGroupChat = arguments['isGroupChat'] ?? false;
      final String profilePic = arguments['profilePic'] ?? '';
      return MaterialPageRoute(
        builder: (context) => MobileChatScreen(
          name: name,
          uid: uid,
          isGroupChat: isGroupChat,
          profilePic: profilePic,
        ),
      );
    case CreateGroupScreen.routeName:
      return MaterialPageRoute(builder: (_) => const CreateGroupScreen());
    case GroupHomeScreen.routeName:
      final args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => GroupHomeScreen(
          groupId: args['groupId'] ?? '',
          name: args['name'] ?? '',
          profilePic: args['profilePic'] ?? '',
        ),
      );
    case MobileLayoutScreen.routeName:
      return MaterialPageRoute(builder: (_) => const MobileLayoutScreen());
    case SettingsScreen.routeName:
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    case ConfirmStatusScreen.routeName:
      // Modificación para soportar tanto imagen como video
      final statusData = settings.arguments;
      
      // Manejar compatibilidad con versión anterior (solo File)
      if (statusData is File) {
        return MaterialPageRoute(
          builder: (_) => ConfirmStatusScreen(
            statusData: {'file': statusData, 'isVideo': false},
          ),
        );
      } 
      // Nueva versión con Map que incluye File y bool isVideo
      else if (statusData is Map<String, dynamic>) {
        return MaterialPageRoute(
          builder: (_) => ConfirmStatusScreen(statusData: statusData),
        );
      } 
      // Caso de error
      else {
        logError('Router', 'Formato incorrecto para ConfirmStatusScreen', 
          'Se esperaba File o Map<String, dynamic>, pero se recibió ${statusData.runtimeType}', null);
        return MaterialPageRoute(
          builder: (_) => const ErrorScreen(error: "Formato de datos incorrecto"),
        );
      }
   case StatusScreen.routeName:
  // Manejar el nuevo formato con argumentos múltiples
  final args = settings.arguments;
  
  if (args is Status) {
    // Compatibilidad hacia atrás - formato antiguo
    logInfo('Router', 'Navegando a StatusScreen con formato antiguo (solo Status)');
    return MaterialPageRoute(
      builder: (_) => StatusScreen(status: args, allStatuses: []),
    );
  } else if (args is Map<String, dynamic>) {
    // Nuevo formato con status y allStatuses
    logInfo('Router', 'Navegando a StatusScreen con formato nuevo (Map con status y allStatuses)');
    final status = args['status'] as Status;
    final allStatuses = args['allStatuses'] as List<Status>? ?? [];
    
    return MaterialPageRoute(
      builder: (_) => StatusScreen(status: status, allStatuses: allStatuses),
    );
  } else {
    // Formato incorrecto
    logError('Router', 'Formato incorrecto para StatusScreen', 
      'Se esperaba Status o Map<String, dynamic>, pero se recibió ${args.runtimeType}', null);
    return MaterialPageRoute(
      builder: (_) => const ErrorScreen(error: "Formato de datos incorrecto"),
    );
  }
     case CallScreen.routeName:
      final arguments = settings.arguments as Map<String, dynamic>;
      final String channelId = arguments['channelId'] ?? '';
      
      // Castea directamente a Call, asumiendo que NUNCA será null
      final Call callData = arguments['call'] as Call;
      final bool isGroupChat = arguments['isGroupChat'] as bool? ?? false;
      
      return MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId: channelId,
          call: callData,
          isGroupChat: isGroupChat,
        ),
      );
    case CheckoutPaymentScreen.routeName:
      final arguments = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => CheckoutPaymentScreen(
          checkoutUrl: arguments['checkoutUrl'] ?? '',
          checkoutId: arguments['checkoutId'] ?? '',
          amount: arguments['amount'] ?? 0.0,
          currency: arguments['currency'] ?? 'EUR',
          onPaymentComplete: arguments['onPaymentComplete'],
          onPaymentError: arguments['onPaymentError'],
          onPaymentVerify: arguments['onPaymentVerify'],
        ),
      );
      
    // Rutas de Wallet
    case WalletScreen.routeName:
      return MaterialPageRoute(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final walletState = ref.watch(walletControllerProvider);
            
            return walletState.when(
              data: (wallet) {
                // VERIFICACIÓN EXTREMA: Si hay la menor duda, mostrar KYC
                if (wallet == null) {
                  logInfo('Router', 'Wallet es null, redirigiendo a KYC');
                  return const KYCScreen();
                }
                
                // Verificar si kycCompleted es explícitamente TRUE y kycStatus es explícitamente 'approved'
                if (wallet.kycCompleted == true && wallet.kycStatus == 'approved') {
                  logInfo('Router', 'KYC verificado correctamente, mostrando WalletScreen');
                  return const WalletScreen();
                } else {
                  logInfo('Router', 'KYC faltante o incompleto, redirigiendo a KYCScreen');
                  logInfo('Router', 'kycCompleted: ${wallet.kycCompleted}, kycStatus: ${wallet.kycStatus}');
                  return const KYCScreen();
                }
              },
              loading: () {
                logInfo('Router', 'Wallet en carga, mostrando Loader');
                return const Loader();
              },
              error: (error, stack) {
                logError('Router', 'Error cargando wallet, redirigiendo a KYC', error, stack);
                return const KYCScreen();
              }
            );
          },
        ),
      );
    case KYCScreen.routeName:
      return MaterialPageRoute(builder: (_) => const KYCScreen());
    case PaymentScreen.routeName:
      final arguments = settings.arguments as Map<String, dynamic>?;
      final String receiverId = arguments?['receiverId'] ?? '';
      final String receiverName = arguments?['receiverName'] ?? '';
      return MaterialPageRoute(
        builder: (_) => PaymentScreen(
          receiverId: receiverId,
          receiverName: receiverName,
        ),
      );
    case WithdrawFundsScreen.routeName:
      return MaterialPageRoute(builder: (_) => const WithdrawFundsScreen());
    case RestrictedAccountScreen.routeName:
      return MaterialPageRoute(builder: (_) => const RestrictedAccountScreen());
    case DebugScreen.routeName:
      return MaterialPageRoute(builder: (_) => const DebugScreen());
      
    // Rutas directas (para compatibilidad)
    case '/wallet':
      return MaterialPageRoute(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final walletState = ref.watch(walletControllerProvider);
            
            return walletState.when(
              data: (wallet) {
                // VERIFICACIÓN EXTREMA: Si hay la menor duda, mostrar KYC
                if (wallet == null) {
                  logInfo('Router', 'Wallet es null, redirigiendo a KYC');
                  return const KYCScreen();
                }
                
                // Verificar si kycCompleted es explícitamente TRUE y kycStatus es explícitamente 'approved'
                if (wallet.kycCompleted == true && wallet.kycStatus == 'approved') {
                  logInfo('Router', 'KYC verificado correctamente, mostrando WalletScreen');
                  return const WalletScreen();
                } else {
                  logInfo('Router', 'KYC faltante o incompleto, redirigiendo a KYCScreen');
                  logInfo('Router', 'kycCompleted: ${wallet.kycCompleted}, kycStatus: ${wallet.kycStatus}');
                  return const KYCScreen();
                }
              },
              loading: () {
                logInfo('Router', 'Wallet en carga, mostrando Loader');
                return const Loader();
              },
              error: (error, stack) {
                logError('Router', 'Error cargando wallet, redirigiendo a KYC', error, stack);
                return const KYCScreen();
              }
            );
          },
        ),
      );
    case '/settings':
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    case '/kyc':
      return MaterialPageRoute(builder: (_) => const KYCScreen());
    case '/withdraw':
      return MaterialPageRoute(builder: (_) => const WithdrawFundsScreen());
    case '/debug':
      return MaterialPageRoute(builder: (_) => const DebugScreen());
    case '/mobile-layout':
      return MaterialPageRoute(builder: (_) => const MobileLayoutScreen());
      
    default:
      logWarning('Router', '⚠️ Ruta no encontrada: ${settings.name}');
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: ErrorScreen(error: "Esta página no existe"),
        ),
      );
  }
}