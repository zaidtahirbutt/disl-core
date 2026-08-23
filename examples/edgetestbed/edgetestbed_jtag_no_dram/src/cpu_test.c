#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#define BME280_STANDBY_TIME_500_MS                (0x04)
#define BME280_CONCAT_BYTES(msb, lsb)             (((uint16_t)msb << 8) | (uint16_t)lsb)
#define BME280_12_BIT_SHIFT                       12
#define BME280_8_BIT_SHIFT                        8
#define BME280_4_BIT_SHIFT                        4
#define BME280_ADDRESS (0x76 << 1)

extern int debug asm ("DEBUG");
extern int timer asm ("TIMER");
extern int i2cbus asm ("I2CBUS");
const char digits[16] = {'0','1','2','3','4','5','6','7','8','9', 'A', 'B', 'C', 'D', 'E', 'F'};

void sleep(int microseconds);
void prints (char* str);
void printi(int val);
void printf(char *c, ...);
void putchar(int c);
void puts(char* c);
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



int main( )
{
  uint8_t data = 0;
  int count = 0;

  uint8_t digT1msb, digT1lsb, digT2msb, digT2lsb, digT3msb, digT3lsb;
  uint16_t digT1;
  int16_t digT2, digT3;

  uint8_t temp[3]; 
  uint32_t uncomp_temp_reading;
  int32_t comp_temp_reading;
  int32_t var1; 
  int32_t var2;
  int32_t temp_comp;

  int32_t tmin = -4000;
  int32_t tmax = 8500;
  int32_t t_fine = 0;

  uint32_t dataXLSB, dataLSB, dataMSB; 
  uint8_t ctrlSettings = 0x00;

  i2cbus = (0 << 16) | (0x88 << 8) | BME280_ADDRESS | 1;
  digT1lsb = i2cbus & 0xFF;
  i2cbus = (0 << 16) | (0x89 << 8) | BME280_ADDRESS | 1; 
  digT1msb = i2cbus & 0xFF;
  digT1 = (int16_t)BME280_CONCAT_BYTES(digT1msb, digT1lsb); 
  
  i2cbus = (0 << 16) | (0x8A << 8) | BME280_ADDRESS | 1;
  digT2lsb = i2cbus & 0xFF;
  i2cbus = (0 << 16) | (0x8B << 8) | BME280_ADDRESS | 1; 
  digT2msb = i2cbus & 0xFF;
  digT2 = (int16_t)BME280_CONCAT_BYTES(digT2msb, digT2lsb); 

  i2cbus = (0 << 16) | (0x8C << 8) | BME280_ADDRESS | 1;
  digT3lsb = i2cbus & 0xFF;
  i2cbus = (0 << 16) | (0x8D << 8) | BME280_ADDRESS | 1; 
  digT3msb = i2cbus & 0xFF;
  digT3 = (int16_t)BME280_CONCAT_BYTES(digT3msb, digT3lsb); 

  i2cbus = (0 << 16) | (0xD0 << 8) | BME280_ADDRESS | 1;
  data = i2cbus & 0xFF;
 
  if(data != 0x60)
  {
	 printf("Error, ID %d not equal to BME280 0x60!\r\n", data); 
  }
  i2cbus = (0 << 16) | (0xF4 << 8) | BME280_ADDRESS | 1;
  ctrlSettings = i2cbus & 0xFF;
  ctrlSettings |= 0x23;
  i2cbus = (ctrlSettings << 16) | (0xF4 << 8) | BME280_ADDRESS | 0;
  i2cbus = (0x60 << 16) | (0xF5 << 8) | BME280_ADDRESS | 0;

  while (1)
  {
    i2cbus = (0 << 16) | (0xFA << 8) | BME280_ADDRESS | 1;
    temp[0] = i2cbus & 0xFF; 
    dataMSB = (uint32_t)temp[0] << BME280_12_BIT_SHIFT;
  
    i2cbus = (0 << 16) | (0xFB << 8) | BME280_ADDRESS | 1;
    temp[1] = i2cbus & 0xFF;
    dataLSB = (uint32_t)temp[1] << BME280_4_BIT_SHIFT;
  
    i2cbus = (0 << 16) | (0xFC << 8) | BME280_ADDRESS | 1;
    temp[2] = i2cbus & 0xFF;
    dataXLSB = (uint32_t)temp[2] >> BME280_4_BIT_SHIFT;
  
    uncomp_temp_reading = dataMSB | dataLSB | dataXLSB;
    comp_temp_reading = 0;
  
    var1 = (int32_t)((uncomp_temp_reading / 8) - (digT1 * 2));
    var1 = (var1 * ((int32_t)digT2)) / 2048;
  
    var2 = (int32_t)((uncomp_temp_reading / 16) - ((int32_t)digT1));
    var2 = (((var2 * var2) / 4096) * ((int32_t)digT3)) / 16384;
  
    t_fine = var1 + var2;
    comp_temp_reading = (t_fine * 5 + 128) / 256;
 
    if (comp_temp_reading < tmin)
    {
        comp_temp_reading = tmin;
    }
    else if (comp_temp_reading > tmax)
    {
        comp_temp_reading = tmax;
    }

    printf("Temperature: %d.%dC\n\r",(int)comp_temp_reading/100,comp_temp_reading - ((int)(comp_temp_reading/100)*100 ));
    int start = timer;
    while (timer-start < 500000);
  }
}


//////////////////////////////////////////////////////// end test code ///////////////////////


void sleep(int microseconds){
    int start = timer;
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
