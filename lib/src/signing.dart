export 'signing_base.dart' show CryptoSignKeyPair;

export 'signing_ffi.dart'
    if (dart.library.js_interop) 'signing_web.dart';
