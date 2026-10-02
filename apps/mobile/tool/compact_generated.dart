import 'dart:io';

void main() {
  final generated = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => _isGenerated(file.path));
  for (final file in generated) {
    file.writeAsStringSync(_compact(file.readAsLinesSync()));
  }
}

String _compact(List<String> lines) {
  final output = StringBuffer();
  final code = StringBuffer();
  output.writeln('// ignore_for_file: type=lint, unused_element');

  void flushCode() {
    if (code.isEmpty) return;
    output.writeln(code.toString().trim());
    code.clear();
  }

  for (final line in lines) {
    var trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('//')) continue;
    final inlineComment = trimmed.indexOf('// ignore');
    if (inlineComment >= 0) {
      trimmed = trimmed.substring(0, inlineComment).trimRight();
    }
    if (trimmed.isEmpty) continue;
    code.write('$trimmed ');
  }
  flushCode();
  return output.toString();
}

bool _isGenerated(String path) =>
    path.endsWith('.freezed.dart') || path.endsWith('.g.dart');
