import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'internal/extensions.dart';

import 'internal/bindings.generated.dart' as bindings;

class CryptoSignKeyPair {
  CryptoSignKeyPair({
    required this.publicKey,
    required this.secretKey,
  })  : assert(publicKey.lengthInBytes == 32),
        assert(secretKey.lengthInBytes == 64);

  final Uint8List publicKey;
  final Uint8List secretKey;
}

CryptoSignKeyPair cryptoGenerateSignPair(Random random) {

  final publicKeyPointer = malloc.allocate<Uint8>(32);
  final secretKeyPointer = malloc.allocate<Uint8>(64);
  final seed = malloc.allocate<Uint8>(32);

  try {
    random.fill(seed, 32);
    bindings.crypto_eddsa_key_pair(
      secretKeyPointer,
      publicKeyPointer,
      seed,
    );

    final keypair = CryptoSignKeyPair(
      publicKey: Uint8List.fromList(publicKeyPointer.asTypedList(32)),
      secretKey: Uint8List.fromList(secretKeyPointer.asTypedList(64)),
    );

    bindings.crypto_wipe(secretKeyPointer as Pointer<Void>, 64);
    return keypair;
  } finally {
    malloc.free(publicKeyPointer);
    malloc.free(secretKeyPointer);
  }
}

List<int> cryptoSign(List<int> message, List<int> secretKey) {
  assert(secretKey.length == 64);
  final signaturePointer = malloc.allocate<Uint8>(64);
  final messagePointer = malloc.allocate<Uint8>(message.length)..asTypedList(message.length).setAll(0, message);
  final secretKeyPointer = malloc.allocate<Uint8>(secretKey.length)..asTypedList(secretKey.length).setAll(0, secretKey);

  try {
    bindings.crypto_eddsa_sign(
      signaturePointer,
      secretKeyPointer,
      messagePointer,
      message.length,
    );
    bindings.crypto_wipe(secretKeyPointer.cast(), secretKey.length);
    return Uint8List.fromList(signaturePointer.asTypedList(64));
  } finally {
    malloc.free(signaturePointer);
    malloc.free(messagePointer);
    malloc.free(secretKeyPointer);
  }
}

bool cryptoSignVerify(List<int> signature, List<int> publicKey, List<int> message) {
  assert(signature.length == 64);
  assert(publicKey.length == 32);

  final signaturePointer = malloc.allocate<Uint8>(64)..asTypedList(64).setAll(0, signature);
  final publicKeyPointer = malloc.allocate<Uint8>(32)..asTypedList(32).setAll(0, publicKey);
  final messagePointer = malloc.allocate<Uint8>(message.length)..asTypedList(message.length).setAll(0, message);

  try {
    final result = bindings.crypto_eddsa_check(
      signaturePointer,
      publicKeyPointer,
      messagePointer,
      message.length,
    );
    return result == 0;
  } finally {
    malloc.free(signaturePointer);
    malloc.free(publicKeyPointer);
    malloc.free(messagePointer);
  }
}