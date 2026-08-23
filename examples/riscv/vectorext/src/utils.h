#ifndef UTILS_H
#define UTILS_H

extern int gpio asm ("GPIO");
extern int debug asm ("DEBUG");
extern int timer asm ("TIMER");
const char digits[16] = {'0','1','2','3','4','5','6','7','8','9', 'A', 'B', 'C', 'D', 'E', 'F'};



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
    while ((timer-start) < microseconds);
    return;
}

void delay(int ms){
    int start = timer;
    int microseconds = ms*1000;
    while ((timer-start) < microseconds);
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


void printh(int val){
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
        num[i] = val - 16*(val/16); val = val/16;
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

void printfloat(int val){
    if (val == 0){
        debug = '0';
        debug = '.';
        debug = '0';
        return;
    }

    unsigned int sign = (val >> 31)&1;
    int exponent = ((val >> 23)&0x0FF)-127;
    unsigned int mantissa = (val & 0x007FFFFF) | 0x00800000;
    unsigned int decimal_point = 23;
    if (sign){
        debug = '-';
    }

    unsigned int lhs = 0;
    unsigned int rhs = 0;

    if (exponent >= 23) {
        lhs = mantissa << (exponent - 23);
        rhs = 0;
    } else if (exponent >= 0) {
        lhs = mantissa >> (23 - exponent);
        rhs = (mantissa & ((1 << (23 - exponent)) - 1)) << exponent;
    } else {
        lhs = 0;
        rhs = mantissa >> (23 - exponent);
    }
    printi(lhs);
    debug = '.';
    printi(rhs);
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
            case 'h': printh(va_arg(lst, int)); break;
            case 'f': printfloat(va_arg(lst, int)); break;
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
