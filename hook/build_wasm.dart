import 'dart:io';
import 'package:logging/logging.dart';

Future<void> buildWasm(String path) async {
  final parentDir = File(path).parent;
  if (!await parentDir.exists()) {
    await parentDir.create(recursive: true);
  }

  final result = await Process.run('clang', [
    '--target=wasm32',
    '-O3',
    '-nostdlib',
    '-Wl,--no-entry',
    '-Wl,--export-all',
    '-o',
    path,
    'src/monocypher_wasm.c',
  ]);

  if (result.exitCode != 0) {
    throw('WASM compilation failed: ${result.stderr}');
  } else {
    Logger.root.log(.INFO,'Successfully compiled WebAssembly to $path');
  }
}


// Since linking non-code (as far as FFI is concerned) data
// is not supported as of yet, we're going to hack it
// in here. This can be run from the command line with
//
// > dart hook/build_wasm.dart
//
// This must be done before building for web.
void main(List<String> args) async {
  // Compile WebAssembly module for Web if clang is available
  try {
    print('Building WebAssembly monocypher.wasm...');
    await buildWasm('assets/monocypher.wasm');
  } catch (e) {
    print('Could not compile WebAssembly asset: $e');
  }
}

