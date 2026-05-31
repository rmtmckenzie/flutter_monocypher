import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';
import 'signing_base.dart';

@JS('fetch')
external JSPromise<JSObject> jsFetch(JSString url);

extension type FetchResponse._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('WebAssembly')
extension type WebAssembly._(JSObject _) implements JSObject {
  external static JSPromise<WebAssemblyResult> instantiate(
    JSUint8Array bytes,
    JSObject importObject,
  );
}

extension type WebAssemblyResult._(JSObject _) implements JSObject {
  external WebAssemblyInstance get instance;
}

extension type WebAssemblyInstance._(JSObject _) implements JSObject {
  external MonocypherExports get exports;
}

extension type MonocypherExports._(JSObject _) implements JSObject {
  external JSFunction get wasm_malloc;
  external JSFunction get wasm_free;
  external JSFunction get crypto_eddsa_key_pair;
  external JSFunction get crypto_eddsa_sign;
  external JSFunction get crypto_eddsa_check;
  external JSMemory get memory;
}

extension type JSMemory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

MonocypherExports? _exportsInstance;

MonocypherExports get _exports {
  if (_exportsInstance == null) {
    throw StateError(
      'Monocypher WebAssembly is not initialized. '
      'You must call "await initWeb()" in your main() function on the web '
      'before calling any Monocypher functions.'
    );
  }
  return _exportsInstance!;
}

Future<void> initWeb() async {
  if (_exportsInstance != null) return; // Already initialized

  final url = 'assets/packages/flutter_monocypher/assets/monocypher.wasm';
  try {
    final responseObj = await jsFetch(url.toJS).toDart;
    final response = FetchResponse._(responseObj);
    final arrayBuffer = await response.arrayBuffer().toDart;
    final jsBytes = JSUint8Array(arrayBuffer);

    final importObject = JSObject();
    final result = await WebAssembly.instantiate(jsBytes, importObject).toDart;
    _exportsInstance = result.instance.exports;
  } catch (e) {
    throw Exception(
      'Failed to load and initialize Monocypher WebAssembly from "$url". '
      'Make sure that "assets/monocypher.wasm" is declared under assets '
      'in your pubspec.yaml and serves correctly. '
      'Error: $e'
    );
  }
}

class WebCryptoPointer implements CryptoPointer {
  WebCryptoPointer(this.address, this.buffer, this.onFree);

  final int address;
  final Uint8List buffer;
  final void Function(int address) onFree;

  @override
  Uint8List asTypedList(int length) {
    return buffer.buffer.asUint8List(address, length);
  }


  @override
  void free() {
    onFree(address);
  }
}

class WebCryptoAllocator implements CryptoAllocator {
  WebCryptoAllocator(this.buffer, this.mallocFunc, this.freeFunc);

  final Uint8List buffer;
  final JSFunction mallocFunc;
  final JSFunction freeFunc;

  @override
  CryptoPointer allocate(int byteCount) {
    final ptr = (mallocFunc.callAsFunction(null, byteCount.toJS) as JSNumber).toDartInt;
    if (ptr == 0) throw OutOfMemoryError();
    return WebCryptoPointer(ptr, buffer, (address) {
      freeFunc.callAsFunction(null, address.toJS);
    });
  }
}

class WebMonocypherBindings implements MonocypherBindings {
  WebMonocypherBindings(this.exports);

  final MonocypherExports exports;

  @override
  void crypto_eddsa_key_pair(
    CryptoPointer secretKey,
    CryptoPointer publicKey,
    CryptoPointer seed,
  ) {
    exports.crypto_eddsa_key_pair.callAsFunction(
      null,
      (secretKey as WebCryptoPointer).address.toJS,
      (publicKey as WebCryptoPointer).address.toJS,
      (seed as WebCryptoPointer).address.toJS,
    );
  }

  @override
  void crypto_eddsa_sign(
    CryptoPointer signature,
    CryptoPointer secretKey,
    CryptoPointer message,
    int messageLength,
  ) {
    exports.crypto_eddsa_sign.callAsFunction(
      null,
      (signature as WebCryptoPointer).address.toJS,
      (secretKey as WebCryptoPointer).address.toJS,
      (message as WebCryptoPointer).address.toJS,
      messageLength.toJS,
    );
  }

  @override
  int crypto_eddsa_check(
    CryptoPointer signature,
    CryptoPointer publicKey,
    CryptoPointer message,
    int messageLength,
  ) {
    final result = exports.crypto_eddsa_check.callAsFunction(
      null,
      (signature as WebCryptoPointer).address.toJS,
      (publicKey as WebCryptoPointer).address.toJS,
      (message as WebCryptoPointer).address.toJS,
      messageLength.toJS,
    ) as JSNumber;
    return result.toDartInt;
  }
}

MonocypherSigning? _signingInstance;

MonocypherSigning get _signing {
  if (_signingInstance == null) {
    final exp = _exports;
    final buffer = exp.memory.buffer.toDart.asUint8List();
    _signingInstance = MonocypherSigning(
      allocator: WebCryptoAllocator(buffer, exp.wasm_malloc, exp.wasm_free),
      bindings: WebMonocypherBindings(exp),
    );
  }
  return _signingInstance!;
}

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
