#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include "utils.h"
#include "arducam_ov2640.h"

#define BME280_ADDRESS (0x76 << 1)

int main( )
{
  uint8_t data = 0;
  uint8_t counter = 0;
  int count = 0;
  int start = 0;


  data = i2cbus_read(BME280_ADDRESS, 0xD0);
  if(data != 0x60)
   printf("Error, ID %d not equal to BME280 0x60!\r\n", data); 
  else
        printf("Found BME280\r\n");
          
  //while(detect_arducam_ov2640()){
  //  delay(100);
  //}
  detect_arducam_ov2640();
  InitCAM(JPEG);
  set_JPEG_size(OV2640_160x120);
  delay(1000);
  clear_fifo_flag();
  write_reg(ARDUCHIP_FRAMES,0x00);
  
  set_Light_Mode(Auto);
  set_Color_Saturation(Saturation0);
  set_Brightness(Brightness0);
  set_Contrast(Contrast0);
  uint8_t effect = Normal;
  //while(1);
  while(1){
    set_Special_effects(effect);
    //effect++;
    if (effect == 13){effect = 0;}
    flush_fifo();
    clear_fifo_flag();
    printf("Status = %d\n\r", read_reg(ARDUCHIP_FIFO));
    delay(100);
    start_capture();
    printf("Begin capture\n\r");
    while (get_bit(ARDUCHIP_TRIG, CAP_DONE_MASK) == 0);
    printf("End capture\n\r");
    int len = read_fifo_length();
    //printf("Start\n\r");
    int ret;
    for (int i = 0; i < len; i++){
      uint8_t byte = read_fifo();
      //printf("%d", byte);
      //printf("\n\r", byte);
      crossover = byte;
    }
    clear_fifo_flag();
    //delay(10);
    printf("Done\n\r");
    //break;
  }
  /*while(1){
    crossover = counter;
    printf("Sent: %d\n\r", crossoverstatus);
    counter++;
    delay(1000);
  }*/
  while(1);
}



