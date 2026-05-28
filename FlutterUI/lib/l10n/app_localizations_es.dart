// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get searchHint => 'Buscar aplicaciones, juegos, herramientas...';

  @override
  String get featured => 'Destacado';

  @override
  String get forYou => 'Para ti';

  @override
  String get essentialTools => 'Herramientas esenciales';

  @override
  String get hotApps => 'Aplicaciones populares';

  @override
  String get explore => 'Explorar';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String get downloads => 'Descargas';

  @override
  String get help => 'Ayuda';

  @override
  String get userAccount => 'Cuenta de usuario';

  @override
  String get install => 'Instalar';

  @override
  String get open => 'Abrir';

  @override
  String get uninstall => 'Desinstalar';

  @override
  String get launch => 'Iniciar';

  @override
  String get about => 'Acerca de';

  @override
  String get details => 'Detalles';

  @override
  String get source => 'Fuente';

  @override
  String get variant => 'Variante';

  @override
  String get version => 'Versión';

  @override
  String get ready => 'Listo';

  @override
  String resultsFound(int count) {
    return '$count resultados encontrados';
  }

  @override
  String get noResults => 'No se encontraron resultados';

  @override
  String get searching => 'Buscando...';

  @override
  String get category => 'Categoría';

  @override
  String get packageManager => 'Gestor de paquetes';

  @override
  String get pacmanOfficial => 'Pacman (Oficial)';

  @override
  String get aurUser => 'AUR (Usuario)';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => 'Prioridad de fuente (Arrastrar para reordenar)';

  @override
  String get maxResults => 'Resultados máximos';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeColor => 'Color del tema';

  @override
  String get followSystem => 'Seguir sistema';

  @override
  String get lightMode => 'Modo claro';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get loggingLevel => 'Nivel de registro';

  @override
  String get saveAndApply => 'Guardar y aplicar';

  @override
  String get configSaved => 'Configuración guardada';

  @override
  String get configSaveFailed => 'Error al guardar la configuración';

  @override
  String get confirmUninstall => 'Confirmar desinstalación';

  @override
  String get confirmInstall => 'Confirmar instalación';

  @override
  String confirmActionMsg(String name) {
    return '¿Estás seguro de que quieres realizar esta acción en $name?';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get terminalOutput => 'Salida de terminal';

  @override
  String get waitingForOutput => 'Esperando salida...';

  @override
  String get screenshots => 'Capturas de pantalla';

  @override
  String get developer => 'Desarrollador';

  @override
  String get license => 'Licencia';

  @override
  String get success => 'Éxito';

  @override
  String get failed => 'Error';

  @override
  String get taskCancelled => 'Tarea cancelada';

  @override
  String get catDevelopment => 'Desarrollo';

  @override
  String get catMedia => 'Multimedia';

  @override
  String get catInternet => 'Internet';

  @override
  String get catSystem => 'Sistema';

  @override
  String get catOffice => 'Oficina';

  @override
  String get catGames => 'Juegos';

  @override
  String get updates => 'Actualizaciones';

  @override
  String get upToDate => 'Todas las aplicaciones están actualizadas';

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String foundUpdates(int count) {
    return 'Se encontraron $count actualizaciones';
  }

  @override
  String get updateAll => 'Actualizar todo';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get enableNotifications => 'Activar notificaciones';

  @override
  String get progressNotifications => 'Notificaciones de progreso';

  @override
  String get completionNotifications => 'Notificaciones de finalización';

  @override
  String get closeToTray => 'Cerrar a la bandeja del sistema';

  @override
  String get useSystemTitleBar => 'Usar barra de título del sistema';

  @override
  String get showWindow => 'Mostrar ventana';

  @override
  String get exit => 'Salir';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore: Se encontraron $count actualizaciones';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore: Actualizado';

  @override
  String get updateReminders => 'Recordatorios de actualización';

  @override
  String get maintenance => 'Mantenimiento';

  @override
  String get updateAllPackages => 'Actualizar todos los paquetes';

  @override
  String get includeAurUpdates => 'Incluir AUR en \'Actualizar todo\'';

  @override
  String get resetOnboarding => 'Restablecer bienvenida';

  @override
  String get resetOnboardingConfirm =>
      '¿Estás seguro de que quieres restablecer la bienvenida? Se mostrará en el próximo inicio.';

  @override
  String get checkInterval => 'Intervalo de comprobación (Horas)';

  @override
  String get remindMeOfUpdates => 'Recordarme actualizaciones';

  @override
  String installingApp(String name) {
    return 'Instalando $name';
  }

  @override
  String uninstallingApp(String name) {
    return 'Desinstalando $name';
  }

  @override
  String get installSuccessTitle => 'Instalación exitosa';

  @override
  String get uninstallSuccessTitle => 'Desinstalación exitosa';

  @override
  String get installFailedTitle => 'Instalación fallida';

  @override
  String get uninstallFailedTitle => 'Desinstalación fallida';

  @override
  String get taskCompleted => 'Tarea completada';

  @override
  String get searchInstalledHint => 'Buscar aplicaciones instaladas...';

  @override
  String get refresh => 'Actualizar';

  @override
  String get noActiveTasks => 'No hay tareas activas';

  @override
  String get currentTask => 'Tarea actual';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get allUpdated => 'Todas las aplicaciones están al día';

  @override
  String get update => 'Actualizar';
}
