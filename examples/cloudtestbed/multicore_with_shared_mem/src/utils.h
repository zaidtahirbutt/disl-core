#ifndef UTILS_H
#define UTILS_H


extern int debug asm ("DEBUG");
extern int timer asm ("TIMER");
const char digits[16] = {'0','1','2','3','4','5','6','7','8','9', 'A', 'B', 'C', 'D', 'E', 'F'};

void delay_tcks(unsigned int delay){
    uint32_t rs1 = delay;
    uint32_t rs2 = delay;
    uint32_t rd;
    __asm__ (".insn r 0x2B , 0x2, 0, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (rd) : [rs1] "r" (rs1), [rs2] "r" (rs2));
    return;
}

void *
_sbrk (incr)
     int incr;
{
   extern char   end; /* Set by linker.  */
   static char * heap_end;
   char *        prev_heap_end;

   if (heap_end == 0)
     heap_end = & end;

   prev_heap_end = heap_end;
   heap_end += incr;

   return (void *) prev_heap_end;
}

void sleep(int microseconds){
    int start = timer;
    while ((timer-start) < microseconds){
        delay_tcks(100);
    }
    return;
}

void delay(int ms){
    int start = timer;
    int microseconds = ms*1000;
    while ((timer-start) < microseconds){
        delay_tcks(100);
    }
    return;
}
    
void prints (char* str){
    int i = 0;
    while ((int)str[i] != 0){
        debug = str[i];
        i = i+1;
    }
    return;
}

void printi(int val){
    if (val == 0){
        debug = '0';
        return;
    }

    if (val < 0){
        debug = '-';
        val = val*-1;
    }
    int num [10];
    for (int i=0;i<10;i=i+1){
        num[i] = val - 10*(val/10); val = val/10;
    }
    int start = 0;

    for (int i=10;i>0;i=i-1){
        if (start)
            debug = digits[num[i-1]];
        else if (num[i-1] > 0){
            debug = digits[num[i-1]];
            start = 1;
        }
        else 
            debug = 0;
        
    }
    return;
}

void done(){
    prints("!q!\n\r");
    return;
}


//https://stackoverflow.com/questions/46631410/how-to-write-custom-printf
void printf(char *c, ...)
{
    char *s;
    va_list lst;
    va_start(lst, c);
    while(*c != '\0')
    {
        if(*c != '%')
        {
            debug = *c;
            c++;
            continue;
        }

        c++;

        if(*c == '\0')
        {
            break;
        }

        switch(*c)
        {
            case 's': prints(va_arg(lst, char *)); break;
            case 'd': printi(va_arg(lst, int)); break;
        }
        c++;
    }
}

void putchar(int c){
    debug = c;
}

void puts(char* c){
    prints(c);
}
#endif

unsigned int get_hart_id() {
    unsigned int id;
    asm ("csrr %0, 0xf14" : "=r"(id) : : ); 
    return id;
}

void spinlock_init(unsigned int* shared_mem_pointer, unsigned int num_harts){
    shared_mem_pointer[num_harts-1] = 1;
}

void spinlock_poll(unsigned int* shared_mem_pointer){
    unsigned int id = get_hart_id();
    while (shared_mem_pointer[id] == 0){
        delay_tcks(100);
    }
}

void spinlock_release(unsigned int* shared_mem_pointer, unsigned int num_harts){
    unsigned int id = get_hart_id();
    shared_mem_pointer[id] = 0;
    if (id == 0){
        shared_mem_pointer[num_harts-1] = 1;
    } else {
        shared_mem_pointer[id-1] = 1;
    }
}