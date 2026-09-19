/// A validated request delivered through the public OmniStore command line.
///
/// Public contract:
///   `omnistore install package-id [--source source]`
///
/// Parsing this request never starts an installation. The OmniStore UI must
/// still show its own confirmation dialog before invoking the task backend.
class ExternalInstallRequest {
  const ExternalInstallRequest({required this.packageId, required this.source});

  final String packageId;
  final String source;

  static const Map<String, String> _sources = {
    'native': 'Native',
    'pacman': 'Native',
    'aur': 'AUR',
    'flatpak': 'Flatpak',
    'github': 'GitHub',
    'bitu': 'Bitu',
  };

  static final RegExp _nativePackage = RegExp(
    r'^[a-z0-9][a-z0-9@._+\-]{0,127}$',
  );
  static final RegExp _flatpakPackage = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._\-]{1,191}$',
  );
  static final RegExp _repositoryPackage = RegExp(
    r'^[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+$',
  );

  static ExternalInstallRequest? fromArguments(Iterable<String> arguments) {
    final args = arguments.toList(growable: false);
    if (args.isEmpty || args.first != 'install') return null;

    if (args.length != 2 && args.length != 4) {
      throw const FormatException(
        'Usage: omnistore install <package-id> [--source <source>]',
      );
    }
    if (args.length == 4 && args[2] != '--source') {
      throw const FormatException(
        'Only --source is accepted after package-id.',
      );
    }

    final sourceKey = args.length == 4 ? args[3].toLowerCase() : 'native';
    final source = _sources[sourceKey];
    if (source == null) {
      throw FormatException('Unsupported OmniStore source: ${args[3]}');
    }

    final packageId = args[1];
    final valid = switch (source) {
      'Native' || 'AUR' => _nativePackage.hasMatch(packageId),
      'Flatpak' => _flatpakPackage.hasMatch(packageId),
      'GitHub' || 'Bitu' => _repositoryPackage.hasMatch(packageId),
      _ => false,
    };
    if (!valid) {
      throw FormatException('Invalid package identifier for $source.');
    }

    return ExternalInstallRequest(packageId: packageId, source: source);
  }
}
