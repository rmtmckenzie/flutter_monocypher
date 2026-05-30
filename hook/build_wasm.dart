import 'dart:io';

// Since this is not supported as of yet, we're going to hack it
// in here. This can be run from the command line with
//
// > dart hook/build_wasm.dart
//
// This must be done before building for web.
void main(List<String> args) async {
  // Compile WebAssembly module for Web if clang is available
  try {
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }

    print('Building WebAssembly monocypher.wasm...');
    final result = await Process.run('clang', [
      '--target=wasm32',
      '-O3',
      '-nostdlib',
      '-Wl,--no-entry',
      '-Wl,--export-all',
      '-o',
      'assets/monocypher.wasm',
      'src/monocypher_wasm.c',
    ]);

    if (result.exitCode != 0) {
      print('WASM compilation failed: ${result.stderr}');
    } else {
      print('Successfully compiled WebAssembly to assets/monocypher.wasm');
    }
  } catch (e) {
    print('Could not compile WebAssembly asset: $e');
  }
}
