import 'dart:math';
import 'dart:typed_data';

abstract class CryptoPointer {
  Uint8List asTypedList(int length);
  void free();
}

abstract class CryptoAllocator {
  CryptoPointer allocate(int byteCount);
}

abstract class MonocypherBindings {
  void crypto_eddsa_key_pair(
    CryptoPointer secretKey,
    CryptoPointer publicKey,
    CryptoPointer seed,
  );

  void crypto_eddsa_sign(
    CryptoPointer signature,
    CryptoPointer secretKey,
    CryptoPointer message,
    int messageLength,
  );

  int crypto_eddsa_check(
    CryptoPointer signature,
    CryptoPointer publicKey,
    CryptoPointer message,
    int messageLength,
  );
}

class CryptoSignKeyPair {
  CryptoSignKeyPair({
    required this.publicKey,
    required this.secretKey,
  })  : assert(publicKey.lengthInBytes == 32),
        assert(secretKey.lengthInBytes == 64);

  final Uint8List publicKey;
  final Uint8List secretKey;
}

class MonocypherSigning {
  MonocypherSigning({
    required this.allocator,
    required this.bindings,
  });

  final CryptoAllocator allocator;
  final MonocypherBindings bindings;

  CryptoSignKeyPair cryptoGenerateSignPair(Random random) {
    final publicKeyPointer = allocator.allocate(32);
    final secretKeyPointer = allocator.allocate(64);
    final seedPointer = allocator.allocate(32);

    try {
      final seed = seedPointer.asTypedList(32);
      for (var i = 0; i < 32; i++) {
        seed[i] = random.nextInt(256);
      }

      bindings.crypto_eddsa_key_pair(secretKeyPointer, publicKeyPointer, seedPointer);

      final publicKey = Uint8List.fromList(publicKeyPointer.asTypedList(32));
      final secretKey = Uint8List.fromList(secretKeyPointer.asTypedList(64));

      // Wipe secret key and seed in memory for security before freeing
      secretKeyPointer.asTypedList(64).fillRange(0, 64, 0);
      seedPointer.asTypedList(32).fillRange(0, 32, 0);

      return CryptoSignKeyPair(publicKey: publicKey, secretKey: secretKey);
    } finally {
      publicKeyPointer.free();
      secretKeyPointer.free();
      seedPointer.free();
    }
  }

  List<int> cryptoSign(List<int> message, List<int> secretKey) {
    assert(secretKey.length == 64);
    final signaturePointer = allocator.allocate(64);
    final messagePointer = allocator.allocate(message.length);
    final secretKeyPointer = allocator.allocate(64);

    try {
      secretKeyPointer.asTypedList(64).setAll(0, secretKey);
      messagePointer.asTypedList(message.length).setAll(0, message);

      bindings.crypto_eddsa_sign(signaturePointer, secretKeyPointer, messagePointer, message.length);

      final signature = Uint8List.fromList(signaturePointer.asTypedList(64));

      // Wipe secret key in memory before freeing
      secretKeyPointer.asTypedList(64).fillRange(0, 64, 0);

      return signature;
    } finally {
      signaturePointer.free();
      messagePointer.free();
      secretKeyPointer.free();
    }
  }

  bool cryptoSignVerify(List<int> signature, List<int> publicKey, List<int> message) {
    assert(signature.length == 64);
    assert(publicKey.length == 32);

    final signaturePointer = allocator.allocate(64);
    final publicKeyPointer = allocator.allocate(32);
    final messagePointer = allocator.allocate(message.length);

    try {
      signaturePointer.asTypedList(64).setAll(0, signature);
      publicKeyPointer.asTypedList(32).setAll(0, publicKey);
      messagePointer.asTypedList(message.length).setAll(0, message);

      final result = bindings.crypto_eddsa_check(signaturePointer, publicKeyPointer, messagePointer, message.length);

      return result == 0;
    } finally {
      signaturePointer.free();
      publicKeyPointer.free();
      messagePointer.free();
    }
  }
}
