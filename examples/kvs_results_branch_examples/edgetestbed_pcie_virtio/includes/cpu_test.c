/*---------------
 Include Section
 ----------------*/
#include "utils.h"
#include <stdlib.h>

/*--------------------
 Preprocessor Section
 ---------------------*/
/* Memory mapped config structures */
#define PCI_CFG0              0x10000000
#define PCI_CFG1              0x20000000

#define VIRTQ_NOTIFY_VECTOR   0x58
#define VIRTQ_NOTIFY_ADDR     0x54
#define VIRTQ_NOTIFY_REG      0x50
#define VIRTQ_DEVICE          0x4C
#define VIRTQ_DRIVER          0x48
#define VIRTQ_DESC            0x44
#define VIRTQ_SIZE            0x40

#define MM_TX_REMAINING_BYTES 0x34
#define MM_POLL_WR_VAL        0x30
#define MM_POLL_ADDR          0x2C
#define MM_TX_SIZE            0x28
#define MM_TX_DST_ADDR        0x24
#define MM_TX_SRC_ADDR        0x20
#define MM_RX_DESC_TABLE_SIZE 0x1C
#define MM_RX_DESC_TABLE_ADDR 0x18
#define MM_RX_BUFFER_SIZE     0x14
#define MM_RX_BUFFER_ADDR     0x10
#define PCIE_CMD_W1C          0x0C
#define PCIE_CMD_W1S          0x08
#define PCIE_CMD              0x04
#define PCIE_STATUS           0x00

#define DESC_TAB_SIZE 4
#define RX_BUF_SIZE 512
#define TX_BUF_SIZE 512

#define NUM_QUEUES 2
#define QUEUE_SIZE 32

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
  unsigned short used_idx0, used_int_idx0;
  unsigned short desc_tab_idx1;
  unsigned long desc_addr1;
  unsigned short desc_flags1;
  unsigned int tx_len1;
  unsigned int addrx;

  int tx_buf_head = 0;
  int tx_buf_tail = 0;

  volatile int *p;
  volatile char *c;

  volatile char *rx_buffer;
  //volatile int *desc_table;
  char *tx_buffer;
  volatile int *poll_addr0;
  volatile int *poll_addr1;

  int notify_counter0, notify_counter1;

  notify_counter0 = 0;
  notify_counter1 = 0;


  //Set up queue controllers
  // Queue 0 (TX) (c2h)
  p = PCI_CFG0 + PCIE_STATUS;
  do{
  j = *p;
  k = j & 0x80000000;
  } while(k != 0x80000000);

  poll_addr0 = (int*) malloc(1*sizeof(int));
  if(poll_addr0 == NULL) goto alloc_error0;
  //tx_buffer = (char*) malloc(TX_BUF_SIZE*sizeof(char));

  virtq_avail_t *avail_ring0 = (virtq_avail_t*) malloc(sizeof(virtq_avail_t));
  if(avail_ring0 == NULL) goto alloc_error1;

  virtq_desc_t *desc_table0  = (virtq_desc_t*) malloc(sizeof(virtq_desc_t)*QUEUE_SIZE);
  if(desc_table0 == NULL) goto alloc_error2;

  volatile virtq_used_t volatile *used_ring0 = (virtq_used_t*) malloc(sizeof(virtq_used_t));
  if(used_ring0 == NULL) goto alloc_error3;


  *poll_addr0 = 0;

  p = PCI_CFG0 + VIRTQ_NOTIFY_ADDR;
  *p = poll_addr0;

  p = PCI_CFG0 + VIRTQ_NOTIFY_VECTOR;
  *p = 0x1;

  p = PCI_CFG0 + VIRTQ_SIZE;
  *p = QUEUE_SIZE;

  p = PCI_CFG0 + VIRTQ_DESC;
  *p = desc_table0;
  
  p = PCI_CFG0 + VIRTQ_DRIVER;
  *p = avail_ring0;

  p = PCI_CFG0 + VIRTQ_DEVICE;
  *p = used_ring0;

  //p = PCI_CFG0 + MM_TX_SRC_ADDR;
  //*p = tx_buffer;

  p = PCI_CFG0 + PCIE_CMD_W1S;
  *p = 0x80000024; // virtIO and polling modes selected

  avail_ring0->flags = 0;
  avail_ring0->idx   = 0;


  // Queue 1 RX (h2c)
  p = PCI_CFG1 + PCIE_STATUS;
  do{
  j = *p;
  k = j & 0x80000000;
  } while(k != 0x80000000);


  poll_addr1 = (int*) malloc(1*sizeof(int));
  if(poll_addr1 == NULL) goto alloc_error4;

  rx_buffer = (char*) malloc(RX_BUF_SIZE*sizeof(char));
  if(rx_buffer == NULL) goto alloc_error5;

  volatile virtq_avail_t volatile *avail_ring1 = (virtq_avail_t*) malloc(sizeof(virtq_avail_t));
  if(avail_ring1 == NULL) goto alloc_error6;

  volatile virtq_desc_t volatile *desc_table1  = (virtq_desc_t*) malloc(sizeof(virtq_desc_t)*QUEUE_SIZE);
  if(desc_table1 == NULL) goto alloc_error7;

  virtq_used_t *used_ring1 = (virtq_used_t*) malloc(sizeof(virtq_used_t));
  if(used_ring1 == NULL) goto alloc_error8;


  *poll_addr1 = 0;

  p = PCI_CFG1 + VIRTQ_NOTIFY_ADDR;
  *p = poll_addr1;

  p = PCI_CFG1 + VIRTQ_NOTIFY_VECTOR;
  *p = 0x1;

  p = PCI_CFG1 + VIRTQ_SIZE;
  *p = QUEUE_SIZE;

  p = PCI_CFG1 + VIRTQ_DESC;
  *p = desc_table1;
  
  p = PCI_CFG1 + VIRTQ_DRIVER;
  *p = avail_ring1;

  p = PCI_CFG1 + VIRTQ_DEVICE;
  *p = used_ring1;

  p = PCI_CFG1 + MM_RX_BUFFER_ADDR;
  // addrx = (int)rx_buffer & 0x0000000f;
  // switch(addrx){ // Change alignment to 0x4
  //   case 0:
  //     rx_buffer += 4;
  //     break;
  //   case 4:
  //     break;
  //   case 8:
  //     rx_buffer += 12;
  //     break;
  //   case 12:
  //     rx_buffer += 8;
  //     break;
  //   default:
  //     break;
  // }
  
  // switch(addrx){ // Change alignment to 0x8
  //   case 0:
  //     rx_buffer += 8;
  //     break;
  //   case 4:
  //     rx_buffer += 4;
  //     break;
  //   case 8:
  //     break;
  //   case 12:
  //     rx_buffer += 12;
  //     break;
  //   default:
  //     break;
  // }

  //switch(addrx){ // Change alignment to 0xc
  //  case 0:
  //    rx_buffer += 12;
  //    break;
  //  case 4:
  //    rx_buffer += 8;
  //    break;
  //  case 8:
  //    rx_buffer += 4;
  //    break;
  //  case 12:
  //    break;
  //  default:
  //    break;
  //}

 *p = rx_buffer;

  p = PCI_CFG1 + MM_RX_BUFFER_SIZE;
  *p = RX_BUF_SIZE;

  p = PCI_CFG1 + PCIE_CMD_W1S;
  *p = 0x80000024; // virtIO and polling modes selected

  used_ring1->idx = 0;
  used_ring1->flags = 0;

  avail_idx1     = 0;
  avail_int_idx1 = 0;
  //used_idx0      = 0;
  //used_int_idx0  = 0;


  // Infinite loop
  while(1){
    // poll for an interrupt from the pcie controller and handle the interrupt
    if(*poll_addr1 == 1){ //h2c
      notify_counter1++;
      printf("Notification %d received on Q1.\n", notify_counter1);
      *poll_addr1 = 0;
      asm("");
    
/**************/
      avail_idx1 = avail_ring1->idx;

      while(avail_int_idx1 != avail_idx1){ // Buffers exposed
        desc_tab_idx1 = avail_ring1->ring[avail_int_idx1 % QUEUE_SIZE];


      //   desc_table0[avail_int_idx1 % QUEUE_SIZE].addr    = desc_table1[desc_tab_idx1].addr;

      //   desc_table0[avail_int_idx1 % QUEUE_SIZE].padding = 0;
      //   desc_table0[avail_int_idx1 % QUEUE_SIZE].len     = desc_table1[desc_tab_idx1].len;
      //   desc_table0[avail_int_idx1 % QUEUE_SIZE].flags   = 0;
      //   desc_table0[avail_int_idx1 % QUEUE_SIZE].next    = 0;

      //   avail_ring0->ring[avail_int_idx1 % QUEUE_SIZE] = avail_int_idx1 % QUEUE_SIZE;
      //   
        used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].id = desc_tab_idx1;
        used_ring1->ring[avail_int_idx1 % QUEUE_SIZE].len = desc_table1[desc_tab_idx1].len;

        avail_int_idx1++;

        used_ring1->idx = avail_int_idx1;
      //   avail_ring0->idx = avail_int_idx1;
      } // Buffers exposed

      // // Notify the controller for TX request
      // p = PCI_CFG0 + VIRTQ_NOTIFY_REG;
      // *p = 1;

      // p = PCI_CFG0 + PCIE_STATUS;

      // do{
      // j = *p;
      // k = j & 0x20000000;
      // } while(k == 0x20000000);
/**************/

    }
    else if(*poll_addr0 == 1){
      notify_counter0++;
      printf("Notification %d received on Q0.\n", notify_counter0);
      notify_counter0++;
      *poll_addr0 = 0;
    }
  }
  return (EXIT_SUCCESS);
  
alloc_error0:
  while(1){printf("Error allocating buffer 0");}

alloc_error1:
  while(1){printf("Error allocating buffer 1");}

alloc_error2:
  while(1){printf("Error allocating buffer 2");}

alloc_error3:
  while(1){printf("Error allocating buffer 3");}

alloc_error4:
  while(1){printf("Error allocating buffer 4");}

alloc_error5:
  while(1){printf("Error allocating buffer 5");}

alloc_error6:
  while(1){printf("Error allocating buffer 6");}

alloc_error7:
  while(1){printf("Error allocating buffer 7");}

alloc_error8:
  while(1){printf("Error allocating buffer 8");}
}

