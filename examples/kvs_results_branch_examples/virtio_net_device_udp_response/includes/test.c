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
#define PCI_CFG0              0x10000000
#define PCI_CFG1              0x20000000

#define DESC_TAB_SIZE 4
#define RX_BUF_SIZE 1024
#define TX_BUF_SIZE 1024
#define TX_BUF2_SIZE 80

#define NUM_QUEUES 2
#define QUEUE_SIZE 32

#define UDP_CSUM_BASE 0x349d4
#define UDP_CSUM_BASE2 0x34a18 // For the second packet without data

// #define T1 0x11223344
// #define T2 0x12345678
// #define T3 0x89abcdef
// #define T4 0xaabbccdd

#define T1 q1_csr->TIMER_TRX_START
#define T2 q1_csr->TIMER_TRX_END
#define T3 q1_csr->TIMER_BUF_CLEAN_START
#define T4 q1_csr->TIMER_BUF_CLEAN_END
#define T5 q0_csr->TIMER_TRX_START
#define T6 q0_csr->TIMER_TRX_END

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
  int tab_index = 0;
  unsigned short avail_idx1, avail_int_idx1;
  unsigned short avail_idx0;
  unsigned short used_idx0, used_int_idx0;
  unsigned short desc_tab_idx1;
  unsigned long desc_addr1;
  unsigned short desc_flags1;
  unsigned int tx_len1;
  unsigned int addrx;

  volatile int *p;

  volatile pcie_csr_t *q0_csr;
  volatile pcie_csr_t *q1_csr;

  volatile char *rx_buffer;
  char *tx_buffer;
  char *tx_buffer2;
  volatile int *poll_addr0;
  volatile int *poll_addr1;

  int notify_counter0, notify_counter1;

  uint16_t udp_len;

  uint32_t udp_csum_sum;
  uint16_t udp_csum;
  uint16_t udp_csum_add_val;

  notify_counter0 = 0;
  notify_counter1 = 0;

  q0_csr = (pcie_csr_t*) PCI_CFG0;
  q1_csr = (pcie_csr_t*) PCI_CFG1;

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
  tx_buffer2 = (char*) malloc(TX_BUF2_SIZE*sizeof(char));
  if(tx_buffer2 == NULL) print_error(12);
  addrx = (int)tx_buffer & 0x00000003;
  if(addrx != 0) print_error(2);  // TX buffer is not 4 Byte aligned.
  addrx = (int)tx_buffer2 & 0x00000003;
  if(addrx != 0) print_error(13);  // TX buffer is not 4 Byte aligned.

  uint32_t* tx_buffer_32 = (uint32_t*) tx_buffer;
  uint16_t* tx_buffer_16 = (uint16_t*) tx_buffer;

  uint32_t* tx_buffer2_32 = (uint32_t*) tx_buffer2;
  uint16_t* tx_buffer2_16 = (uint16_t*) tx_buffer2;

  uint32_t* rx_buffer_32;
  uint16_t* rx_buffer_16;
  uint8_t*  rx_buffer_8;

  // Zero out the TX buffer
  for(i=0; i<(TX_BUF_SIZE>>2); i++){
    tx_buffer_32[i<<2] = 0x00000000;
  }

  for(i=0; i<(TX_BUF2_SIZE>>2); i++){
    tx_buffer2_32[i<<2] = 0x00000000;
  }

  // Write the fixed part of the TX packet to the TX buffer
  // Common packet content
  // Source MAC = 02:de:ad:be:ef:11
  // Dest. MAC  = 7e:39:ac:b5:89:c7
  // Source IP  = 192.168.0.2 (0x0200A8C0) // Bytes ordered assuming the transmit order of bytes where the LSB is sent first
  // Dest. IP   = 128.197.176.148 (0x94B0C580)
  // Protocol   = 17 (UDP)
  // UDP length = 20
  // Source port = 44000
  // Destination port = 44000

  tx_buffer_32[8>>2]  = 0x01000000; // Last word of virtio header
  tx_buffer_32[12>>2] = 0xb5ac397e; // dest. and src mac
  tx_buffer_32[16>>2] = 0xde02c789;
  tx_buffer_32[20>>2] = 0x11efbead;
  tx_buffer_32[24>>2] = 0x00450008; // Eth type and IP vesion and hdr length
  tx_buffer_32[32>>2] = 0x11400040; // flags, fragmented offset, TTL, protocol
  tx_buffer_32[36>>2] = 0xa8c00000; // dst. IP, IP header csum (Added later)
  tx_buffer_32[40>>2] = 0xc5800200; // src IP, dst. IP
  tx_buffer_32[44>>2] = 0xe0ab94b0; // dst. IP, UDP src. port
  tx_buffer_32[48>>2] = 0x0000e0ab; // UDP dst. port, UDP length (Needs to be updated later)

  // Write to TX buffer 2
  tx_buffer2_32[8>>2]  = 0x01000000; // Last word of virtio header
  tx_buffer2_32[12>>2] = 0xb5ac397e; // dest. and src mac
  tx_buffer2_32[16>>2] = 0xde02c789;
  tx_buffer2_32[20>>2] = 0x11efbead;
  tx_buffer2_32[24>>2] = 0x00450008; // Eth type and IP vesion and hdr length
  tx_buffer2_32[28>>2] = 0xd2043600; // identification (1234), total length (54)
  tx_buffer2_32[32>>2] = 0x11400040; // flags, fragmented offset, TTL, protocol
  tx_buffer2_32[36>>2] = 0xa8c0E143; // dst. IP, IP header csum
  tx_buffer2_32[40>>2] = 0xc5800200; // src IP, dst. IP
  tx_buffer2_32[44>>2] = 0xe0ab94b0; // dst. IP, UDP src. port
  tx_buffer2_32[48>>2] = 0x2200e0ab; // UDP dst. port, UDP length
  tx_buffer2_32[52>>2] = 0x00000000; // UDP checksum, buffer of two bytes
  tx_buffer2_32[56>>2] = 0x00000000; // First value
  tx_buffer2_32[60>>2] = 0x00000000; // Second value
  tx_buffer2_32[64>>2] = 0x00000000; // Third value
  tx_buffer2_32[68>>2] = 0x00000000; // Fourth value
  tx_buffer2_32[72>>2] = 0x00000000; // Fifth value
  tx_buffer2_32[76>>2] = 0x00000000; // Sixth value


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
      notify_counter1++;
      *poll_addr1 = 0;
    
      avail_idx1 = avail_ring1->idx;

      while(avail_int_idx1 != avail_idx1){ // Buffers exposed
        desc_tab_idx1 = avail_ring1->ring[avail_int_idx1 % QUEUE_SIZE];

        int table_addr;
        table_addr = (int) desc_table1[desc_tab_idx1].addr;

        rx_buffer_32 = (uint32_t*) table_addr;
        rx_buffer_16 = (uint16_t*) table_addr;
        rx_buffer_8  = (uint8_t*) table_addr;
        
        // Write TX packet
        tx_buffer_32[28>>2] = rx_buffer_32[28>>2]; // total length and identification (Same as the RX packet)
        // IP header checksum is also copied from the RX packet
        tx_buffer_16[36>>1] = rx_buffer_16[36>>1];
        // UDP length copied from RX buffer;
        tx_buffer_16[(48>>1) + 1] = rx_buffer_16[(48>>1) + 1];

        udp_len = rx_buffer_8[50];
        udp_len = udp_len << 8;
        udp_len = udp_len | rx_buffer_8[51];

        udp_csum_sum = UDP_CSUM_BASE + (udp_len << 1); // Length is added twice in CSUM calculation

        while((udp_csum_sum>>16)){
          udp_csum_sum = (udp_csum_sum>>16) + (udp_csum_sum & 0x0000ffff);
        }
        
        udp_csum = udp_csum_sum & 0x0000ffff;
        udp_csum = ~udp_csum;

        // Write UDP checksum to TX packet
        tx_buffer[52] = udp_csum>>8;
        tx_buffer[53] = udp_csum & 0x00ff;

        // Update descriptor table and available ring
        desc_table0[avail_idx0 % QUEUE_SIZE].addr    = tx_buffer;
        desc_table0[avail_idx0 % QUEUE_SIZE].padding = 0;
        desc_table0[avail_idx0 % QUEUE_SIZE].len     = udp_len + 46;
        desc_table0[avail_idx0 % QUEUE_SIZE].flags   = 0;
        desc_table0[avail_idx0 % QUEUE_SIZE].next    = 0;
        avail_ring0->ring[avail_idx0 % QUEUE_SIZE] = avail_idx0 % QUEUE_SIZE;
        used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].id = desc_tab_idx1;
        used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].len = desc_table1[desc_tab_idx1].len;
        avail_int_idx1++;
        used_ring1->idx = avail_int_idx1;
        avail_idx0++;
        avail_ring0->idx = avail_idx0;

      } // Buffers exposed

      // Notify the controller for TX request
      q0_csr->VIRTQ_NOTIFY_REG = 1;

      do{
      j = q0_csr->PCIE_STATUS;
      k = j & 0x20000000;
      } while(k == 0x20000000);

      if(*poll_addr0 != 0){
        *poll_addr0 = 0;
      }

      // Update fields of packet2
      udp_csum_sum = UDP_CSUM_BASE2;

      tx_buffer2_32[56>>2] = T1;
      udp_csum_add_val = (T1 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T1 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T1 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T1 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      tx_buffer2_32[60>>2] = T2;
      udp_csum_add_val = (T2 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T2 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T2 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T2 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      tx_buffer2_32[64>>2] = T3;
      udp_csum_add_val = (T3 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T3 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T3 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T3 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      tx_buffer2_32[68>>2] = T4;
      udp_csum_add_val = (T4 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T4 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T4 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T4 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      tx_buffer2_32[72>>2] = T5;
      udp_csum_add_val = (T5 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T5 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T5 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T5 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      tx_buffer2_32[76>>2] = T6;
      udp_csum_add_val = (T6 & 0x000000ff) << 8;
      udp_csum_add_val = udp_csum_add_val | ((T6 & 0x0000ff00) >> 8);
      udp_csum_sum += udp_csum_add_val;
      udp_csum_add_val = (T6 & 0x00ff0000) >> 8;
      udp_csum_add_val = udp_csum_add_val | ((T6 & 0xff000000) >> 24);
      udp_csum_sum += udp_csum_add_val;

      while((udp_csum_sum>>16)){
        udp_csum_sum = (udp_csum_sum>>16) + (udp_csum_sum & 0x0000ffff);
      }
      
      udp_csum = udp_csum_sum & 0x0000ffff;
      udp_csum = ~udp_csum;

      // Write UDP checksum to TX packet
      tx_buffer2[52] = udp_csum>>8;
      tx_buffer2[53] = udp_csum & 0x00ff;


      // Send second packet
      // Update descriptor table and available ring
      desc_table0[avail_idx0 % QUEUE_SIZE].addr    = tx_buffer2;
      desc_table0[avail_idx0 % QUEUE_SIZE].padding = 0;
      desc_table0[avail_idx0 % QUEUE_SIZE].len     = 80;
      desc_table0[avail_idx0 % QUEUE_SIZE].flags   = 0;
      desc_table0[avail_idx0 % QUEUE_SIZE].next    = 0;
      avail_ring0->ring[avail_idx0 % QUEUE_SIZE] = avail_idx0 % QUEUE_SIZE;
      avail_idx0++;
      avail_ring0->idx = avail_idx0;

      // Notify the controller for TX request 2
      q0_csr->VIRTQ_NOTIFY_REG = 1;

      do{
      j = q0_csr->PCIE_STATUS;
      k = j & 0x20000000;
      } while(k == 0x20000000);

      if(*poll_addr0 != 0){
        *poll_addr0 = 0;
      }
    }

    else if(*poll_addr0 == 1){ // c2h
      notify_counter0++;
      *poll_addr0 = 0;
    }
  }
  return (0);
}

