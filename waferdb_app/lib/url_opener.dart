import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _urlOpenerChannel = MethodChannel(
  'it.infn.virgo.waferdb/url_opener',
);

Future<bool> openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return false;
  }

  final normalizedUrl = uri.toString();

  if (Platform.isAndroid) {
    try {
      return await _urlOpenerChannel.invokeMethod<bool>('openUrl', {
            'url': normalizedUrl,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  if (Platform.isLinux) {
    return _runCommand('xdg-open', [normalizedUrl]);
  }
  if (Platform.isMacOS) {
    return _runCommand('open', [normalizedUrl]);
  }
  if (Platform.isWindows) {
    return _runCommand('cmd', [
      '/c',
      'start',
      '',
      normalizedUrl,
    ], runInShell: true);
  }

  return false;
}

Future<bool> _runCommand(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
}) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
      runInShell: runInShell,
    );
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
