import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/onboarding/source_setup_profile.dart';

void main() {
  test('Ubuntu recommendations enable its plugin without Arch or arbitrary sources', () {
    final profile = SourceSetupProfile.fromEnvironment({
      'system': {
        'platform': 'linux',
        'native_manager': 'apt',
        'recommended_sources': [
          'apt',
          'flatpak',
          'appimage',
          'aur',
          'dnf',
          'attacker.plugin',
          42,
        ],
      },
    });
    final sources = <String, dynamic>{
      'pacman': true,
      'github': true,
      'fdroid': true,
    };
    final plugins = <String, dynamic>{'thirdparty.custom': true};
    profile.apply(sources, plugins, enableAur: true);
    expect(sources['apt'], isTrue);
    expect(plugins['builtin.apt'], isTrue);
    expect(sources['pacman'], isFalse);
    expect(sources['aur'], isFalse);
    expect(sources['dnf'], isFalse);
    expect(sources['github'], isTrue);
    expect(sources['fdroid'], isTrue);
    expect(plugins['thirdparty.custom'], isTrue);
    expect(plugins.containsKey('builtin.attacker.plugin'), isFalse);
  });

  test('AUR remains opt in only on an Arch host', () {
    final profile = SourceSetupProfile.fromEnvironment({
      'system': {
        'platform': 'linux',
        'native_manager': 'pacman',
        'recommended_sources': ['pacman', 'flatpak', 'appimage', 'aur'],
      },
    });
    final sources = <String, dynamic>{};
    final plugins = <String, dynamic>{};
    profile.apply(sources, plugins, enableAur: false);
    expect(sources['aur'], isFalse);
    profile.apply(sources, plugins, enableAur: true);
    expect(plugins['builtin.aur'], isTrue);
  });

  test('immutable Linux does not enable a mutating host manager', () {
    final profile = SourceSetupProfile.fromEnvironment({
      'system': {
        'platform': 'linux',
        'native_manager': 'dnf',
        'immutable': true,
        'recommended_sources': ['dnf', 'flatpak', 'appimage'],
      },
    });
    final sources = <String, dynamic>{'dnf': true};
    profile.apply(sources, {}, enableAur: true);
    expect(sources['dnf'], isFalse);
    expect(sources['flatpak'], isTrue);
  });

  test(
    'unknown profiles retain settings and Windows removes Linux defaults',
    () {
      final sources = <String, dynamic>{
        'pacman': true,
        'flatpak': true,
        'scoop': true,
      };
      SourceSetupProfile.fromEnvironment({})
          .apply(sources, {}, enableAur: false);
      expect(sources['pacman'], isTrue);
      SourceSetupProfile.fromEnvironment({
        'system': {
          'platform': 'windows',
          'native_manager': 'winget',
          'recommended_sources': ['winget', 'apt'],
        },
      }).apply(sources, {}, enableAur: false);
      expect(sources['pacman'], isFalse);
      expect(sources['flatpak'], isFalse);
      expect(sources['winget'], isTrue);
      expect(sources['scoop'], isTrue);
    },
  );
}
