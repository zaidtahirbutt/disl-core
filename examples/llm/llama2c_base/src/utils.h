#ifndef UTILS_H
#define UTILS_H

extern int debug asm ("DEBUG");
extern int timer asm ("TIMER");
extern int spibus asm ("SPIBUS");
extern int crossover asm ("CROSSOVER");
extern int crossoverstatus asm ("CROSSOVERSTATUS");
const char digits[16] = {'0','1','2','3','4','5','6','7','8','9', 'A', 'B', 'C', 'D', 'E', 'F'};


#define SPI_READ (0<<7)
#define SPI_WRITE (1<<7)

#define SPI_SLOW 0
#define SPI_FAST (1<<16)
uint32_t spi_speed = SPI_SLOW;

void spibus_write(uint8_t addr){      
  spibus = addr | spi_speed;
}

uint8_t spibus_read(uint8_t addr){
  spibus = addr  | spi_speed;
  return(spibus & 0xFF);
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



#define CMD0        0
#define CMD0_ARG    0x00000000
#define CMD0_CRC    0x94
#define CMD8        8
#define CMD8_ARG    0x0000001AA
#define CMD8_CRC    0x86 //(1000011 << 1)
#define CMD0                0
#define CMD0_ARG            0x00000000
#define CMD0_CRC            0x94
#define CMD8                8
#define CMD8_ARG            0x0000001AA
#define CMD8_CRC            0x86
#define CMD9                9
#define CMD9_ARG            0x00000000
#define CMD9_CRC            0x00
#define CMD10               9
#define CMD10_ARG           0x00000000
#define CMD10_CRC           0x00
#define CMD13               13
#define CMD13_ARG           0x00000000
#define CMD13_CRC           0x00
#define CMD17               17
#define CMD17_CRC           0x00
#define CMD24               24
#define CMD24_CRC           0x00
#define CMD55               55
#define CMD55_ARG           0x00000000
#define CMD55_CRC           0x00
#define CMD58               58
#define CMD58_ARG           0x00000000
#define CMD58_CRC           0x00
#define ACMD41              41
#define ACMD41_ARG          0x40000000
#define ACMD41_CRC          0x00
#define PARAM_ERROR(X)      X & 0b01000000
#define ADDR_ERROR(X)       X & 0b00100000
#define ERASE_SEQ_ERROR(X)  X & 0b00010000
#define CRC_ERROR(X)        X & 0b00001000
#define ILLEGAL_CMD(X)      X & 0b00000100
#define ERASE_RESET(X)      X & 0b00000010
#define IN_IDLE(X)          X & 0b00000001
#define CMD_VER(X)          ((X >> 4) & 0xF0)
#define VOL_ACC(X)          (X & 0x1F)
#define VOLTAGE_ACC_27_33   0b00000001
#define VOLTAGE_ACC_LOW     0b00000010
#define VOLTAGE_ACC_RES1    0b00000100
#define VOLTAGE_ACC_RES2    0b00001000
#define POWER_UP_STATUS(X)  X & 0x40
#define CCS_VAL(X)          X & 0x40
#define VDD_2728(X)         X & 0b10000000
#define VDD_2829(X)         X & 0b00000001
#define VDD_2930(X)         X & 0b00000010
#define VDD_3031(X)         X & 0b00000100
#define VDD_3132(X)         X & 0b00001000
#define VDD_3233(X)         X & 0b00010000
#define VDD_3334(X)         X & 0b00100000
#define VDD_3435(X)         X & 0b01000000
#define VDD_3536(X)         X & 0b10000000
#define SD_MAX_READ_ATTEMPTS    1563
#define SD_TOKEN_OOR(X)     X & 0b00001000
#define SD_TOKEN_CECC(X)    X & 0b00000100
#define SD_TOKEN_CC(X)      X & 0b00000010
#define SD_TOKEN_ERROR(X)   X & 0b00000001
#define SD_SUCCESS  0
#define SD_ERROR    1
#define SD_READY 0
#define CMD24                   24
#define CMD24_ARG               0x00
#define SD_MAX_WRITE_ATTEMPTS   3907
#define SD_INIT_CYCLES          80
#define SD_START_TOKEN          0xFE
#define SD_ERROR_TOKEN          0x00
#define SD_DATA_ACCEPTED        0x05
#define SD_DATA_REJECTED_CRC    0x0B
#define SD_DATA_REJECTED_WRITE  0x0D
#define SD_BLOCK_LEN            512

void SD_command(uint8_t cmd, uint32_t arg, uint8_t crc)
{
    uint32_t byte5 = 0x40 | (cmd&0x3F);  
    uint32_t byte4 = (arg >> 24)& 0xFF; 
    uint32_t byte3 = (arg >> 16)& 0xFF; 
    uint32_t byte2 = (arg >> 8) & 0xFF; 
    uint32_t byte1 = (arg >> 0) & 0xFF;  
    uint32_t byte0 = crc|0x01; 
    spibus_write(byte5);
    spibus_write(byte4);
    spibus_write(byte3);
    spibus_write(byte2);
    spibus_write(byte1);
    spibus_write(byte0);
}

// int check = 1;
// uint32_t spi_transfer_hold = 0;
// uint32_t SPI_transfer(uint8_t addr){
//   if (check){
//     spibus = 0xFF00 | addr ;
//     spi_transfer_hold = spibus;
//     check = 0; 
//     return ((spi_transfer_hold >> 8)&0xFF);
//   }
//   check = 1;
//   return spi_transfer_hold&0xFF;
// }


uint32_t SPI_transfer(uint8_t byte1){
  return spibus_read(byte1);
}


void _delay_ms(uint32_t val){
    delay(val);
}

uint8_t SD_readRes1()
{
    uint8_t i = 0, res1;
    // keep polling until actual data received
    while((res1 = SPI_transfer(0xFF)) == 0xFF)
    {
        i++;
        // if no data received for 8 bytes, break
        if(i > 8) break;
    }
    return res1;
}

uint8_t SD_goIdleState()
{
    SPI_transfer(0xFF);
    // send CMD0
    SD_command(CMD0, CMD0_ARG, CMD0_CRC);
    // read response
    uint8_t res1 = SD_readRes1();
    // deassert chip select
    SPI_transfer(0xFF);
    return res1;
}



void UART_puts(char* msg){
    printf("%s", msg);
}

void UART_puthex8(uint32_t msg){
    printf("%d",msg);
}
void SD_readRes7(uint8_t *res)
{
    // read response 1 in R7
    res[0] = SD_readRes1();
    // if error reading R1, return
    if(res[0] > 1) return;
    // read remaining bytes
    res[1] = SPI_transfer(0xFF);
    res[2] = SPI_transfer(0xFF);
    res[3] = SPI_transfer(0xFF);
    res[4] = SPI_transfer(0xFF);
}

void SD_sendIfCond(uint8_t *res)
{
    SPI_transfer(0xFF);
    // send CMD8
    SD_command(CMD8, CMD8_ARG, CMD8_CRC);
    //SPI_transfer(0xFF);
    // read response
    SD_readRes7(res);
}

void SD_printR1(uint8_t res)
{
    if(res & 0b10000000)
        { UART_puts("\tError: MSB = 1\r\n"); return; }
    if(res == 0)
        { UART_puts("\tCard Ready\r\n"); return; }
    if(PARAM_ERROR(res))
        UART_puts("\tParameter Error\r\n");
    if(ADDR_ERROR(res))
        UART_puts("\tAddress Error\r\n");
    if(ERASE_SEQ_ERROR(res))
        UART_puts("\tErase Sequence Error\r\n");
    if(CRC_ERROR(res))
        UART_puts("\tCRC Error\r\n");
    if(ILLEGAL_CMD(res))
        UART_puts("\tIllegal Command\r\n");
    if(ERASE_RESET(res))
        UART_puts("\tErase Reset Error\r\n");
    if(IN_IDLE(res))
        UART_puts("\tIn Idle State\r\n");
}

void SD_printR7(uint8_t *res)
{
    SD_printR1(res[0]);

    if(res[0] > 1) return;

    UART_puts("\tCommand Version: ");
    UART_puthex8(CMD_VER(res[1]));
    UART_puts("\r\n");

    UART_puts("\tVoltage Accepted: ");
    if(VOL_ACC(res[3]) == VOLTAGE_ACC_27_33)
        UART_puts("2.7-3.6V\r\n");
    else if(VOL_ACC(res[3]) == VOLTAGE_ACC_LOW)
        UART_puts("LOW VOLTAGE\r\n");
    else if(VOL_ACC(res[3]) == VOLTAGE_ACC_RES1)
        UART_puts("RESERVED\r\n");
    else if(VOL_ACC(res[3]) == VOLTAGE_ACC_RES2)
        UART_puts("RESERVED\r\n");
    else
        UART_puts("NOT DEFINED\r\n");

    UART_puts("\tEcho: ");
    UART_puthex8(res[4]);
    UART_puts("\r\n");
}

void SD_readRes3_7(uint8_t *res)
{
    // read R1
    res[0] = SD_readRes1();

    // if error reading R1, return
    if(res[0] > 1) return;

    // read remaining bytes
    res[1] = SPI_transfer(0xFF);
    res[2] = SPI_transfer(0xFF);
    res[3] = SPI_transfer(0xFF);
    res[4] = SPI_transfer(0xFF);
}

void SD_readOCR(uint8_t *res)
{
    // assert chip select
    SPI_transfer(0xFF);
    // send CMD58
    SD_command(CMD58, CMD58_ARG, CMD58_CRC);
    // read response
    SD_readRes3_7(res);
    SPI_transfer(0xFF);
}

void SD_printR3(uint8_t *res)
{
    SD_printR1(res[0]);

    if(res[0] > 1) return;

    UART_puts("\tCard Power Up Status: ");
    if(POWER_UP_STATUS(res[1]))
    {
        UART_puts("READY\r\n");
        UART_puts("\tCCS Status: ");
        if(CCS_VAL(res[1])){ UART_puts("1\r\n"); }
        else UART_puts("0\r\n");
    }
    else
    {
        UART_puts("BUSY\r\n");
    }

    UART_puts("\tVDD Window: ");
    if(VDD_2728(res[3])) UART_puts("2.7-2.8, ");
    if(VDD_2829(res[2])) UART_puts("2.8-2.9, ");
    if(VDD_2930(res[2])) UART_puts("2.9-3.0, ");
    if(VDD_3031(res[2])) UART_puts("3.0-3.1, ");
    if(VDD_3132(res[2])) UART_puts("3.1-3.2, ");
    if(VDD_3233(res[2])) UART_puts("3.2-3.3, ");
    if(VDD_3334(res[2])) UART_puts("3.3-3.4, ");
    if(VDD_3435(res[2])) UART_puts("3.4-3.5, ");
    if(VDD_3536(res[2])) UART_puts("3.5-3.6");
    UART_puts("\r\n");
}

uint8_t SD_sendApp()
{
    SPI_transfer(0xFF);
    SD_command(CMD55, CMD55_ARG, CMD55_CRC);
    uint8_t res1 = SD_readRes1();
    SPI_transfer(0xFF);
    return res1;
}

uint8_t SD_sendOpCond()
{
    // assert chip select
    SPI_transfer(0xFF);
    SD_command(ACMD41, ACMD41_ARG, ACMD41_CRC);
    uint8_t res1 = SD_readRes1();
    SPI_transfer(0xFF);
    return res1;
}


/*******************************************************************************
 Read single 512 byte block
 token = 0xFE - Successful read
 token = 0x0X - Data error
 token = 0xFF - Timeout
*******************************************************************************/
uint8_t SD_readSingleBlock(uint32_t addr, uint8_t *buf, uint8_t *token)
{
    uint8_t res1, read;
    uint16_t readAttempts;
    // set token to none
    *token = 0xFF;
    // assert chip select
    SPI_transfer(0xFF);
    // send CMD17
    SD_command(CMD17, addr, CMD17_CRC);
    // read R1
    res1 = SD_readRes1();
    // if response received from card
    if(res1 != 0xFF)
    {
        // wait for a response token (timeout = 100ms)
        readAttempts = 0;
        while(++readAttempts != SD_MAX_READ_ATTEMPTS)
            if((read = SPI_transfer(0xFF)) != 0xFF) break;

        // if response token is 0xFE
        if(read == 0xFE)
        {
            // read 512 byte block
            for(uint16_t i = 0; i < 512; i++) *buf++ = SPI_transfer(0xFF);

            // read 16-bit CRC
            SPI_transfer(0xFF);
            SPI_transfer(0xFF);
        }

        // set token to card response
        *token = read;
    }
    SPI_transfer(0xFF);
    return res1;
}

void SD_printDataErrToken(uint8_t token)
{
    if(SD_TOKEN_OOR(token))
        UART_puts("\tData out of range\r\n");
    if(SD_TOKEN_CECC(token))
        UART_puts("\tCard ECC failed\r\n");
    if(SD_TOKEN_CC(token))
        UART_puts("\tCC Error\r\n");
    if(SD_TOKEN_ERROR(token))
        UART_puts("\tError\r\n");
}


uint8_t SD_init()
{
    uint8_t res[5], cmdAttempts = 0;
    while((res[0] = SD_goIdleState()) != 0x01)
    {
        cmdAttempts++;
        if(cmdAttempts > 10) return SD_ERROR;
    }
    // SD_printR1(res[0]);
    SD_sendIfCond(res);
    // SD_printR7(res);
    if(res[0] != 0x01)
    {
        return SD_ERROR;
    }
    if(res[4] != 0xAA)
    {
        return SD_ERROR;
    }
    cmdAttempts = 0;
    do
    {
        if(cmdAttempts > 100) return SD_ERROR;
        res[0] = SD_sendApp();
        // SD_printR1(res[0]);
        if(res[0] < 2)
        {
            res[0] = SD_sendOpCond();
            // SD_printR1(res[0]);
        }
        delay(10);
        cmdAttempts++;
    }
    while(res[0] != SD_READY);
    SD_readOCR(res);
    if(!(res[1] & 0x80)) return SD_ERROR;
    return SD_SUCCESS;
}


/*******************************************************************************
 Write single 512 byte block
 token = 0x00 - busy timeout
 token = 0x05 - data accepted
 token = 0xFF - response timeout
*******************************************************************************/
uint8_t SD_writeSingleBlock(uint32_t addr, uint8_t *buf, uint8_t *token)
{
    uint8_t readAttempts, read, res[0];
    // set token to none
    *token = 0xFF;
    SPI_transfer(0xFF);

    // send CMD24
    SD_command(CMD24, addr, CMD24_CRC);

    // read response
    res[0] = SD_readRes1();

    // if no error
    if(res[0] == SD_READY)
    {
        // send start token
        SPI_transfer(SD_START_TOKEN);

        // write buffer to card
        for(uint16_t i = 0; i < SD_BLOCK_LEN; i++) SPI_transfer(buf[i]);

        // wait for a response (timeout = 250ms)
        readAttempts = 0;
        while(++readAttempts != SD_MAX_WRITE_ATTEMPTS)
            if((read = SPI_transfer(0xFF)) != 0xFF) { *token = 0xFF; break; }

        // if data accepted
        if((read & 0x1F) == 0x05)
        {
            // set token to data accepted
            *token = 0x05;

            // wait for write to finish (timeout = 250ms)
            readAttempts = 0;
            while(SPI_transfer(0xFF) == 0x00)
                if(++readAttempts == SD_MAX_WRITE_ATTEMPTS) { *token = 0x00; break; }
        }
    }
    SPI_transfer(0xFF);
    return res[0];
}


uint8_t sdread(uint32_t addr, uint8_t* buf){
    uint8_t token;
    SD_readSingleBlock(addr, buf, &token);
    if (token == SD_START_TOKEN)
        return 0;
    else
        return 1;
}


uint8_t sdwrite(uint32_t addr, uint8_t* buf){
    uint8_t token;
    SD_writeSingleBlock(addr, buf, &token); 
    if (token == 0x05)
        return 0;
    else
        return 1;
}

void sdprintblock(uint8_t* buf){
    for(uint16_t i = 0; i < SD_BLOCK_LEN; i++) printf("%h", buf[i]);
}


void loadfile(uint32_t base_addr){
    if (SD_init() != SD_SUCCESS){
        printf("Card not detected\n\r");
    }   
      uint8_t buf[SD_BLOCK_LEN];
      uint32_t sector_pointer = base_addr;
      while(1){
        for (int i = 0; i < SD_BLOCK_LEN; i++){
          buf[i] = debug & 0xFF;
        }
        sdwrite(sector_pointer,buf);
        printf("Y\r\n");
        sector_pointer++;
      }
}

int sscanf(const char *str, const char *format, ...) {
    va_list args;
    va_start(args, format);
    
    int count = 0; // Count of successfully parsed items
    char *p_str = (char *)str; // Pointer to the current position in the string
    
    // Iterate through the format string
    while (*format != '\0' && *p_str != '\0') {
        if (*format == '%') {
            format++;
            switch (*format) {
                case 'd': {
                    int *arg = va_arg(args, int *);
                    *arg = 0;
                    while (*p_str >= '0' && *p_str <= '9') {
                        *arg = (*arg * 10) + (*p_str - '0');
                        p_str++;
                    }
                    count++;
                    break;
                }
                case 's': {
                    char *arg = va_arg(args, char *);
                    while (*p_str != ' ' && *p_str != '\0') {
                        *arg = *p_str;
                        arg++;
                        p_str++;
                    }
                    *arg = '\0'; // Null-terminate the string
                    count++;
                    break;
                }
                default:
                    // Unsupported format specifier, ignore
                    break;
            }
        } else {
            // Non-format character, skip whitespace in both strings
            while (*format != '\0' && *format == *p_str) {
                format++;
                p_str++;
            }
        }
        format++;
    }

    va_end(args);
    return count;
}


// Helper function to convert an integer to string
int sprintf_int(char *buffer, int value) {
    int len = 0;
    if (value < 0) {
        *buffer++ = '-';
        value = -value;
        len++;
    }
    int temp = value;
    do {
        temp /= 10;
        len++;
    } while (temp != 0);
    buffer += len - 1;
    do {
        *buffer-- = '0' + (value % 10);
        value /= 10;
    } while (value != 0);
    return len;
}

int sprintf(char *buffer, const char *format, ...) {
    va_list args;
    va_start(args, format);

    int count = 0; // Count of characters written to buffer

    while (*format != '\0') {
        if (*format == '%') {
            format++;
            switch (*format) {
                case 'd': {
                    int value = va_arg(args, int);
                    // Convert integer to string and append to buffer
                    int len = sprintf_int(buffer, value);
                    buffer += len;
                    count += len;
                    break;
                }
                case 's': {
                    char *str = va_arg(args, char *);
                    // Copy string to buffer
                    while (*str != '\0') {
                        *buffer++ = *str++;
                        count++;
                    }
                    break;
                }
                default:
                    // Unsupported format specifier, ignore
                    break;
            }
        } else {
            *buffer++ = *format;
            count++;
        }
        format++;
    }

    // Null-terminate the buffer
    *buffer = '\0';

    va_end(args);
    return count;
}
#endif
