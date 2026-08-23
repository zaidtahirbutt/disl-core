/*---------------
 Include Section
 ----------------*/
#include "utils.h"
#include <stdlib.h>
#include <stdint.h>

/*--------------------
 Preprocessor Section
 ---------------------*/
/* Memory mapped config structures */
#define MMAP_CSR              0x10000000

#define RX_BUF_SIZE 1024
#define TX_BUF_SIZE 1024
#define TX_BUF2_SIZE 80

#define NUM_QUEUES 2
#define QUEUE_SIZE 32

#define UDP_CSUM_BASE 0x349d4
#define UDP_CSUM_BASE2 0x34a18 // For the second packet without data


// CSR structure
typedef struct {
  uint32_t irq_req;
  uint32_t start;
  uint32_t done;
  uint32_t rx_buffer_addr;
  uint32_t tx_buffer_addr;
} mmap_csr_t;

typedef struct {
  uint32_t status;
  uint32_t cmd;
  uint32_t rx_buffer_addr;
  uint32_t tx_buffer_addr;
  uint32_t tx_buffer_size;
} kvs_csr_t;

/*----------------------- Print error message ----------------------------------
------------------------------------------------------------------------------*/
void print_error(int error_num){
  while(1){printf("Error Number: %d\n", error_num);}
}


/*--------------------------- main function ----------------------------------
 ----------------------------------------------------------------------------*/
int main( )
{

  int i = 0;
  int j = 0;
  int k = 0;
  int l = 0;
  unsigned short avail_idx1, avail_int_idx1;
  unsigned short avail_idx0;
  unsigned short used_idx0, used_int_idx0;
  unsigned short desc_tab_idx1;
  unsigned long desc_addr1;
  unsigned short desc_flags1;
  unsigned int tx_len1;
  unsigned int addrx;

  volatile int *p;

  volatile kvs_csr_t *kvs_csr;
  volatile mmap_csr_t *mmap_csr;

  volatile char *rx_buffer;
  char *tx_buffer;
  char *tx_buffer2;
  volatile int *poll_addr0;
  volatile int *poll_addr1;

  int request_counter;

  uint16_t udp_len;

  uint32_t udp_csum_sum;
  uint16_t udp_csum;
  uint16_t udp_csum_add_val;

  kvs_csr = (kvs_csr_t*) KVS_CFG;
  mmap_csr = (mmap_csr_t*) MMAP_CSR;

  // Allocate buffers
  tx_buffer = (char*) malloc(TX_BUF_SIZE*sizeof(char));
  if(tx_buffer == NULL) print_error(1);
  addrx = (int)tx_buffer & 0x00000003;
  if(addrx != 0) print_error(2);  // TX buffer is not 4 Byte aligned.

  uint32_t* tx_buffer_32 = (uint32_t*) tx_buffer;
  uint16_t* tx_buffer_16 = (uint16_t*) tx_buffer;

  // Write TX buffer address to KVS CSR
  kvs_csr->tx_buffer_addr = tx_buffer;
  mmap_csr->tx_buffer_addr = tx_buffer;

  // Zero out the TX buffer
  for(i=0; i<(TX_BUF_SIZE>>2); i++){
    tx_buffer_32[i<<2] = 0x00000000;
  }


  rx_buffer = (char*) malloc(RX_BUF_SIZE*sizeof(char));
  if(rx_buffer == NULL) print_error(3);
  addrx = (int)rx_buffer & 0x00000003;
  if(addrx != 0) print_error(4);  // RX buffer address is not 4 Byte aligned.

  uint32_t* rx_buffer_32 = (uint32_t*) rx_buffer;
  uint16_t* rx_buffer_16 = (uint16_t*) rx_buffer;

  mmap_csr->rx_buffer_addr = rx_buffer;

  request_counter = 0;

  // Infinite loop
  while(1){
    if(mmap_csr->start & 0x00000001){
      request_counter++;

      do{ // Check if the KVS engine is busy
        k = kvs_csr->status & 0x00000001;
      } while(k == 1);

      kvs_csr->rx_buffer_addr = rx_buffer;
      kvs_csr->cmd = 1;

      // Wait for the KVS engine to finish
      do{ // Check of the KVS engine is busy
        k = kvs_csr->status & 0x00000001;
      } while(k == 1);

      if(kvs_csr->status == 0x6){ // KVS engine has successfully handled the request
        mmap_csr->tx_buffer_addr = tx_buffer;
        mmap_csr->tx_buffer_len  = kvs_csr->tx_buffer_size;
        mmap_csr->done = 0x1;
        mmap_csr->irq_req = 0x1;
      } else { // KVS engine has encountered an error
          print_error(5);
      }

    }
  } //while(1)
  
  return (0);
}

