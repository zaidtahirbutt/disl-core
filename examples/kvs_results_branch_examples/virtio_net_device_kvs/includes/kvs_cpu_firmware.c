/*---------------
 Include Section
 ----------------*/
#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include "utils.h"

/*--------------------
 Preprocessor Section
 ---------------------*/
/* Memory mapped config structures */
#define PCI_CFG0              0x10000000
#define PCI_CFG1              0x20000000
#define KVS_CFG               0x70000000

#define DESC_TAB_SIZE 4
#define RX_BUF_SIZE 1024
#define TX_BUF_SIZE 128

#define NUM_QUEUES 2
#define QUEUE_SIZE 32

#define MAX_PAYLOAD 16

// CSR structure for the individual PCIe queues
typedef struct {
  uint32_t PCIE_STATUS;
  uint32_t PCIE_CMD;
  uint32_t PCIE_CMD_W1S;
  uint32_t PCIE_CMD_W1C;
  uint32_t MM_RX_BUFFER_ADDR;
  uint32_t MM_RX_BUFFER_SIZE;
  uint32_t MM_RX_DESC_TABLE_ADDR;
  uint32_t MM_RX_DESC_TABLE_SIZE;
  uint32_t MM_TX_SRC_ADDR;
  uint32_t MM_TX_DST_ADDR;
  uint32_t MM_TX_SIZE;
  uint32_t MM_POLL_ADDR;
  uint32_t MM_POLL_WR_VAL;
  uint32_t MM_TX_REMAINING_BYTES;
  uint32_t TIMERS_VALID;
  uint32_t ACTIVATE_TIMERS;
  uint32_t VIRTQ_SIZE;
  uint32_t VIRTQ_DESC;
  uint32_t VIRTQ_DRIVER;
  uint32_t VIRTQ_DEVICE;
  uint32_t VIRTQ_NOTIFY_REG;
  uint32_t VIRTQ_NOTIFY_ADDR;
  uint32_t VIRTQ_NOTIFY_VECTOR;
  uint32_t TIMER_TRX_START;
  uint32_t TIMER_TRX_END;
  uint32_t TIMER_BUF_CLEAN_START;
  uint32_t TIMER_BUF_CLEAN_END;
  uint32_t NUM_BUFFERS;
} pcie_csr_t;

// Define available and used ring structures
typedef struct {
  unsigned short flags; 
	unsigned short idx; 
	unsigned short ring[QUEUE_SIZE];
} virtq_avail_t;

typedef struct {
  /* Index of start of used descriptor chain. */ 
	unsigned int id; 
	/* Total length of the descriptor chain which was used (written to) */ 
	unsigned int len;
} virtq_used_elem;

typedef struct {
  unsigned short flags; 
	unsigned short idx; 
	virtq_used_elem ring[QUEUE_SIZE]; 
} virtq_used_t;

typedef struct {
  unsigned int addr;
  unsigned int padding;
  unsigned int  len;
  unsigned short flags;
  unsigned short next;
} virtq_desc_t;

typedef struct {
  uint32_t status;
  uint32_t cmd;
  uint32_t rx_buffer_addr;
  uint32_t tx_buffer_addr;
  uint32_t tx_buffer_size;
} kvs_csr_t;

// memcached headers
typedef struct {
  uint8_t Magic;
  uint8_t Opcode;
  uint16_t KeyLength;
  uint8_t ExtrasLength;
  uint8_t DataType;
  uint16_t vbucketID;
  uint32_t BodyLength;
  uint32_t Opaque;
  uint64_t CAS;
} MemCD_HDR_t;

typedef struct {
  MemCD_HDR_t header;
  uint32_t key; // Fixed key size for this implementation.
} __attribute__((packed)) MemCD_Get_Req_t;


typedef struct {
  MemCD_HDR_t header;
  uint32_t extras_flags;
  uint32_t extras_expiration;
  uint32_t key; // Fixed key size for this implementation.
  uint8_t  value[MAX_PAYLOAD];
} __attribute__((packed)) MemCD_Set_Req_t;

typedef struct {
  uint8_t Magic;
  uint8_t Opcode;
  uint16_t KeyLength;
  uint8_t ExtrasLength;
  uint8_t DataType;
  uint16_t Status;
  uint32_t BodyLength;
  uint32_t Opaque;
  uint64_t CAS;
  uint8_t Data[MAX_PAYLOAD];
} MemCD_Resp_t;

/*----------------------- Print error message ----------------------------------
------------------------------------------------------------------------------*/
void print_error(int error_num){
  while(1){printf("Error Number: %d\r\n", error_num);}
}


/*--------------------------- main function ----------------------------------
 ----------------------------------------------------------------------------*/
int main( )
{
  int i = 0;
  int j = 0;
  int k = 0;
  unsigned short avail_idx1, avail_int_idx1;
  unsigned short avail_idx0;
  unsigned short used_idx0, used_int_idx0;
  unsigned short desc_tab_idx1;
  unsigned long desc_addr1;
  unsigned short desc_flags1;
  unsigned int tx_len1;
  unsigned int addrx;

  volatile pcie_csr_t *q0_csr;
  volatile pcie_csr_t *q1_csr;

  volatile kvs_csr_t *kvs_csr;

  volatile char *rx_buffer;
  char *tx_buffer;
  volatile int *poll_addr0;
  volatile int *poll_addr1;

  uint32_t* rx_buffer_32;
  uint16_t* rx_buffer_16;
  uint8_t*  rx_buffer_8;

  q0_csr = (pcie_csr_t*) PCI_CFG0;
  q1_csr = (pcie_csr_t*) PCI_CFG1;

  kvs_csr = (kvs_csr_t*) KVS_CFG;

  //Set up queue controllers
  // Queue 0 (TX) (c2h)
  do{
  j = q0_csr->PCIE_STATUS;
  k = j & 0x80000000;
  } while(k != 0x80000000);

  poll_addr0 = (int*) malloc(1*sizeof(int));
  if(poll_addr0 == NULL) print_error(0);
  tx_buffer = (char*) malloc(TX_BUF_SIZE*sizeof(char));
  if(tx_buffer == NULL) print_error(1);
  addrx = (int)tx_buffer & 0x00000003;
  if(addrx != 0) print_error(2);  // TX buffer is not 4 Byte aligned.

  // Write TX buffer address to KVS CSR
  kvs_csr->tx_buffer_addr = tx_buffer;

  uint32_t* tx_buffer_32 = (uint32_t*) tx_buffer;
  uint16_t* tx_buffer_16 = (uint16_t*) tx_buffer;

  // Zero out the TX buffer
  for(i=0; i<(TX_BUF_SIZE>>2); i++){
    tx_buffer_32[i] = 0x00000000;
  }

  virtq_avail_t *avail_ring0 = (virtq_avail_t*) malloc(sizeof(virtq_avail_t));
  if(avail_ring0 == NULL) print_error(3);

  virtq_desc_t *desc_table0  = (virtq_desc_t*) malloc(sizeof(virtq_desc_t)*QUEUE_SIZE);
  if(desc_table0 == NULL) print_error(4);

  volatile virtq_used_t volatile *used_ring0 = (virtq_used_t*) malloc(sizeof(virtq_used_t));
  if(used_ring0 == NULL) print_error(5);


  *poll_addr0 = 0;

  q0_csr->VIRTQ_NOTIFY_ADDR = poll_addr0;
  q0_csr->VIRTQ_NOTIFY_VECTOR = 0x1;
  q0_csr->VIRTQ_SIZE = QUEUE_SIZE;
  q0_csr->VIRTQ_DESC = desc_table0;
  q0_csr->VIRTQ_DRIVER = avail_ring0;
  q0_csr->VIRTQ_DEVICE = used_ring0;
  q0_csr->PCIE_CMD_W1S = 0x80000024; // virtIO and polling modes selected

  avail_ring0->flags = 0;
  avail_ring0->idx   = 0;


  // Queue 1 RX (h2c)
  do{
  j = q1_csr->PCIE_STATUS;
  k = j & 0x80000000;
  } while(k != 0x80000000);


  poll_addr1 = (int*) malloc(1*sizeof(int));
  if(poll_addr1 == NULL) print_error(6);

  rx_buffer = (char*) malloc(RX_BUF_SIZE*sizeof(char));
  if(rx_buffer == NULL) print_error(7);
  addrx = (int)rx_buffer & 0x00000003;
  if(addrx != 0) print_error(8);  // RX buffer address is not 4 Byte aligned.

  volatile virtq_avail_t volatile *avail_ring1 = (virtq_avail_t*) malloc(sizeof(virtq_avail_t));
  if(avail_ring1 == NULL) print_error(9);

  volatile virtq_desc_t volatile *desc_table1  = (virtq_desc_t*) malloc(sizeof(virtq_desc_t)*QUEUE_SIZE);
  if(desc_table1 == NULL) print_error(10);

  virtq_used_t *used_ring1 = (virtq_used_t*) malloc(sizeof(virtq_used_t));
  if(used_ring1 == NULL) print_error(11);


  *poll_addr1 = 0;

  q1_csr->VIRTQ_NOTIFY_ADDR = poll_addr1;
  q1_csr->VIRTQ_NOTIFY_VECTOR = 0x1;
  q1_csr->VIRTQ_SIZE = QUEUE_SIZE;
  q1_csr->VIRTQ_DESC = desc_table1;
  q1_csr->VIRTQ_DRIVER = avail_ring1;
  q1_csr->VIRTQ_DEVICE = used_ring1;
  q1_csr->MM_RX_BUFFER_ADDR = rx_buffer;
  q1_csr->MM_RX_BUFFER_SIZE = RX_BUF_SIZE;
  q1_csr->PCIE_CMD_W1S = 0x80000024; // virtIO and polling modes selected

  used_ring1->idx = 0;
  used_ring1->flags = 0;

  avail_idx1     = 0;
  avail_int_idx1 = 0;
  avail_idx0     = 0;
  used_idx0      = 0;
  used_int_idx0  = 0;


  // Infinite loop
  while(1){
    // poll for an interrupt from the pcie controller and handle the interrupt
    if(*poll_addr1 == 1){ //h2c
      *poll_addr1 = 0;
      avail_idx1 = avail_ring1->idx;

      while(avail_int_idx1 != avail_idx1){ // Buffers exposed
        desc_tab_idx1 = avail_ring1->ring[avail_int_idx1 % QUEUE_SIZE];

        do{ // Check of the KVS engine is busy
          k = kvs_csr->status & 0x00000001;
        } while(k == 1);

        kvs_csr->rx_buffer_addr = desc_table1[desc_tab_idx1].addr;
        int table_addr;
        table_addr = (int) desc_table1[desc_tab_idx1].addr;
        kvs_csr->cmd = 1;

        // Wait for the KVS engine to finish
        do{ // Check of the KVS engine is busy
          k = kvs_csr->status & 0x00000001;
        } while(k == 1);

        if(kvs_csr->status == 0x6){ // KVS engine has successfully handled the request
          desc_table0[avail_int_idx1 % QUEUE_SIZE].addr    = tx_buffer;
          desc_table0[avail_int_idx1 % QUEUE_SIZE].padding = 0;
          desc_table0[avail_int_idx1 % QUEUE_SIZE].len     = kvs_csr->tx_buffer_size;
          desc_table0[avail_int_idx1 % QUEUE_SIZE].flags   = 0;
          desc_table0[avail_int_idx1 % QUEUE_SIZE].next    = 0;
          avail_ring0->ring[avail_int_idx1 % QUEUE_SIZE] = avail_int_idx1 % QUEUE_SIZE;
          used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].id = desc_tab_idx1;
          used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].len = desc_table1[desc_tab_idx1].len;
          avail_int_idx1++;
          used_ring1->idx = avail_int_idx1;
          avail_ring0->idx = avail_int_idx1;
        }
        else{ // KVS engine has encountered an error
          used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].id = desc_tab_idx1;
          used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].len = desc_table1[desc_tab_idx1].len;
          avail_int_idx1++;
          used_ring1->idx = avail_int_idx1;
          print_error(12);
        }
      
      } // Buffers exposed

      // Notify the controller for TX request
      q0_csr->VIRTQ_NOTIFY_REG = 1;

      do{
      j = q0_csr->PCIE_STATUS;
      k = j & 0x20000000;
      } while(k == 0x20000000);
    } //h2c notification
    else if(*poll_addr0 == 1){ // c2h
      *poll_addr0 = 0;
    }

  } //while


  return 0;
}
