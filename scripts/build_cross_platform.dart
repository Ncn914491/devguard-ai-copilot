import 'dart:io';
import 'dart:convert';

/// Cross-platform build script for DevGuard AI Copilot
/// Builds for Web, Android, and Windows platforms
void main(List<String> args) async {
  print('🚀 DevGuard AI Copilot - Cross-Platform Build Script');
  print('=' * 60);

  final platforms = args.isEmpty ? ['web', 'android', 'windows'] : args;
  final buildResults = <String, bool>{};

  for (final platform in platforms) {
    print('\n📦 Building for $platform...');
    final success = await buildForPlatform(platform);
    buildResults[platform] = success;

    if (success) {
      print('✅ $platform build completed successfully');
    } else {
      print('❌ $platform build failed');
    }
  }

  // Print summary
  print('\n' + '=' * 60);
  print('📊 Build Summary:');
  buildResults.forEach((platform, success) {
    final status = success ? '✅' : '❌';
    print('  $status $platform');
  });

  final allSuccessful = buildResults.values.every((success) => success);
  if (allSuccessful) {
    print('\n🎉 All builds completed successfully!');
    await generateBuildInfo(buildResults);
  } else {
    print('\n⚠️  Some builds failed. Check the output above for details.');
    exit(1);
  }
}

Future<bool> buildForPlatform(String platform) async {
  try {
    switch (platform.toLowerCase()) {
      case 'web':
        return await buildWeb();
      case 'android':
        return await buildAndroid();
      case 'windows':
        return await buildWindows();
      case 'apk':
        return await buildApk();
      default:
        print('❌ Unknown platform: $platform');
        return false;
    }
  } catch (e) {
    print('❌ Error building $platform: $e');
    return false;
  }
}

Future<bool> buildWeb() async {
  print('  🌐 Building for Web...');

  final result = await Process.run(
    'flutter',
    [
      'build',
      'web',
      '--release',
      '--web-renderer',
      'canvaskit',
      '--dart-define=FLUTTER_WEB_USE_SKIA=true',
    ],
  );

  if (result.exitCode == 0) {
    print('  📁 Web build output: build/web/');
    return true;
  } else {
    print('  ❌ Web build failed:');
    print(result.stderr);
    return false;
  }
}

Future<bool> buildAndroid() async {
  print('  🤖 Building Android App Bundle...');

  final result = await Process.run(
    'flutter',
    [
      'build',
      'appbundle',
      '--release',
      '--dart-define=FLUTTER_WEB_USE_SKIA=false',
    ],
  );

  if (result.exitCode == 0) {
    print('  📁 Android build output: build/app/outputs/bundle/release/');
    return true;
  } else {
    print('  ❌ Android build failed:');
    print(result.stderr);
    return false;
  }
}

Future<bool> buildApk() async {
  print('  📱 Building Android APK...');

  final result = await Process.run(
    'flutter',
    [
      'build',
      'apk',
      '--release',
      '--split-per-abi',
    ],
  );

  if (result.exitCode == 0) {
    print('  📁 APK build output: build/app/outputs/flutter-apk/');
    return true;
  } else {
    print('  ❌ APK build failed:');
    print(result.stderr);
    return false;
  }
}

Future<bool> buildWindows() async {
  if (!Platform.isWindows) {
    print('  ⚠️  Windows builds can only be created on Windows');
    return false;
  }

  print('  🪟 Building for Windows...');

  final result = await Process.run(
    'flutter',
    [
      'build',
      'windows',
      '--release',
    ],
  );

  if (result.exitCode == 0) {
    print('  📁 Windows build output: build/windows/runner/Release/');
    return true;
  } else {
    print('  ❌ Windows build failed:');
    print(result.stderr);
    return false;
  }
}

Future<void> generateBuildInfo(Map<String, bool> buildResults) async {
  final buildInfo = {
    'timestamp': DateTime.now().toIso8601String(),
    'platforms': buildResults,
    'flutter_version': await getFlutterVersion(),
    'dart_version': Platform.version,
    'build_machine': {
      'os': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
    },
  };

  final buildInfoFile = File('build/build_info.json');
  await buildInfoFile.parent.create(recursive: true);
  await buildInfoFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(buildInfo),
  );

  print('📄 Build info saved to: ${buildInfoFile.path}');
}

Future<String> getFlutterVersion() async {
  try {
    final result = await Process.run('flutter', ['--version']);
    final lines = result.stdout.toString().split('\n');
    return lines.first.trim();
  } catch (e) {
    return 'Unknown';
  }
}
