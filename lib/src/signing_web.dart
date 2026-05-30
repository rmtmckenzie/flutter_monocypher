import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

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
  external JSFunction get get_wasm_memory;
  external JSFunction get crypto_eddsa_key_pair;
  external JSFunction get crypto_eddsa_sign;
  external JSFunction get crypto_eddsa_check;
  external JSMemory get memory;
}

extension type JSMemory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
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

CryptoSignKeyPair cryptoGenerateSignPair(Random random) {
  final exp = _exports;
  final memoryOffset = (exp.get_wasm_memory.callAsFunction() as JSNumber).toDartInt;
  final buffer = exp.memory.buffer.toDart.asUint8List();

  // Offset mappings inside 64KB static buffer:
  // - 0 to 64: secret key (64 bytes)
  // - 64 to 96: public key (32 bytes)
  // - 96 to 128: seed (32 bytes)
  final secretKeyOffset = memoryOffset;
  final publicKeyOffset = memoryOffset + 64;
  final seedOffset = memoryOffset + 96;

  // Generate 32-byte seed from random
  final seed = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    seed[i] = random.nextInt(256);
  }
  buffer.setRange(seedOffset, seedOffset + 32, seed);

  exp.crypto_eddsa_key_pair.callAsFunction(
    null,
    secretKeyOffset.toJS,
    publicKeyOffset.toJS,
    seedOffset.toJS,
  );

  final publicKey = Uint8List.fromList(buffer.sublist(publicKeyOffset, publicKeyOffset + 32));
  final secretKey = Uint8List.fromList(buffer.sublist(secretKeyOffset, secretKeyOffset + 64));

  // Wipe the seed and secret key in static buffer for security
  buffer.fillRange(secretKeyOffset, secretKeyOffset + 64, 0);
  buffer.fillRange(seedOffset, seedOffset + 32, 0);

  return CryptoSignKeyPair(publicKey: publicKey, secretKey: secretKey);
}

List<int> cryptoSign(List<int> message, List<int> secretKey) {
  assert(secretKey.length == 64);
  final exp = _exports;
  final memoryOffset = (exp.get_wasm_memory.callAsFunction() as JSNumber).toDartInt;
  final buffer = exp.memory.buffer.toDart.asUint8List();

  // Offset mappings inside 64KB static buffer:
  // - 0 to 64: signature (64 bytes)
  // - 64 to 128: secret key (64 bytes)
  // - 128+: message (up to 65408 bytes)
  final signatureOffset = memoryOffset;
  final secretKeyOffset = memoryOffset + 64;
  final messageOffset = memoryOffset + 128;

  buffer.setRange(secretKeyOffset, secretKeyOffset + 64, secretKey);
  buffer.setRange(messageOffset, messageOffset + message.length, message);

  exp.crypto_eddsa_sign.callAsFunction(
    null,
    signatureOffset.toJS,
    secretKeyOffset.toJS,
    messageOffset.toJS,
    message.length.toJS,
  );

  final signature = Uint8List.fromList(buffer.sublist(signatureOffset, signatureOffset + 64));

  // Wipe secret key and signature area
  buffer.fillRange(signatureOffset, signatureOffset + 128, 0);

  return signature;
}

bool cryptoSignVerify(List<int> signature, List<int> publicKey, List<int> message) {
  assert(signature.length == 64);
  assert(publicKey.length == 32);

  final exp = _exports;
  final memoryOffset = (exp.get_wasm_memory.callAsFunction() as JSNumber).toDartInt;
  final buffer = exp.memory.buffer.toDart.asUint8List();

  // Offset mappings inside 64KB static buffer:
  // - 0 to 64: signature (64 bytes)
  // - 64 to 96: public key (32 bytes)
  // - 96+: message
  final signatureOffset = memoryOffset;
  final publicKeyOffset = memoryOffset + 64;
  final messageOffset = memoryOffset + 96;

  buffer.setRange(signatureOffset, signatureOffset + 64, signature);
  buffer.setRange(publicKeyOffset, publicKeyOffset + 32, publicKey);
  buffer.setRange(messageOffset, messageOffset + message.length, message);

  final result = exp.crypto_eddsa_check.callAsFunction(
    null,
    signatureOffset.toJS,
    publicKeyOffset.toJS,
    messageOffset.toJS,
    message.length.toJS,
  ) as JSNumber;

  // Clear memory
  buffer.fillRange(signatureOffset, signatureOffset + 96, 0);

  return result.toDartInt == 0;
}
