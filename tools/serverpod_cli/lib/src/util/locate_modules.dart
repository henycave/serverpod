import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:serverpod_cli/src/config/config.dart';
import 'package:serverpod_cli/src/util/serverpod_cli_logger.dart';
import 'package:serverpod_shared/serverpod_shared.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

const _serverSuffix = '_server';

Future<List<ModuleConfig>?> locateModules({
  required Directory directory,
  List<String> excludePackages = const [],
  Map<String, String?> manualModules = const {},
}) async {
  var modules = <ModuleConfig>[];

  var packageConfig = await findPackageConfig(directory);
  if (packageConfig != null) {
    for (var packageInfo in packageConfig.packages) {
      try {
        var packageName = packageInfo.name;
        if (excludePackages.contains(packageName)) {
          continue;
        }

        if (!packageName.endsWith(_serverSuffix) &&
            packageName != 'serverpod') {
          continue;
        }
        var moduleName = await moduleNameFromServerPackageName(packageName);

        var packageSrcRoot = packageInfo.packageUriRoot;
        var moduleProjectRoot = List<String>.from(packageSrcRoot.pathSegments)
          ..removeLast()
          ..removeLast();
        var generatorConfigSegments = path
            .joinAll([...moduleProjectRoot, 'config', 'generator.yaml']).split(
                path.separator);

        var generatorConfigUri = packageSrcRoot.replace(
          pathSegments: generatorConfigSegments,
        );

        var generatorConfigFile = File.fromUri(generatorConfigUri);
        if (!await generatorConfigFile.exists()) {
          continue;
        }

        var moduleProjectUri = packageSrcRoot.replace(
          pathSegments: moduleProjectRoot,
        );

        var migrationVersions = findAllMigrationVersionsSync(
          directory: Directory.fromUri(moduleProjectUri),
          moduleName: moduleName,
        );

        var moduleInfo = loadConfigFile(generatorConfigFile);

        var manualNickname = manualModules[moduleName];
        var nickname = manualNickname ?? moduleInfo['nickname'] ?? moduleName;

        modules.add(
          ModuleConfig(
            type: GeneratorConfig.getPackageType(moduleInfo),
            name: moduleName,
            nickname: nickname,
            migrationVersions: migrationVersions,
            serverPackageDirectoryPathParts: moduleProjectRoot,
          ),
        );
      } catch (e) {
        continue;
      }
    }

    return modules;
  } else {
    log.error(
      'Failed to read your server\'s package configuration. Have you run '
      '`dart pub get` in your server directory?',
    );
    return null;
  }
}

Map<dynamic, dynamic> loadConfigFile(File file) {
  var yaml = file.readAsStringSync();
  return loadYaml(yaml) as Map;
}

List<String> findAllMigrationVersionsSync({
  required Directory directory,
  required String moduleName,
}) {
  try {
    var migrationRoot = MigrationConstants.migrationsBaseDirectory(directory);

    var migrationsDir = migrationRoot.listSync().whereType<Directory>();

    var migrationVersions =
        migrationsDir.map((dir) => path.split(dir.path).last).toList();

    migrationVersions.sort();
    return migrationVersions;
  } catch (e) {
    return [];
  }
}

Future<List<Uri>> locateAllModulePaths({
  required Directory directory,
}) async {
  var packageConfig = await findPackageConfig(directory);
  if (packageConfig == null) {
    throw Exception('Failed to read package configuration.');
  }

  var paths = <Uri>[];
  for (var packageInfo in packageConfig.packages) {
    try {
      var packageName = packageInfo.name;
      if (!packageName.endsWith(_serverSuffix) && packageName != 'serverpod') {
        continue;
      }

      var packageSrcRoot = packageInfo.packageUriRoot;

      // Check for generator file
      var generatorConfigSegments =
          List<String>.from(packageSrcRoot.pathSegments)
            ..removeLast()
            ..removeLast()
            ..addAll(['config', 'generator.yaml']);
      var generatorConfigUri = packageSrcRoot.replace(
        pathSegments: generatorConfigSegments,
      );

      var generatorConfigFile = File.fromUri(generatorConfigUri);
      if (!await generatorConfigFile.exists()) {
        continue;
      }

      // Get the root of the package
      var packageRootSegments = List<String>.from(packageSrcRoot.pathSegments)
        ..removeLast()
        ..removeLast();
      var packageRoot = packageSrcRoot.replace(
        pathSegments: packageRootSegments,
      );
      paths.add(packageRoot);
    } catch (e) {
      log.debug(e.toString());
      continue;
    }
  }
  return paths;
}

Future<String> moduleNameFromServerPackageName(String packageDirName,
    [List<String> pathSegments = const []]) async {
  var packageName = packageDirName.split('-').first;

  if (packageName == 'serverpod') {
    return 'serverpod';
  }

  if (!packageName.endsWith(_serverSuffix)) {
    log.warning(
        "Hint: Found a server package that doesn't end with a suffix of $_serverSuffix: $packageName\n Please make sure that all server packages end with $_serverSuffix.");
    if (pathSegments.isNotEmpty && await isServerPackage(pathSegments)) {
      log.info(
          'Assuming package is a server package based on config/generator.yaml');
      return packageName;
    }
    throw Exception('Not a server package ($packageName)');
  }
  return packageName.substring(0, packageName.length - _serverSuffix.length);
}

Future<bool> isServerPackage(List<String> pathSegments) async {
  //Check whether the package is a server package based on the generator.yaml file
  //here we are verifying the type of the package
  //if the type is server then we can assume that the package is a server package
  var generateConfigSegments = List<String>.from(pathSegments)
    ..addAll(['config', 'generator.yaml']);
  var filePath = path.joinAll(generateConfigSegments);
  // Ensure the filePath is absolute; if not, adjust accordingly:
  if (!path.isAbsolute(filePath)) {
    filePath = '/$filePath';
  }
  var generatorConfigUri = Uri.file(filePath);
  log.info('Reading generator config from: $generatorConfigUri');
  var generatorConfigFile = File.fromUri(generatorConfigUri);
  if (!await generatorConfigFile.exists()) {
    log.info('config/generator.yaml file not found');
    return false;
  }

  var config = loadYaml(await generatorConfigFile.readAsString()) as Map;
  return config['type'] == 'server';
}
