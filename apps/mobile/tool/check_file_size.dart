import 'dart:io';

const maxLines = 200;
const checkedDirectories = ['lib', 'test', 'tool'];

void main() {
  final violations = <String>[];
  for (final directory in checkedDirectories) {
    final root = Directory(directory);
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync().length;
      if (lines > maxLines) violations.add('${entity.path}: $lines lines');
    }
  }
  if (violations.isEmpty) {
    stdout.writeln('All Dart files are <= $maxLines lines.');
    return;
  }
  stderr.writeln('Dart file size limit exceeded:');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}
