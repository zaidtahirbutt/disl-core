#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include "utils.h"

int main(){
  while (1) {
    printf("%d\n\r", get_hart_id());
    delay(1000);
  }
  while (1);
}
