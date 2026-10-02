import 'dart:io';

const checkedDirectories = ['lib', 'test', 'tool'];

Future<void> main() async {
  final files = <String>[];
  for (final directory in checkedDirectories) {
    final root = Directory(directory);
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_isGenerated(entity.path)) continue;
      files.add(entity.path);
    }
  }
  final result = await Process.run('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...files,
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}

bool _isGenerated(String path) =>
    path.endsWith('.freezed.dart') || path.endsWith('.g.dart');
