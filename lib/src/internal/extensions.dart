import 'dart:ffi';
import 'dart:math';

extension RandomHelpers on Random {
  int nextByte() => nextInt(0x100);

  void fill(Pointer<Uint8> pointer, int size) {
    for (--size; size >= 0; --size) {
      pointer[size] = nextByte();
    }
  }
}
