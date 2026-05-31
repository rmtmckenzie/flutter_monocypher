#include "monocypher/monocypher.c"

#ifndef __wasm__
// Mock declarations for IDE static analyzer / code completion when running in native host mode
#define __builtin_wasm_memory_size(x) ((unsigned int)0)
#define __builtin_wasm_memory_grow(x, y) ((unsigned int)-1)
#endif

typedef struct Block {
    unsigned int size;
    int free;
    struct Block* next;
} Block;

#define BLOCK_SIZE sizeof(Block)

extern unsigned char __heap_base;
Block* freeList = 0;
unsigned int heap_top = 0;

void* wasm_malloc(unsigned int size) {
    if (heap_top == 0) {
        heap_top = (unsigned int)&__heap_base;
    }
    
    // Align size to 8 bytes for memory safety and alignment
    size = (size + 7) & ~7;
    
    // First fit search in existing blocks
    Block* curr = freeList;
    while (curr) {
        if (curr->free && curr->size >= size) {
            curr->free = 0;
            return (void*)(curr + 1);
        }
        curr = curr->next;
    }
    
    // Allocate a new block at heap_top
    unsigned int needed = BLOCK_SIZE + size;
    unsigned int current_memory_size = __builtin_wasm_memory_size(0) * 65536;
    if (heap_top + needed > current_memory_size) {
        unsigned int needed_bytes = heap_top + needed - current_memory_size;
        unsigned int needed_pages = (needed_bytes + 65535) / 65536;
        if (__builtin_wasm_memory_grow(0, needed_pages) == -1) {
            return 0; // Out of memory
        }
    }
    
    Block* block = (Block*)heap_top;
    block->size = size;
    block->free = 0;
    block->next = freeList;
    freeList = block;
    
    heap_top += needed;
    return (void*)(block + 1);
}

void wasm_free(void* ptr) {
    if (!ptr) return;
    Block* block = (Block*)ptr - 1;
    block->free = 1;
}
