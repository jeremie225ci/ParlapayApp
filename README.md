# MK Messenger

Aplicación de mensajería multiplataforma desarrollada con Flutter.

## Características

- Chat en tiempo real
- Llamadas de audio y video
- Sistema de pagos integrado con Rapyd
- Notificaciones push
- Gestión de contactos
- Grupos y stickers
- Tema claro/oscuro

## Requisitos

- Flutter SDK >=3.5.3
- Dart SDK >=3.0.0
- Android Studio / VS Code
- Firebase CLI
- Node.js >=20.0.0

## Instalación

1. Clonar el repositorio:
```bash
git clone https://github.com/[tu-usuario]/mk_mesenger.git
```

2. Instalar dependencias:
```bash
flutter pub get
```

3. Configurar Firebase:
- Crear proyecto en Firebase Console
- Descargar y configurar google-services.json
- Configurar Firebase CLI

4. Configurar Rapyd:
- Crear cuenta de desarrollo en Rapyd
- Configurar credenciales en .env

5. Ejecutar la aplicación:
```bash
flutter run
```

## Estructura del Proyecto

```
lib/
├── feature/           # Características principales
│   ├── auth/         # Autenticación
│   ├── chat/         # Chat
│   ├── call/         # Llamadas
│   └── ...
├── common/           # Código compartido
├── config/           # Configuraciones
├── services/         # Servicios externos
└── widgets/          # Widgets reutilizables
```

## Control de Versiones

- `main`: Rama principal de producción
- `develop`: Rama de desarrollo
- `feature/*`: Ramas para nuevas características
- `hotfix/*`: Ramas para correcciones urgentes

## Contribución

1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE.md](LICENSE.md) para más detalles.

## Contacto

[Tu Nombre] - [Tu Email]

Link del Proyecto: [https://github.com/[tu-usuario]/mk_mesenger](https://github.com/[tu-usuario]/mk_mesenger)
