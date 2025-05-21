class Constants {
  // URLs de API - Reemplaza con tu URL real de backend
  static const String apiUrl = 'https://us-central1-mk-mensenger.cloudfunctions.net/api'; 
  
  // Endpoints específicos
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String paymentsEndpoint = '/payments';
  
  // Configuración de Stripe
  static const String stripePublishableKey = 'pk_test_51PSAxGBZUIqVb4SncdUgIsZm4Ly0leGJlbpHQhsXwUP3XQ71vrUbkMnDNRyu3wp7524RokWpPQJ8R9gdOWBJouyN00v3HJ6dEu';
  
  // Configuración general
  static const int requestTimeout = 30; // Segundos
  
  // Mensajes de error comunes
  static const String networkError = 'Error de conexión. Verifica tu internet.';
  static const String authError = 'Error de autenticación. Inicia sesión nuevamente.';
  static const String paymentError = 'Error al procesar el pago.';
  
  // No se puede instanciar esta clase
  Constants._();
}