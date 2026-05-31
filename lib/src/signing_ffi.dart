import 'dart:ffi' as ffi;
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'signing_base.dart';
import 'internal/bindings.generated.dart' as native_bindings;

class FfiCryptoPointer implements CryptoPointer {
  FfiCryptoPointer(this.pointer);

  final ffi.Pointer<ffi.Uint8> pointer;

  @override
  Uint8List asTypedList(int length) {
    return pointer.asTypedList(length);
  }

  @override
  void free() {
    malloc.free(pointer);
  }
}

class FfiCryptoAllocator implements CryptoAllocator {
  @override
  CryptoPointer allocate(int byteCount) {
    return FfiCryptoPointer(malloc.allocate<ffi.Uint8>(byteCount));
  }
}

class FfiMonocypherBindings implements MonocypherBindings {
  @override
  void crypto_eddsa_key_pair(
    CryptoPointer secretKey,
    CryptoPointer publicKey,
    CryptoPointer seed,
  ) {
    native_bindings.crypto_eddsa_key_pair(
      (secretKey as FfiCryptoPointer).pointer,
      (publicKey as FfiCryptoPointer).pointer,
      (seed as FfiCryptoPointer).pointer,
    );
  }

  @override
  void crypto_eddsa_sign(
    CryptoPointer signature,
    CryptoPointer secretKey,
    CryptoPointer message,
    int messageLength,
  ) {
    native_bindings.crypto_eddsa_sign(
      (signature as FfiCryptoPointer).pointer,
      (secretKey as FfiCryptoPointer).pointer,
      (message as FfiCryptoPointer).pointer,
      messageLength,
    );
  }

  @override
  int crypto_eddsa_check(
    CryptoPointer signature,
    CryptoPointer publicKey,
    CryptoPointer message,
    int messageLength,
  ) {
    return native_bindings.crypto_eddsa_check(
      (signature as FfiCryptoPointer).pointer,
      (publicKey as FfiCryptoPointer).pointer,
      (message as FfiCryptoPointer).pointer,
      messageLength,
    );
  }
}

final _signing = MonocypherSigning(
  allocator: FfiCryptoAllocator(),
  bindings: FfiMonocypherBindings(),
);

CryptoSignKeyPair cryptoGenerateSignPair(Random random) =>
    _signing.cryptoGenerateSignPair(random);

List<int> cryptoSign(List<int> message, List<int> secretKey) =>
    _signing.cryptoSign(message, secretKey);

bool cryptoSignVerify(
  List<int> signature,
  List<int> publicKey,
  List<int> message,
) =>
    _signing.cryptoSignVerify(signature, publicKey, message);

Future<void> initWeb() async {}