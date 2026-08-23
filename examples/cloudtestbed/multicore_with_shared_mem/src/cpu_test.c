#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include "utils.h"

#define NUM_HARTS 4
#define SHARED_MEM_POINTER 1048576
#define USE_SPINLOCK 1

int main(){ 
  uint32_t counter = 0;
  if (USE_SPINLOCK)
    spinlock_init((uint32_t*) SHARED_MEM_POINTER, NUM_HARTS);
  int i;
  while (1) { 
    if (USE_SPINLOCK)
      spinlock_poll((uint32_t*)SHARED_MEM_POINTER);
    printf("%d: %d\n\r", get_hart_id(), counter++);
    if (USE_SPINLOCK)
      spinlock_release((uint32_t*)SHARED_MEM_POINTER, NUM_HARTS);
    delay(100);
  }
  while (1); 
}
    