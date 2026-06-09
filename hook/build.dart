import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';

// import 'dart:io';
// import 'package:data_assets/data_assets.dart';
// import 'build_wasm.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    final cBuilder = CBuilder.library(
      name: packageName,
      assetName: 'src/internal/bindings.generated.dart',
      sources: ['src/monocypher/monocypher.c'],
    );
    await cBuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = .ALL
        ..onRecord.listen((record) => print(record.message)),
    );

    // if (input.config.buildDataAssets) {
    //   final packageName = input.packageName;
      
    //   await buildWasm('build/out/monocypher.wasm')
      
    //   final assetPathInPackage = input.packageRoot.resolve('build/out/monocypher.wasm');
 
    //   output.assets.data.add(
    //     DataAsset(
    //       package: packageName,
    //       name: 'monocypher.wasm',
    //       file: assetPathInPackage,
    //     ),
    //   );
    // }
  });
}
