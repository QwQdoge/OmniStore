// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get searchHint => 'Busca aplicaciones, juegos, herramientas...';

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
  String get downloads => 'Actividad y actualizaciones';

  @override
  String get help => 'Ayuda';

  @override
  String get userAccount => 'Cuenta de usuario';

  @override
  String get install => 'Instalar';

  @override
  String get download => 'Descargar';

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
  String get variant => 'Variantes';

  @override
  String get version => 'Versión';

  @override
  String get ready => 'Instalado';

  @override
  String resultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String get noResults => 'Sin resultados';

  @override
  String get searching => 'Buscando...';

  @override
  String get activity => 'Historial de tareas';

  @override
  String get category => 'Categoría';

  @override
  String get packageManager => 'Gestor de paquetes';

  @override
  String get pacmanOfficial => 'Pacman (Oficial)';

  @override
  String get pacmanBrowsingNoAuthorization =>
      'Explorar, buscar, ver detalles y comprobar actualizaciones de Pacman no requiere autenticación de cuenta ni de administrador. Solo se solicita autorización al modificar el sistema.';

  @override
  String get aurUser => 'AUR (Repositorio de usuarios)';

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
  String get configSaved =>
      'Configuración guardada. Algunos cambios se aplicarán tras reiniciar';

  @override
  String get configSaveFailed => 'Error al guardar la configuración';

  @override
  String get confirmUninstall => 'Confirmar desinstalación';

  @override
  String get confirmInstall => 'Confirmar instalación';

  @override
  String confirmActionMsg(String name) {
    return '¿Confirmas que deseas realizar esta acción en $name?';
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
  String get catInternet => 'Internet y Redes';

  @override
  String get catSystem => 'Sistema';

  @override
  String get catOffice => 'Oficina';

  @override
  String get catGames => 'Juegos';

  @override
  String get catGraphics => 'Gráficos';

  @override
  String get catUtility => 'Utilidades';

  @override
  String get systemAndWindow => 'Sistema y Ventana';

  @override
  String get visitWebsite => 'Visitar sitio web';

  @override
  String get updates => 'Actualizaciones';

  @override
  String get upToDate => 'Todas las aplicaciones están actualizadas';

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String foundUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actualizaciones encontradas',
      one: '1 actualización encontrada',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'OmniStore: $count actualizaciones encontradas',
      one: 'OmniStore: 1 actualización encontrada',
    );
    return '$_temp0';
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
  String get searchInstalledHint => 'Busca aplicaciones instaladas...';

  @override
  String get refresh => 'Actualizar';

  @override
  String get noActiveTasks => 'No hay tareas activas ni completadas';

  @override
  String get currentTask => 'Tarea actual';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get allUpdated => 'No se encontraron actualizaciones de paquetes';

  @override
  String get update => 'Actualizar';

  @override
  String updatingSourcePackages(String source) {
    return 'Actualizando paquetes de $source…';
  }

  @override
  String sourceUpdateFailed(String source) {
    return 'Falló la actualización de $source';
  }

  @override
  String get enabledSourcesUpdated =>
      'Todas las fuentes habilitadas están actualizadas';

  @override
  String get enableSystemTray => 'Activar bandeja del sistema';

  @override
  String get systemCleaning => 'Limpieza del sistema';

  @override
  String get system => 'Sistema';

  @override
  String get clean => 'Limpiar';

  @override
  String get systemCleaningDesc =>
      'Eliminar paquetes huérfanos y vaciar la caché de Pacman (requiere autorización de administrador)';

  @override
  String get systemCleaningSubtitle =>
      'Eliminar paquetes huérfanos y limpiar caché de pacman';

  @override
  String get systemCleaningStarted => 'Tarea de limpieza del sistema iniciada';

  @override
  String get backupAndExport => 'Copia de seguridad y exportación';

  @override
  String get backupAndExportSubtitle =>
      'Exportar lista de aplicaciones instaladas o importar desde copia';

  @override
  String get export => 'Exportar';

  @override
  String get import => 'Importar';

  @override
  String get selectExportLocation => 'Seleccionar ubicación de exportación';

  @override
  String exportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exportación exitosa: $count paquetes',
      one: 'Exportación exitosa: 1 paquete',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String message) {
    return 'Exportación fallida: $message';
  }

  @override
  String get importBackup => 'Importar copia de seguridad';

  @override
  String importBackupConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paquetes detectados en la copia. ¿Recuperar por lotes?',
      one: '1 paquete detectado en la copia. ¿Recuperar?',
    );
    return '$_temp0';
  }

  @override
  String get startRecovery => 'Iniciar recuperación';

  @override
  String get mirrorListSaved => 'Lista de espejos guardada';

  @override
  String get addMirror => 'Añadir espejo';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get pacmanMirrorManagement => 'Gestión de espejos de Pacman';

  @override
  String get save => 'Guardar';

  @override
  String get add => 'Añadir';

  @override
  String get general => 'General';

  @override
  String get advanced => 'Avanzado';

  @override
  String get repositories => 'Repositorios';

  @override
  String get aiSettings => 'Ajustes del Asistente de IA';

  @override
  String get aiEnabled => 'Activar Asistente de IA';

  @override
  String get aiEnabledDesc =>
      'Activar búsqueda impulsada por IA, explicación de aplicaciones y diagnóstico de errores.';

  @override
  String get aiProvider => 'Proveedor de IA';

  @override
  String get aiEndpoint => 'Punto de acceso API';

  @override
  String get aiModel => 'Nombre del modelo';

  @override
  String get aiApiKey => 'Clave API';

  @override
  String get aiProxy => 'Proxy de red (Opcional)';

  @override
  String get aiTemperature => 'Temperatura (Creatividad)';

  @override
  String get aiMaxTokens => 'Tokens máximos';

  @override
  String get aiTestButton => 'Probar conexión de IA';

  @override
  String get aiTestSuccess => '¡Conexión de IA exitosa!';

  @override
  String aiTestFailed(String error) {
    return 'Conexión de IA fallida: $error';
  }

  @override
  String get aiPromptExplain => 'Explicar con IA';

  @override
  String get aiPromptRecommend => 'Sugerencias de IA';

  @override
  String get aiPromptError => 'Analizar error con IA';

  @override
  String get aiPickDay => 'Recomendación diaria de la IA';

  @override
  String get aiPickDaySubtitle => 'Con la tecnología de OmniStore AI';

  @override
  String get aiCompareTitle => 'Comparación de variantes por IA';

  @override
  String get aiHealthTitle => 'Informe de salud del sistema por IA';

  @override
  String get aiHealthSubtitle => 'Diagnóstico inteligente para Arch Linux';

  @override
  String get aiCorrection => '¿Quisiste decir?';

  @override
  String get aiThinking => 'La IA está pensando...';

  @override
  String get magicSearch => 'Búsqueda inteligente';

  @override
  String get aiChangelogTitle => 'Resumen de actualizaciones por IA';

  @override
  String get aiCliTitle => 'Generador de comandos por IA';

  @override
  String get aiConflictTitle => 'Detección de conflictos por IA';

  @override
  String get aiCopyCommand => 'Copiar comando';

  @override
  String get aiRefineSearch => 'Refinar búsqueda con IA';

  @override
  String get aiExplainUpdate => 'Explicar esta actualización';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Cerrar';

  @override
  String get omnistore => 'OmniStore';

  @override
  String get installedApps => 'Aplicaciones instaladas';

  @override
  String get githubStore => 'Tienda de GitHub';

  @override
  String get flatpakStore => 'Tienda de Flatpak';

  @override
  String get locateInstallation => 'Localizar instalación';

  @override
  String get delete => 'Eliminar';

  @override
  String get welcomeTitle => 'Bienvenido a OmniStore';

  @override
  String get welcomeSubtitle =>
      'Ofreciendo una experiencia de gestión de aplicaciones simple y elegante para Arch Linux';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get skip => 'Omitir';

  @override
  String get envCheckTitle => 'Comprobación del entorno';

  @override
  String get envCheckSubtitle => 'Asegurando que su sistema esté listo';

  @override
  String get envFatalDesc =>
      'Su sistema no parece estar basado en Arch. La mayoría de las funciones no estarán disponibles.';

  @override
  String get envWarningDesc =>
      'Faltan algunos componentes necesarios. Podemos configurarlos por usted.';

  @override
  String get envOkDesc => '¡Todo listo! Su sistema es perfecto.';

  @override
  String get fixProblems => 'Corregir / Configurar todo';

  @override
  String get continueAnyway => 'Continuar de todos modos';

  @override
  String get sourceConfigTitle => 'Fuentes de software';

  @override
  String get sourceConfigSubtitle =>
      'Elige dónde puede buscar software OmniStore';

  @override
  String get enableAur => 'Activar AUR (Arch User Repository)';

  @override
  String get yayDesc => 'Activar AUR requiere instalar el asistente yay.';

  @override
  String get aurWarning =>
      'Advertencia de seguridad: Los paquetes AUR son contribuciones de usuarios. Asegúrese de confiar en la fuente.';

  @override
  String get bootstrapNote =>
      'Explorar no requiere autorización. Solo se solicita autorización de administrador cuando la configuración modifica el sistema.';

  @override
  String get feedbackDesc =>
      'Si encuentra problemas, por favor infórmenos en GitHub.';

  @override
  String get aiAssistant => 'Asistente de IA';

  @override
  String get aiAssistantDesc =>
      'Activar búsqueda asistida por IA, explicación de aplicaciones y diagnóstico de errores.';

  @override
  String get aiProviderDesc =>
      'Seleccione su fuente de modelo de IA (Local o Nube)';

  @override
  String get aiEndpointHelper => 'Ollama por defecto es http://localhost:11434';

  @override
  String get aiApiKeyHelper =>
      'Dejar en blanco para Ollama, introducir sk-xxx para OpenAI';

  @override
  String get howToGetApiKey => '¿Cómo obtener una clave API?';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama (Local): Descargue y ejecute Ollama, no se necesita clave. 2. Nube (OpenAI): Vaya al sitio web del proveedor, cree una clave API e introdúzcala aquí.';

  @override
  String get gotIt => 'Entendido';

  @override
  String get aiOllamaNote =>
      'Nota: Si usa Ollama, asegúrese de que se esté ejecutando con OLLAMA_ORIGINS=\"*\".';

  @override
  String get enterStore => 'Entrar a la tienda';

  @override
  String get nextStep => 'Siguiente paso';

  @override
  String get resetCache => 'Restablecer caché e historial';

  @override
  String get resetCacheDesc =>
      'Limpiar el historial de búsqueda y el caché de recomendaciones locales';

  @override
  String get resetCacheConfirm =>
      'Esto borrará su historial de búsqueda y el caché de recomendaciones. ¿Continuar?';

  @override
  String get resetting => 'Restableciendo...';

  @override
  String get resetSuccess => 'Caché e historial borrados con éxito';

  @override
  String resetFailed(String error) {
    return 'Error al restablecer: $error';
  }

  @override
  String get ollamaLocal => 'Ollama (Local)';

  @override
  String get openaiCompatible => 'Compatible con OpenAI';

  @override
  String get googleGemini => 'Google Gemini';

  @override
  String get importPackages => 'Importar paquetes';

  @override
  String importPackagesConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paquetes detectados. ¿Descargar por lotes?',
      one: '1 paquete detectado. ¿Descargar?',
    );
    return '$_temp0';
  }

  @override
  String get allDownloads => 'Descargar todo';

  @override
  String get importList => 'Importar lista';

  @override
  String get loadError =>
      'Error al cargar recomendaciones, por favor compruebe el estado del backend';

  @override
  String get community => 'Comunidad';

  @override
  String get official => 'Oficial';

  @override
  String get verified => 'Verificado';

  @override
  String installingPkg(String name) {
    return 'Instalando $name...';
  }

  @override
  String get switchSource => 'Cambiar';

  @override
  String get flatpakBetterDesc =>
      'Fuente Flatpak disponible, generalmente más estable.';

  @override
  String get aiAnalysisPrompt => '¿Analizar registros de errores con IA?';

  @override
  String get analyzeNow => 'Analizar ahora';

  @override
  String get cleanOrphans => 'Limpiar dependencias no utilizadas (huérfanos)';

  @override
  String get securityWarning => 'Advertencia de seguridad';

  @override
  String get aurSecurityDesc =>
      'AUR (Arch User Repository) es un repositorio mantenido por la comunidad. Dado que los paquetes son contribuciones de los usuarios, podría haber código inseguro. Antes de instalar, se recomienda revisar el PKGBUILD.';

  @override
  String get continueInstall => 'Continuar instalación';

  @override
  String get installInfo => 'Información de instalación';

  @override
  String get downloadSize => 'Tamaño de descarga';

  @override
  String get installedSize => 'Tamaño instalado';

  @override
  String dependenciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dependencias ($count)',
      one: 'Dependencia (1)',
    );
    return '$_temp0';
  }

  @override
  String get runningInBackground =>
      'OmniStore se está ejecutando en segundo plano, puede abrirlo mediante el icono de la bandeja.';

  @override
  String get clearSearch => 'Limpiar búsqueda';

  @override
  String get listView => 'Vista de lista';

  @override
  String get gridView => 'Vista de cuadrícula';

  @override
  String get categories => 'Categorías';

  @override
  String get clearHistory => 'Limpiar historial';

  @override
  String get clearHistoryShort => 'Limpiar historial';

  @override
  String get confirmClearHistory =>
      '¿Está seguro de que desea borrar todo el historial?';

  @override
  String get viewMore => 'Ver más';

  @override
  String get logDebug => 'DEPURACIÓN (DEBUG)';

  @override
  String get logInfo => 'INFORMACIÓN (INFO)';

  @override
  String get logWarning => 'ADVERTENCIA (WARNING)';

  @override
  String get logError => 'ERROR (ERROR)';

  @override
  String get notificationTitle => 'Actualizaciones disponibles';

  @override
  String notificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actualizaciones disponibles',
      one: '1 actualización disponible',
    );
    return '$_temp0';
  }

  @override
  String get preparingUpdate => 'Preparando actualización...';

  @override
  String get processing => 'Procesando';

  @override
  String get clear => 'Limpiar';

  @override
  String get retry => 'Reintentar';

  @override
  String get searchFailedSubtitle =>
      'No se pudo conectar con las fuentes de software. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String pluginCapabilities(int count) {
    return '$count capacidades';
  }

  @override
  String get aiResponseFailed => 'La IA no pudo responder.';

  @override
  String get aiAnalysisFailed => 'La IA no pudo analizar.';

  @override
  String cannotConnectToBackend(String error) {
    return 'No se puede conectar al servicio backend: $error';
  }

  @override
  String get taskInitializing => 'Inicializando tarea...';

  @override
  String get taskStarting => 'Iniciando...';

  @override
  String get taskSuccess => 'Tarea completada con éxito';

  @override
  String taskFailedWithCode(int code) {
    return 'La tarea falló con el código de salida $code';
  }

  @override
  String get taskCancelledByUser => 'Tarea cancelada por el usuario';

  @override
  String taskError(String error) {
    return 'Error: $error';
  }

  @override
  String get githubAuthTitle => 'Autenticación de GitHub';

  @override
  String get githubPatSaved => 'GitHub PAT guardado con éxito';

  @override
  String get saveToken => 'Guardar token';

  @override
  String get back => 'Atrás';

  @override
  String get next => 'Siguiente';

  @override
  String get aurFull => 'AUR (Arch User Repository)';

  @override
  String get flatpakFull => 'Flatpak (Flathub)';

  @override
  String get errorPackageNameRequired => 'El nombre del paquete es obligatorio';

  @override
  String errorStartFailed(String error) {
    return 'Error al iniciar: $error';
  }

  @override
  String errorUpdateFailed(String error) {
    return 'Error al actualizar: $error';
  }

  @override
  String checkUpdateFailed(String error) {
    return 'Error al buscar actualizaciones: $error';
  }

  @override
  String errorCleanFailed(String error) {
    return 'Error al limpiar: $error';
  }

  @override
  String errorFatalStream(String error) {
    return 'Error fatal de flujo de datos: $error';
  }

  @override
  String errorProcessStart(String error) {
    return 'Error al iniciar el proceso, por favor compruebe el entorno: $error';
  }

  @override
  String get taskForcedTerminated => 'Tarea terminada forzosamente';

  @override
  String get aiTimeout =>
      'Se ha agotado el tiempo de conexión con la IA, por favor inténtelo de nuevo más tarde.';

  @override
  String get aiNoResponse => 'La IA no pudo proporcionar una respuesta válida.';

  @override
  String get aiParseFailed =>
      'Error al analizar la respuesta de la IA: formato incorrecto.';

  @override
  String aiCallFailed(String error) {
    return 'La llamada al servicio de IA falló: $error';
  }

  @override
  String errorUpdateAll(String error) {
    return 'Error al actualizar todo: $error';
  }

  @override
  String get taskProcessing => 'Procesando';

  @override
  String get collapse => 'Contraer';

  @override
  String get expand => 'Expandir';

  @override
  String get all => 'Todo';

  @override
  String get relatedApps => 'Aplicaciones relacionadas';

  @override
  String get activeSources => 'Fuentes activas';

  @override
  String get autoDetect => 'Autodetectar';

  @override
  String get addCustomSource => 'Añadir fuente personalizada';

  @override
  String get addCustomSourceDesc =>
      'Configura repositorios Pacman/Flatpak, fuentes AppImage o fuentes GitHub/Bitu personalizadas';

  @override
  String get pacmanRepoType => 'Repositorio Pacman';

  @override
  String get pacmanRepoSafety =>
      'Solo se aceptan repositorios HTTPS con firmas de paquetes obligatorias. OmniStore no descarga claves ni ejecuta pacman -Sy; la fuente se aplica en la próxima actualización completa del sistema.';

  @override
  String get sourceType => 'Tipo de fuente';

  @override
  String get githubRepoType => 'Repositorio de GitHub (owner/repo)';

  @override
  String get bituRepoType =>
      'Bitu / Bitbucket (espacio de trabajo/repositorio)';

  @override
  String get flatpakRemoteType => 'Remoto de Flatpak';

  @override
  String get appImageFeedType => 'URL de feed de AppImage';

  @override
  String get sourceName => 'Nombre de la fuente';

  @override
  String get hintCustomAppName => 'ej. mi-app-personalizada';

  @override
  String get repoOwnerRepo => 'Repositorio (owner/repo)';

  @override
  String get sourceUrl => 'URL';

  @override
  String get hintRepoFormat => 'ej. flutter/flutter';

  @override
  String get hintFeedUrl => 'ej. https://ejemplo.com/feed.json';

  @override
  String get errorNameUrlRequired =>
      'El nombre y la URL/Repo no pueden estar vacíos';

  @override
  String get addingCustomSource => 'Añadiendo fuente personalizada...';

  @override
  String get sourceAddSuccess => '¡Fuente añadida con éxito!';

  @override
  String get sourceAddFailed => 'Error al añadir la fuente.';

  @override
  String get autoDetectingSources =>
      'Autodetectando fuentes disponibles para su sistema...';

  @override
  String get autoDetectSuccess =>
      '¡Autodetección completada y ajustes guardados!';

  @override
  String get autoDetectFailed => 'Error al guardar los ajustes autodetectados.';

  @override
  String get personalAccessToken => 'Token de acceso personal';

  @override
  String get copyName => 'Copiar nombre';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get tapToCopy => 'Toca para copiar';

  @override
  String get language => 'Idioma de la interfaz';

  @override
  String get languageSubtitle => 'Requiere reiniciar para aplicarse';

  @override
  String get restartTitleBar =>
      'Reinicie la aplicación para aplicar los cambios en la barra de título';

  @override
  String get enableDaemon => 'Activar demonio de actualización';

  @override
  String get enableDaemonDesc =>
      'Buscar actualizaciones periódicamente en segundo plano';

  @override
  String get autoUpdate => 'Actualización automática silenciosa';

  @override
  String get autoUpdateDesc =>
      'Descargar e instalar actualizaciones automáticamente en segundo plano';

  @override
  String get checkIntervalTitle => 'Frecuencia de comprobación';

  @override
  String checkIntervalSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Comprobar cada $hours horas',
      one: 'Comprobar cada hora',
    );
    return '$_temp0';
  }

  @override
  String get typography => 'Tipografía';

  @override
  String get fontFamily => 'Familia de fuentes';

  @override
  String get fontScale => 'Escala de fuente';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String hourValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get langSimplifiedChinese => 'Chino simplificado';

  @override
  String get langTraditionalChinese => 'Chino tradicional';

  @override
  String get langEnglish => 'Inglés';

  @override
  String get langJapanese => 'Japonés';

  @override
  String get langSpanish => 'Español';

  @override
  String get taskInProgress => 'Otra tarea ya está en progreso';

  @override
  String get trayInitFailedDisabled =>
      'Error al inicializar la bandeja del sistema. Cerrar a la bandeja desactivado.';

  @override
  String get errorTitle => 'Error';

  @override
  String get appDetailsNotFound =>
      'No se encontraron detalles de la aplicación';

  @override
  String diskSpaceInfo(String free, String total) {
    return 'Espacio en disco: $free GB libres / $total GB en total';
  }

  @override
  String cacheTypeInfo(String pacman, String flatpak, String custom) {
    return 'Pacman: $pacman MB | Flatpak: $flatpak MB | Personalizado: $custom MB';
  }

  @override
  String get backSemanticsLabel => 'Atrás';

  @override
  String get backSemanticsHint => 'Volver a la pantalla anterior';

  @override
  String categorySemantics(String name) {
    return 'Categoría: $name';
  }

  @override
  String get temperatureRangeError => 'El valor debe estar entre 0.0 y 2.0';

  @override
  String get enableSystemdService => 'Habilitar servicio de fondo systemd';

  @override
  String get enableSystemdServiceDesc =>
      'Permitir registrar el temporizador de systemd para buscar actualizaciones cuando la aplicación está cerrada';

  @override
  String get taskHistory => 'Historial de tareas';

  @override
  String get unknownApp => 'Aplicación desconocida';

  @override
  String get taskSuccessMsg => 'Completada correctamente';

  @override
  String failureReason(String message) {
    return 'Razón del fallo: $message';
  }

  @override
  String get noPackagesAvailable => 'No hay paquetes disponibles';

  @override
  String get noDescription => 'Sin descripción.';

  @override
  String get viewDetails => 'Ver detalles';

  @override
  String get ok => 'Aceptar';

  @override
  String get checkNetwork =>
      'Compruebe su conexión a la red e inténtelo de nuevo';

  @override
  String get githubStoreSubtitle =>
      'Descubre y descarga aplicaciones directamente desde las versiones de GitHub';

  @override
  String get searchGithubHint => 'Busca repositorios de GitHub...';

  @override
  String get recommended => 'Recomendado';

  @override
  String get rankings => 'Clasificaciones';

  @override
  String get trending => 'Tendencias';

  @override
  String get latestUpdates => 'Últimas actualizaciones';

  @override
  String get searchNoResultsSubtitle =>
      'Prueba otra palabra clave o habilita más fuentes de software';

  @override
  String get pluginsAndSources => 'Complementos y fuentes';

  @override
  String get refreshPlugins => 'Actualizar complementos';

  @override
  String get noPluginsFound => 'No se encontraron complementos';

  @override
  String get builtin => 'Integrado';

  @override
  String get legacy => 'Heredado';

  @override
  String get pluginUpdated => 'Complemento actualizado';

  @override
  String get pluginUpdateFailed => 'Error al actualizar el complemento';

  @override
  String get pluginRemoved => 'Complemento eliminado';

  @override
  String get pluginRemovalFailed => 'Error al eliminar el complemento';

  @override
  String get removePlugin => 'Eliminar complemento';

  @override
  String get managed => 'Gestionado';

  @override
  String get readOnly => 'Solo lectura';

  @override
  String get installationDecisionTitle =>
      'Asistente de Decisión de Instalación';

  @override
  String recommendedSource(String source) {
    return 'Fuente Recomendada: $source';
  }

  @override
  String get preflightChecks => 'Comprobaciones Previas';

  @override
  String get potentialRisks => 'Riesgos Potenciales';

  @override
  String get continueInstallation => 'Continuar Instalación';

  @override
  String get changeRecommendation => 'Cambiar recomendación';

  @override
  String get aiPickDisclaimer =>
      'Generado en función de su búsqueda, historial de instalación y fuentes disponibles actualmente; no afectará sus opciones de instalación.';

  @override
  String get quickStart => 'Inicio rápido';

  @override
  String get importListSubtitle =>
      'Importa tus paquetes de uso frecuente desde una lista';

  @override
  String get emptyTrendingMessage =>
      'No hay datos de tendencias disponibles; se actualizarán automáticamente cuando se restablezca la conexión.';

  @override
  String get emptyRecommendationsMessage =>
      'Las sugerencias personalizadas aparecerán aquí después de buscar o instalar aplicaciones.';

  @override
  String get aiPickFallbackMessage =>
      'No se pueden generar recomendaciones personalizadas en este momento. Aún puedes explorar las selecciones de los editores o volver a intentarlo más tarde.';

  @override
  String get meoarchAccount => 'Cuenta de MeoArch';

  @override
  String get defaultUser => 'Usuario';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get syncStatus => 'Estado de sincronización';

  @override
  String get syncStatusSubtitle =>
      'Toca para guardar tu lista de aplicaciones de OmniStore';

  @override
  String get manageAccount => 'Gestionar cuenta';

  @override
  String get manageAccountSubtitle => 'Seguridad, MFA y sesiones';

  @override
  String get signInTitle => 'Iniciar sesión en MeoArch';

  @override
  String get signInSubtitle =>
      'Sincroniza tus aplicaciones, configuraciones y favoritos entre dispositivos.';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta de MeoArch';

  @override
  String get orDivider => 'O';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithGitHub => 'Continuar con GitHub';

  @override
  String get enterEmailAndPassword =>
      'Por favor, introduce el correo electrónico y la contraseña.';

  @override
  String signInFailed(String message) {
    return 'Error al iniciar sesión: $message';
  }

  @override
  String signInError(String message) {
    return 'Error al iniciar sesión: $message';
  }

  @override
  String get githubIntegration => 'Integración con GitHub';

  @override
  String get configurePat => 'Token de acceso de GitHub (opcional)';

  @override
  String get patHelperText =>
      'Proporcione un PAT clásico de GitHub o un Token de grano fino.';

  @override
  String get featuredSubtitle =>
      'Mantenido por OmniStore, disponible incluso sin conexión';

  @override
  String get editorPicks => 'Selección del editor';

  @override
  String get checkingEnvStatus => 'Comprobando el estado del entorno...';

  @override
  String get envDetailsFailed => 'Error al obtener los detalles del entorno.';

  @override
  String get bootstrapProgress => 'Progreso de configuración:';

  @override
  String get systemDetails => 'Detalles del sistema:';

  @override
  String get aiIntegrationDesc =>
      'Habilitar funciones de integración inteligente';

  @override
  String get ollamaLocalOffline => 'Ollama (Local / Sin conexión)';

  @override
  String get openaiCloud => 'OpenAI API (Nube)';

  @override
  String get testConnection => 'Probar conexión';

  @override
  String get githubSearchFailed => 'Error en la búsqueda de GitHub';

  @override
  String get githubStoreUnavailable => 'Tienda de GitHub no disponible';

  @override
  String get noGithubReposFound => 'No se encontraron repositorios de GitHub';

  @override
  String get pullToRefreshCategory =>
      'Deslice hacia abajo para actualizar o pruebe otra categoría.';

  @override
  String get systemAiProviderLabel =>
      'System AI connection (KWallet / Recommended)';

  @override
  String get systemAiSharedConnectionLabel => 'System shared connection';

  @override
  String get systemAiConnectionHelper =>
      'Meo Account reads the key from KWallet; OmniStore cannot read the plaintext.';

  @override
  String get systemAiLoadingTitle => 'Reading system AI connections';

  @override
  String get systemAiMetadataOnly =>
      'Only names, endpoints, and default models are read; keys are never read.';

  @override
  String get systemAiLoadErrorTitle => 'Unable to read system AI connections';

  @override
  String get systemAiSelectLabel => 'AI connection on this device';

  @override
  String get meoSettingsOpenFailed => 'Unable to open Meo Settings.';

  @override
  String get manageInMeoSettings => 'Manage in Meo Settings';

  @override
  String get systemAiNoConnections =>
      'No system AI connection is configured. Add one in Meo Settings first.';

  @override
  String get systemAiLoadFailed =>
      'Unable to read system AI connections. Check Accounts & Security in Meo Settings.';

  @override
  String get systemAiInvalidCatalog =>
      'The system AI service returned an invalid model catalog.';

  @override
  String get systemAiInvalidConsent =>
      'The system AI service did not return a valid consent summary.';

  @override
  String get systemAiConsentExpired =>
      'The system AI consent summary is invalid or expired.';

  @override
  String get systemAiInvalidResponse =>
      'The system AI service did not return valid text.';

  @override
  String get systemAiUnsupported =>
      'System AI is not supported on this platform.';

  @override
  String get systemAiOperationFailed => 'The system AI operation failed.';

  @override
  String get systemAiTimeout => 'The system AI operation timed out.';

  @override
  String get systemAiUnavailable =>
      'Unable to connect to the Meo Account system AI service.';

  @override
  String get systemAiTestPurpose => 'Test the OmniStore system AI connection';

  @override
  String get aiConsentCancelled => 'You cancelled this AI request.';

  @override
  String get chooseSystemAiConnection =>
      'Select a system AI connection in OmniStore Settings first.';

  @override
  String get chooseAccountAiConnection =>
      'Select an account AI connection in OmniStore Settings first.';

  @override
  String get aiConfigUnavailable => 'AI configuration is unavailable.';

  @override
  String get aiNotEnabled => 'AI assistance is not enabled.';

  @override
  String get aiAccountProviderHint =>
      'Meo Account invokes your saved connection; the API key is never sent to OmniStore.';

  @override
  String get aiSystemProviderHint =>
      'Meo Account invokes the connection from KWallet; OmniStore sees only metadata and the final result.';

  @override
  String get aiOllamaProviderHint =>
      'Ollama connects only to the local service and does not require an API key.';

  @override
  String get aiCompatibleProviderHint =>
      'Use only a trusted HTTPS-compatible endpoint; the key remains in the local secure store.';

  @override
  String get aiLocalKeyProviderHint =>
      'This provider has a separate key in Secret Service/KWallet that cannot be read back.';

  @override
  String get meoAccountOpenFailed => 'Unable to open Meo Account.';

  @override
  String get secureCredentialWriteFailed =>
      'Unable to write to the system credential store.';

  @override
  String get modelsNoneFound =>
      'The service is running, but no installed or available models were reported.';

  @override
  String get modelsAutofilled =>
      'A discovered model was filled in automatically.';

  @override
  String get modelsFoundChoose =>
      'Models were found. Choose one before testing; OmniStore does not infer capabilities from names.';

  @override
  String get apiKeyRequired => 'Enter a new API key first.';

  @override
  String get secureCredentialSaved =>
      'The API key was saved to the system credential store.';

  @override
  String get localApiKeyDeleted => 'The local API key was deleted.';

  @override
  String get secureCredentialUnavailable =>
      'Unable to access the system credential store.';

  @override
  String get signInMeoAccount => 'Sign in to Meo Account';

  @override
  String get signInMeoAccountDetail =>
      'After signing in, choose an encrypted account AI connection. Its API key is never sent to OmniStore.';

  @override
  String get accountAiLoading => 'Reading account AI connections';

  @override
  String get accountAiMetadataOnly =>
      'Only names, providers, and masked key status are read.';

  @override
  String get accountAiLoadError => 'Unable to read account AI connections';

  @override
  String get accountAiNone => 'No AI connection is saved in this account';

  @override
  String get accountAiNoneDetail =>
      'Add your API key securely in Account, then return here and refresh.';

  @override
  String get connect => 'Connect';

  @override
  String get accountAiSelectLabel => 'Account AI connection';

  @override
  String get accountAiConnectionHelper =>
      'The key is decrypted only inside the Account Edge broker; OmniStore cannot read it.';

  @override
  String get manageAiConnections => 'Manage AI connections';

  @override
  String get aiPerRequestConsentDetail =>
      'Before every request, OmniStore shows the provider, model, purpose, data categories, full content, and request fingerprint, then asks for one-time consent.';

  @override
  String get aiEnabledConsentDesc =>
      'Off by default; every request still requires separate confirmation after it is enabled.';

  @override
  String providerLocalSecureKey(String provider) {
    return '$provider (local secure key)';
  }

  @override
  String get providerCompatibleHttps => 'OpenAI Compatible (custom HTTPS)';

  @override
  String get providerMeoAccount => 'Meo Account';

  @override
  String get ollamaEndpointSafety =>
      'Defaults to local Ollama. Keep a loopback address to avoid contacting a LAN service accidentally.';

  @override
  String get compatibleEndpointSafety =>
      'Enter only a trusted HTTPS-compatible endpoint without a key or query parameters.';

  @override
  String get accountModelOverride => 'Account model';

  @override
  String get accountModelDefaultHelper =>
      'Leave empty to use the selected Account connection\'s default model.';

  @override
  String get modelReviewHelper =>
      'The actual model is shown again for confirmation before every request.';

  @override
  String get detectLocalModels => 'Detect local models and fill one in';

  @override
  String get readModelCatalog => 'Read model catalog';

  @override
  String get installOllamaWithOmniStore => 'Install Ollama with OmniStore';

  @override
  String get chooseDiscoveredModel => 'Choose a discovered model';

  @override
  String get localKeyStored =>
      'A separate secure key is saved for this provider';

  @override
  String get localKeyNotStored => 'No API key is saved for this provider';

  @override
  String get localKeysHelper =>
      'Each provider is stored separately in Secret Service/KWallet; keys can be replaced or deleted but never read back.';

  @override
  String get newApiKeyLabel => 'New API key (cleared after saving)';

  @override
  String get newApiKeyHelper =>
      'Enter only a replacement key. Existing keys cannot be read or copied.';

  @override
  String get hideInput => 'Hide input';

  @override
  String get showInput => 'Show input';

  @override
  String get saveOrReplace => 'Save securely / Replace';

  @override
  String get deleteLocalKey => 'Delete local key';

  @override
  String get temperatureHelper =>
      '0–2; lower values are usually more stable, and out-of-range values are not saved.';

  @override
  String get aiTestScopeHelper =>
      'Testing checks only the current connection and does not change the AI enable switch; real requests still require one-time consent.';

  @override
  String get meoUpdateChannel => 'Meo update channel';

  @override
  String get meoUpdateChannelSubtitle =>
      'Read from your active Pacman repositories';

  @override
  String get meoChannelChecking => 'Checking update channel…';

  @override
  String get meoChannelStable => 'Stable';

  @override
  String get meoChannelBeta => 'Beta';

  @override
  String get meoChannelBetaSummary =>
      'Get newer Meo components before Stable. Arch system packages keep their normal repositories.';

  @override
  String get meoChannelStableSummary =>
      'Get fully tested MeoArch release trains.';

  @override
  String meoChannelRepositoryPriority(String repositories) {
    return 'Repository priority: $repositories';
  }

  @override
  String get meoChannelBetaNotice =>
      'Choose Beta only when you want newer components before Stable. It is not recommended for critical systems; Stable remains available as the fallback.';

  @override
  String meoChannelDowngradePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Stable is selected, but $count Meo package downgrades still need your review.',
      one: 'Stable is selected, but 1 Meo package downgrade still needs your review.',
    );
    return '$_temp0';
  }

  @override
  String get meoChannelReviewDowngrades => 'Review downgrades';

  @override
  String get meoChannelSwitchToStable => 'Switch to Stable';

  @override
  String get meoChannelRollbackPreviewInvalid =>
      'This Stable rollback preview is no longer valid. Refresh it and review it again.';

  @override
  String meoChannelDowngradeDialog(String packages) {
    return 'These official Meo packages will move to their Stable versions. Arch and third-party packages won\'t be downgraded.\\n\\n$packages';
  }

  @override
  String sourceFilterSemantics(String name) {
    return 'Filtrar por origen: $name';
  }

  @override
  String get aiConsentTitle => 'Review this AI request';

  @override
  String get aiConsentIntro =>
      'Review the exact request before sending it. Your confirmation applies only to this request and its fingerprint.';

  @override
  String get aiConsentProvider => 'Provider';

  @override
  String get aiConsentDestination => 'Destination';

  @override
  String get aiConsentModel => 'Model';

  @override
  String get aiConsentPurpose => 'Purpose';

  @override
  String get aiConsentDataCategories => 'Data included';

  @override
  String get aiConsentCharacters => 'Characters';

  @override
  String get aiConsentFingerprint => 'Fingerprint';

  @override
  String get aiConsentReviewContent => 'Review content to be sent';

  @override
  String get aiConsentSystemInstruction => 'System instruction';

  @override
  String get aiConsentUserContent => 'Your content';

  @override
  String aiConsentConfirmWithProvider(String provider) {
    return 'I understand this content will be sent to $provider.';
  }

  @override
  String get aiConsentKeyNotExposed =>
      'Your API key is not part of this prompt and is not shown here.';

  @override
  String get aiConsentDeny => 'Don\'t send';

  @override
  String get aiConsentAllowOnce => 'Confirm and send once';

  @override
  String get aiConsentCategoryAppName => 'App name';

  @override
  String get aiConsentCategoryAppDescription => 'App description';

  @override
  String get aiConsentCategoryVersionMetadata => 'Version information';

  @override
  String get aiConsentCategoryPackageSource => 'Package source';

  @override
  String get aiConsentCategoryPackageVariants => 'Installation options';

  @override
  String get aiConsentCategoryPreferenceRequest => 'Preference request';

  @override
  String get aiConsentCategorySearchQuery => 'Search query';

  @override
  String get aiConsentCategorySystemEnvironment => 'System environment summary';

  @override
  String get aiConsentCategoryErrorLog => 'Error log';

  @override
  String get aiConsentCategoryRecommendationRequest => 'Recommendation request';

  @override
  String get aiConsentCategoryConnectionTest => 'Connection test data';

  @override
  String get githubLoadErrorDetail =>
      'Could not load GitHub repositories. Check your network and try again.';

  @override
  String get githubSearchErrorDetail =>
      'Could not search GitHub repositories. Check your network and try again.';

  @override
  String get flatpakLoadErrorDetail =>
      'Could not load Flatpak apps. Check Flathub and your network connection, then try again.';

  @override
  String appCardSemantics(String name) {
    return 'App: $name';
  }

  @override
  String get diskSize => 'Disk size';

  @override
  String diskSizeWithConfidence(String confidence) {
    return 'Disk size ($confidence)';
  }

  @override
  String get accountAiSignInRequired =>
      'Sign in to Meo Account before using Account AI.';

  @override
  String get accountAiNoDefaultModel =>
      'This AI connection has no default model. Choose a model in Settings first.';

  @override
  String get accountAiInvalidConsent =>
      'The account AI service did not return a valid consent summary.';

  @override
  String get accountAiConsentExpired =>
      'The AI consent summary is invalid or expired.';

  @override
  String get accountAiInvalidResponse =>
      'The AI service did not return valid content.';

  @override
  String get accountAiTestPurpose => 'Test the OmniStore account AI connection';

  @override
  String get accountAiInvalidDestination =>
      'The account AI connection has an invalid destination.';

  @override
  String get accountAiConnectionNotFound =>
      'The selected AI connection is unavailable. Choose it again in Settings.';

  @override
  String get accountAiInvalidData =>
      'The account AI service returned invalid data.';

  @override
  String get accountAiUnavailable =>
      'The account AI service is temporarily unavailable.';

  @override
  String get accountAiRequestDenied =>
      'The account AI request was denied. Sign in again and try once more.';

  @override
  String get accountAiConnectionFailed =>
      'Unable to connect to the account AI service.';

  @override
  String get localAiUnsupportedModelDiscovery =>
      'This connection does not support local model discovery.';

  @override
  String get localAiCredentialStoreUnavailable =>
      'Unable to open the secure credential store. Unlock KWallet and try again.';

  @override
  String get localAiApiKeyRequired =>
      'Securely save an API key for this provider first.';

  @override
  String get localAiCatalogTooLarge =>
      'The model catalog response is too large.';

  @override
  String get localAiInvalidCatalog =>
      'The model catalog returned invalid data.';

  @override
  String get localAiCatalogUnavailable =>
      'Unable to read the model catalog. Check that the service is running.';

  @override
  String get localAiUnsupportedConnection =>
      'This local AI connection type is not supported.';

  @override
  String get localAiInvalidModel => 'Enter a valid model name.';

  @override
  String get localAiInvalidPurpose => 'The AI request purpose is invalid.';

  @override
  String get localAiInvalidInput => 'The AI input is empty or too large.';

  @override
  String get localAiInvalidDataCategories =>
      'The AI data categories are invalid.';

  @override
  String get localAiApiKeyInvalid =>
      'The secure credential store has no valid API key for this provider.';

  @override
  String get localAiDestinationChanged =>
      'The AI destination changed after consent, so the request was blocked.';

  @override
  String get localAiResponseTooLarge => 'The AI service response is too large.';

  @override
  String get localAiInvalidResponse => 'The AI service returned invalid data.';

  @override
  String get localAiNoResponseText => 'The AI service did not return text.';

  @override
  String get localAiConnectionFailed =>
      'Unable to connect to the AI service, or the request timed out.';

  @override
  String get localAiTestPurpose =>
      'Test the OmniStore local secure AI connection';

  @override
  String get localAiInvalidEndpoint => 'The AI service address is invalid.';

  @override
  String get localAiOllamaLoopbackRequired =>
      'The Ollama address must use local HTTP(S) loopback.';

  @override
  String get localAiHttpsRequired => 'Cloud AI services must use HTTPS.';

  @override
  String get localAiPrivateEndpointBlocked =>
      'A compatible API cannot point to a local or private network. Use Ollama for local models.';

  @override
  String get localAiOllama => 'Ollama (on this device)';

  @override
  String get localAiApiKeyRejected => 'The AI service rejected the API key.';

  @override
  String get localAiModelOrEndpointNotFound =>
      'The requested AI model or service address was not found.';

  @override
  String get localAiRateLimited =>
      'The AI service is out of quota or receiving requests too quickly.';

  @override
  String get localAiUnavailable => 'The AI service is temporarily unavailable.';

  @override
  String localAiRequestRejected(int status) {
    return 'The AI service rejected the request (HTTP $status).';
  }

  @override
  String get aiTestService => 'Service';

  @override
  String get aiTestConnected => 'Connected';

  @override
  String get aiTestUnavailable => 'Unavailable';

  @override
  String get aiTestReady => 'Ready';

  @override
  String get aiTestNotReady => 'Not ready';

  @override
  String get aiTestLatency => 'Latency';

  @override
  String featuredAppSemantics(String name) {
    return 'Featured app: $name';
  }
}
