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
  String get variant => 'Variantes disponibles';

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
    return '¿Deseas realizar esta acción en $name?';
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
  String get upToDate => 'Todas las aplicaciones están al día';

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
  String get noActiveTasks => 'No hay tareas activas';

  @override
  String get currentTask => 'Tarea actual';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get allUpdated => 'Todas las aplicaciones están al día';

  @override
  String get update => 'Actualizar';

  @override
  String get enableSystemTray => 'Activar bandeja del sistema';

  @override
  String get systemCleaning => 'Limpieza del sistema';

  @override
  String get systemCleaningDesc =>
      'Eliminar paquetes huérfanos y limpiar caché de pacman';

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
  String get aiPromptExplain => 'Análisis';

  @override
  String get aiPromptRecommend => 'Sugerencias de IA';

  @override
  String get aiPromptError => 'Análisis de errores';

  @override
  String get aiPickDay => 'Selección del día de la IA';

  @override
  String get aiPickDaySubtitle => 'Impulsado por OmniStore AI';

  @override
  String get aiCompareTitle => 'Comparación de variantes por IA';

  @override
  String get aiHealthTitle => 'Informe de salud del sistema por IA';

  @override
  String get aiHealthSubtitle => 'Diagnóstico inteligente para su Arch Linux';

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
  String get aiRefineSearch => 'Refinamiento de búsqueda con IA';

  @override
  String get aiExplainUpdate => 'Análisis de actualización';

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
  String get sourceConfigSubtitle => 'Elija las fuentes que desea habilitar';

  @override
  String get enableAur => 'Activar AUR (Arch User Repository)';

  @override
  String get yayDesc => 'Activar AUR requiere instalar el asistente yay.';

  @override
  String get aurWarning =>
      'Advertencia de seguridad: Los paquetes AUR son contribuciones de usuarios. Asegúrese de confiar en la fuente.';

  @override
  String get bootstrapNote =>
      'Nota: La configuración puede requerir introducir su contraseña varias veces.';

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
      'Configure remotos de Flatpak personalizados, feeds de AppImage o repositorios de GitHub/Bitu';

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
  String get taskSuccessMsg => 'Tarea ejecutada con éxito';

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
  String get searchNoResultsSubtitle => 'Intente buscar otra cosa';

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
  String get quickStart => 'Inicio rápido';

  @override
  String get importListSubtitle =>
      'Importe sus paquetes de uso común desde una lista';

  @override
  String get aiPickSubtitleDesc =>
      'Generado en función de su historial de búsqueda, instalación y fuentes activas actuales; no afecta las opciones de instalación.';

  @override
  String get aiPickFallbackBlurb =>
      'Temporalmente no se pueden generar recomendaciones personalizadas. Aún puede explorar aplicaciones destacadas o intentarlo de nuevo más tarde.';

  @override
  String get changeRecommendation => 'Cambiar recomendación';

  @override
  String get emptyTrendingMessage =>
      'No hay datos de tendencias disponibles; se actualizarán automáticamente cuando se restablezca la red.';

  @override
  String get emptyForYouMessage =>
      'Continúe buscando o instalando aplicaciones para ver sugerencias personalizadas aquí.';

  @override
  String get featuredEditorsChoice => 'Elección de los editores';

  @override
  String get featuredSubtitle =>
      'Mantenido por OmniStore, siempre visible incluso sin conexión';
}
