import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final generator = FfiGenerator(
    output: Output(dartFile: Uri.parse('lib/src/internal/bindings.generated.dart'), style: NativeExternalBindings(), commentType: CommentType(.any, .full)),
    headers: Headers(entryPoints: [Uri.parse('src/monocypher/monocypher.h')]),
    functions: Functions.includeAll,
    structs: Structs(include: (name) {
      return !name.originalName.startsWith("_");
    }),
    globals: Globals.includeAll,
    macros: Macros.includeSet({"CRYPTO_ARGON2_D", "CRYPTO_ARGON2_I", "CRYPTO_ARGON2_ID"}),
  );

  try {
    generator.generate();
  } catch (e) {
    stderr.writeln('FFIGen generation failed: $e');
    exit(1);
  }
}
