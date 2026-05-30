#include "monocypher/monocypher.c"

// 64KB static buffer for passing inputs and outputs between Dart and
// WebAssembly
unsigned char wasm_memory[65536];

unsigned char *get_wasm_memory() { return wasm_memory; }
