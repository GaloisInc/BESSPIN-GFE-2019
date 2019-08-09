/*
 * Linux device driver for Bluespec FPGA-based interconnect networks.
 */

#include <linux/module.h>
#include <linux/version.h>     /* LINUX_VERSION_CODE, KERNEL_VERSION */
#include <linux/pci.h>         /* pci device types, fns, etc. */
#include <linux/errno.h>       /* error codes */
#include <linux/io.h>          /* I/O mapping, reading, writing */
#include <linux/types.h>       /* size_t */
#include <linux/cdev.h>        /* struct cdev */
#include <linux/fs.h>          /* struct file_operations */
#include <linux/init.h>        /* __init, __exit, etc. */
#include <linux/ioctl.h>       /* ioctl macros */
#include <linux/interrupt.h>   /* request_irq, free_irq, etc. */
#include <linux/delay.h>       /* udelay */
#include <linux/mm.h>          /* kmalloc, kfree, struct page, etc. */
#include <linux/sched.h>       /* task_struct */
#include <linux/pagemap.h>     /* page_cache_release */
#include <linux/scatterlist.h> /* sg_* operations */
#include <linux/spinlock.h>    /* spinlock_t, spin_lock_irqsave, etc. */
#include <linux/mutex.h>       /* mutex_lock, mutex_unlock, etc. */
#include <linux/poll.h>        /* poll_table, etc. */
#include <linux/time.h>        /* getnstimeofday, struct timespec, etc. */
#include <asm/uaccess.h>       /* copy_to_user, copy_from_user */

#include "bluenoc.h"

/*
 * portability settings across multiple kernel versions
 */

#define USE_INTR_PT_REGS_ARG          (LINUX_VERSION_CODE <  KERNEL_VERSION(2,6,19))
#define USE_CHAINED_SGLIST_API        (LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,24))
#define USE_EXPLICIT_PCI_TABLE_TYPE   ((LINUX_VERSION_CODE < KERNEL_VERSION(2,6,25)) || (LINUX_VERSION_CODE >= KERNEL_VERSION(4,8,0)))
#define DEVICE_CREATE_HAS_DRVDATA_ARG (LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,27))
#define USE_DEVINIT_DEVEXIT_ATTRS     (LINUX_VERSION_CODE <  KERNEL_VERSION(3,8,0))
#define USE_PCI_DIS_LINK_STATE        (LINUX_VERSION_CODE >  KERNEL_VERSION(2,6,32))

#if USE_PCI_DIS_LINK_STATE
#include <linux/pci-aspm.h>    /* disable_link_state */
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(4,12,0)
#define pci_enable_msix_exact pci_enable_msix
#endif

/*
 * portability across 32-bit and 64-bit architectures
 */
#ifndef readq
static inline __u64 readq(const volatile void __iomem *addr)
{
  const volatile u32 __iomem *p = addr;
  u32 low, high;

  low = readl(p);
  high = readl(p + 1);

  return low + ((u64)high << 32);
}
#endif

#ifndef writeq
static inline void writeq(__u64 val, volatile void __iomem *addr)
{
  writel(val, addr);
  writel(val >> 32, addr + 4);
}
#endif

/*
 * driver module data for the kernel
 */

MODULE_AUTHOR ("Bluespec, Inc.");
MODULE_DESCRIPTION ("PCIe device driver for Bluespec FPGA interconnect");
MODULE_LICENSE ("Dual BSD/GPL");
// release script sets MODULE_VERSION.  Do not delete this comment.

/*
 * driver configuration
 */

/* stem used for module and device names */
#define DEV_NAME "bluenoc"

/* version string for the driver */
#define DEV_VERSION "1.2"

/* Bluespec's standard vendor ID */
#define BLUESPEC_VENDOR_ID 0x1be7

/* Bluespec's NoC device ID */
#define BLUESPEC_NOC_DEVICE_ID 0xb100

/* Number of boards to support */
#define NUM_BOARDS 16
#define UNASSIGNED 0

/*
 * Per-device data
 */

/* per-device data that persists from probe to remove */

typedef struct tBoard {
  /* bars */
  void __iomem* bar0io;
  /* pci device pointer */
  struct pci_dev* pci_dev;
  unsigned int    board_number;
  /* cdev structure */
  struct cdev cdev;
  /* board identification fields */
  unsigned int       major_rev;
  unsigned int       minor_rev;
  unsigned int       build;
  unsigned int       timestamp;
  unsigned int       bytes_per_beat;
  unsigned long long content_id;
  /* wait queue used for interrupt notifications */
  unsigned int uses_msix;
  unsigned int irq_num;
  wait_queue_head_t intr_wq;
  /* spin lock used to protect access to DMA information fields */
  spinlock_t dma_lock;
  /* DMA information fields */
  unsigned int read_buffers_level;
  unsigned int read_flushed;
  unsigned int read_completed;
  unsigned int read_queue_full;
  unsigned int read_ok;
  unsigned int write_buffers_level;
  unsigned int write_completed;
  unsigned int write_queue_full;
  unsigned int write_ok;
  /* link to next board */
  struct tBoard* next;
  /* activation status */
  unsigned int activation_level;
  /* debug status */
  tDebugLevel debug_level;
  /* mutexes used to prevent race conditions in read and write functions */
  struct mutex read_mutex;
  struct mutex write_mutex;
  /* accumulators used for profiling */
  unsigned long long read_call_count;
  unsigned long long write_call_count;
  unsigned long long poll_call_count;
  unsigned long long total_bytes_read;
  unsigned long long total_bytes_written;
  unsigned long long total_read_call_ns;
  unsigned long long total_read_blocked_ns;
  unsigned long long total_write_call_ns;
  unsigned long long total_write_blocked_ns;
  unsigned long long interrupt_count;
} tBoard;

static tBoard* board_list = NULL;

/* forward declarations of driver routines */

#if USE_DEVINIT_DEVEXIT_ATTRS
static int __devinit bluenoc_probe(struct pci_dev* dev, const struct pci_device_id* id);
static void __devexit bluenoc_remove(struct pci_dev* dev);
#else
static int bluenoc_probe(struct pci_dev* dev, const struct pci_device_id* id);
static void bluenoc_remove(struct pci_dev* dev);
#endif

static int bluenoc_open(struct inode* inode, struct file* filp);
static int bluenoc_release(struct inode* inode, struct file* filp);

static ssize_t bluenoc_read(struct file* filp, char __user* buf, size_t count, loff_t* loc);
static ssize_t bluenoc_write(struct file* filp, const char __user* buf, size_t count, loff_t* loc);

static unsigned int bluenoc_poll(struct file* filp, poll_table* wait);

static loff_t bluenoc_llseek(struct file* filp, loff_t off, int whence);

static long bluenoc_ioctl(struct file* file, unsigned int cmd, unsigned long arg);

#if USE_INTR_PT_REGS_ARG
static irqreturn_t intr_handler(int irq, void* brd, struct pt_regs* unused);
#else
static irqreturn_t intr_handler(int irq, void* brd);
#endif

static void update_dma_buffer_status(tBoard* this_board);

/* these are the activation levels defined for a board,
 * along with functions for activating and deactivate a
 * board through all of these activation levels.
 */

#define PROBED              (0)
#define BOARD_NUM_ASSIGNED  (1)
#define PCI_DEV_ENABLED     (2)
#define BARS_ALLOCATED      (3)
#define BARS_MAPPED         (4)
#define MAGIC_MATCH         (5)
#define DMA_MASK_SET        (6)
#define MSI_ENABLED         (7)
#define IRQ_ASSIGNED        (8)
#define MSIX_INITIALIZED    (9)
#define PCI_BUS_MASTER     (10)
#define BLUENOC_ACTIVE     (11)

static void deactivate(tBoard* this_board)
{
  if (this_board == NULL) return;

  /* Note: this makes use of C's fall-through switch semantics */
  switch(this_board->activation_level) {
    case BLUENOC_ACTIVE:     { /* deactivate the network */
                               iowrite8(0,this_board->bar0io + 257);
                             } /* fall through */
    case PCI_BUS_MASTER:     { /* disable PCI bus master */
                               pci_clear_master(this_board->pci_dev);
                             } /* fall through */
    case MSIX_INITIALIZED:   { /* set MSI-X Entry 0 Vector Control value to 1 (masked) */
                               if (this_board->uses_msix)
                                 iowrite32(1, this_board->bar0io + 16396);
                             } /* fall through */
    case IRQ_ASSIGNED:       {
                               disable_irq(this_board->irq_num);
                               free_irq(this_board->irq_num, (void*) this_board);
                             } /* fall through */
    case MSI_ENABLED:        { /* disable MSI/MSIX */
                               if (this_board->uses_msix)
                                 pci_disable_msix(this_board->pci_dev);
                               else
                                 pci_disable_msi(this_board->pci_dev);
                             } /* fall through */
    case DMA_MASK_SET:       { ; } /* fall through */
    case MAGIC_MATCH:        { ; } /* fall through */
    case BARS_MAPPED:        { /* unmap PCI BARs */
                               if (this_board->bar0io != NULL)
                                 pci_iounmap(this_board->pci_dev, this_board->bar0io);
                             } /* fall through */
    case BARS_ALLOCATED:     { /* release PCI memory regions */
                               pci_release_regions(this_board->pci_dev);
                             } /* fall through */
    case PCI_DEV_ENABLED:    { /* disable pci device */
                               pci_disable_device(this_board->pci_dev);
                               this_board->activation_level = BOARD_NUM_ASSIGNED;
                             } /* fall through */
    case BOARD_NUM_ASSIGNED: break; /* nothing to deactivate */
    case PROBED:             break; /* nothing to deactivate */
  }
}

static int activate(tBoard* this_board)
{
  if (this_board == NULL) return -EFAULT;

  /* Note: this makes use of C's fall-through switch semantics */
  switch(this_board->activation_level) {
    case PROBED:              { /* assign a board number */
                                unsigned int board_number = 1;
                                while (board_number <= NUM_BOARDS) {
                                  tBoard* brd = board_list;
                                  unsigned int collision = 0;
                                  while (brd != NULL && !collision) {
                                    collision |= (brd->board_number == board_number);
                                    brd = brd->next;
                                  }
                                  if (!collision) break;
                                  ++board_number;
                                }
                                if (board_number > NUM_BOARDS) {
                                  printk(KERN_ERR "%s: %d boards are already in use!\n", DEV_NAME, NUM_BOARDS);
                                  deactivate(this_board);
                                  return -EBUSY;
                                }
                                printk(KERN_INFO "%s: board_number = %d\n", DEV_NAME, board_number);
                                this_board->board_number = board_number;
                                this_board->activation_level = BOARD_NUM_ASSIGNED;
                              } /* fall through */
    case BOARD_NUM_ASSIGNED:  { /* enable the PCI device */
                                if (pci_enable_device(this_board->pci_dev) != 0) {
                                  printk(KERN_ERR "%s: failed to enable %s\n", DEV_NAME, pci_name(this_board->pci_dev));
                                  deactivate(this_board);
                                  return -EFAULT;
                                }
                                this_board->activation_level = PCI_DEV_ENABLED;
                              } /* fall through */
    case PCI_DEV_ENABLED:     { /* reserve PCI memory regions */
                                if (pci_request_region(this_board->pci_dev, 0, "bar0") != 0) {
                                  deactivate(this_board);
                                  return -EBUSY;
                                }
                                this_board->activation_level = BARS_ALLOCATED;
                              } /* fall through */
    case BARS_ALLOCATED:      { /* map BARs */
                                this_board->bar0io = pci_iomap(this_board->pci_dev, 0, 0);
                                if (NULL == this_board->bar0io) {
                                  deactivate(this_board);
                                  return -EFAULT;
                                }
                                this_board->activation_level = BARS_MAPPED;
                              } /* fall through */
    case BARS_MAPPED:         { /* check the magic number in BAR 0 */
                                unsigned long long magic_num = readq(this_board->bar0io);
                                unsigned long long expected_magic = 'B'
                                             | ((unsigned long long)'l' << 8)
                                             | ((unsigned long long)'u' << 16)
                                             | ((unsigned long long)'e' << 24)
                                             | ((unsigned long long)'s' << 32)
                                             | ((unsigned long long)'p' << 40)
                                             | ((unsigned long long)'e' << 48)
                                             | ((unsigned long long)'c' << 56);
                                if (magic_num != expected_magic) {
                                  printk(KERN_ERR "%s: magic number %llx does not match expected %llx\n", DEV_NAME, magic_num, expected_magic);
                                  deactivate(this_board);
                                  return -EINVAL;
                                }
                                {
                                  unsigned int minor_rev = ioread32(this_board->bar0io + 8);
                                  unsigned int major_rev = ioread32(this_board->bar0io + 12);
                                  unsigned int build_version = ioread32(this_board->bar0io + 16);
                                  unsigned int timestamp = ioread32(this_board->bar0io + 20);
                                  unsigned int noc_params = ioread32(this_board->bar0io + 28);
                                  unsigned long long board_content_id = readq(this_board->bar0io + 32);

                                  /* basic board info */

                                  printk(KERN_INFO "%s: revision = %d.%d\n", DEV_NAME, major_rev, minor_rev);
                                  printk(KERN_INFO "%s: build_version = %d\n", DEV_NAME, build_version);
                                  printk(KERN_INFO "%s: timestamp = %d\n", DEV_NAME, timestamp);
                                  printk(KERN_INFO "%s: NoC is using %d byte beats\n", DEV_NAME, (noc_params & 0xff));
                                  printk(KERN_INFO "%s: Content identifier is %llx\n", DEV_NAME, board_content_id);

                                  this_board->major_rev      = major_rev;
                                  this_board->minor_rev      = minor_rev;
                                  this_board->build          = build_version;
                                  this_board->timestamp      = timestamp;
                                  this_board->bytes_per_beat = noc_params & 0xff;
                                  this_board->content_id     = board_content_id;
                                }
                                this_board->activation_level = MAGIC_MATCH;
                              } /* fall through */
    case MAGIC_MATCH:         { /* set DMA mask */
                                if (pci_set_dma_mask(this_board->pci_dev, DMA_BIT_MASK(48)) != 0) {
                                  printk(KERN_ERR "%s: pci_set_dma_mask failed for 48-bit DMA\n", DEV_NAME);
                                  deactivate(this_board);
                                  return -EIO;
                                }
                                init_waitqueue_head(&(this_board->intr_wq));
                                spin_lock_init(&(this_board->dma_lock));
                                update_dma_buffer_status(this_board);
                                this_board->activation_level = DMA_MASK_SET;
                              } /* fall through */
    case DMA_MASK_SET:        { /* enable MSI or MSI-X */
                                  struct msix_entry msix_entries[1];
                                  msix_entries[0].entry = 0;
                                  if (pci_enable_msix_exact(this_board->pci_dev, msix_entries, 1) == 0) {
                                    this_board->uses_msix = 1;
                                    this_board->irq_num = msix_entries[0].vector;
                                    if (this_board->debug_level & DEBUG_INTR)
                                      printk(KERN_INFO "%s: Using MSI-X interrupts\n", DEV_NAME);
				  } else {
				    if (pci_enable_msi(this_board->pci_dev) == 0) {
				      this_board->uses_msix = 0;
				      this_board->irq_num = this_board->pci_dev->irq;
				      //if (this_board->debug_level & DEBUG_INTR)
				      printk(KERN_INFO "%s: Using MSI interrupts\n", DEV_NAME);
				    } else {
				      printk(KERN_ERR "%s: Failed to setup MSI or MSI-X interrupts\n", DEV_NAME);
				      deactivate(this_board);
				      return -EFAULT;
				    }
				  }
                                this_board->activation_level = MSI_ENABLED;
                              } /* fall through */
    case MSI_ENABLED:         { /* install an IRQ handler */
                                int result;
                                result = request_irq(this_board->irq_num, intr_handler, 0, DEV_NAME, (void*) this_board);
                                if (result != 0) {
                                  printk(KERN_ERR "%s: Failed to get requested IRQ %d\n", DEV_NAME, this_board->irq_num);
                                  deactivate(this_board);
                                  return -EBUSY;
                                }
                                this_board->activation_level = IRQ_ASSIGNED;
                              } /* fall through */
    case IRQ_ASSIGNED:        { /* set MSI-X Entry 0 Vector Control value to 0 (unmasked) */
                                if (this_board->uses_msix) {
                                  printk(KERN_INFO "%s: MSI-X interrupts enabled with IRQ %d\n", DEV_NAME, this_board->irq_num);
                                  iowrite32(0, this_board->bar0io + 16396);
                                }
                                this_board->activation_level = MSIX_INITIALIZED;
                              } /* fall through */
    case MSIX_INITIALIZED:    { /* enable PCI bus master */
                                pci_set_master(this_board->pci_dev);
                                this_board->activation_level = PCI_BUS_MASTER;
                              } /* fall through */
    case PCI_BUS_MASTER:      { /* activate the network */
                                iowrite8(1,this_board->bar0io + 257);
                                this_board->activation_level = BLUENOC_ACTIVE;
                              } /* fall through */
    case BLUENOC_ACTIVE:      { break; } /* fully activated! */
  }

  return 0; /* successful activation */
}

/*
 * driver initialization and exit
 *
 * these routines are responsible for allocating and
 * freeing kernel resources, creating device nodes,
 * registering the driver, obtaining a major and minor
 * numbers, etc.
 */

/* static device data */
static dev_t         device_number;
static struct class* bluenoc_class = NULL;
static unsigned int  open_count[NUM_BOARDS+1];

/* file operations pointers */
static const struct file_operations bluenoc_fops = {
  .owner          = THIS_MODULE,
  .open           = bluenoc_open,
  .release        = bluenoc_release,
  .read           = bluenoc_read,
  .write          = bluenoc_write,
  .llseek         = bluenoc_llseek,
  .poll           = bluenoc_poll,
  .unlocked_ioctl = bluenoc_ioctl,
  .compat_ioctl   = bluenoc_ioctl
};

/* PCI ID pattern table */
#if USE_EXPLICIT_PCI_TABLE_TYPE
static struct pci_device_id bluenoc_id_table[] = {
#else
static DEFINE_PCI_DEVICE_TABLE(bluenoc_id_table) = {
#endif
  {PCI_DEVICE(BLUESPEC_VENDOR_ID, BLUESPEC_NOC_DEVICE_ID)},
  { /* end: all zeros */ }
};

MODULE_DEVICE_TABLE(pci, bluenoc_id_table);

/* PCI driver operations pointers */
static struct pci_driver bluenoc_driver = {
  .name     = DEV_NAME,
  .id_table = bluenoc_id_table,
  .probe    = bluenoc_probe,
#if USE_DEVINIT_DEVEXIT_ATTRS
  .remove   = __devexit_p(bluenoc_remove)
#else
  .remove   = bluenoc_remove
#endif
};

/* utility routine to clear the status register and DMA status fields
 * in the tBoard structure
 */

typedef enum { START_READ, START_WRITE } tDMAClearReason;

static void clear_dma_status(tBoard* this_board, tDMAClearReason reason)
{
  unsigned long flags;

  spin_lock_irqsave(&(this_board->dma_lock), flags);

  if (reason == START_READ) {
    iowrite32(0,this_board->bar0io + 2048);
    this_board->read_flushed    = 0;
    this_board->read_completed  = 0;
    this_board->read_ok         = 0;
  }
  else if (reason == START_WRITE) {
    iowrite32(0,this_board->bar0io + 2052);
    this_board->write_completed = 0;
    this_board->write_ok        = 0;
  }

  spin_unlock_irqrestore(&(this_board->dma_lock), flags);
}

/* utility routine to read the status register and fill in the
 * DMA status fields in the tBoard structure
 */

static void update_dma_buffer_status(tBoard* this_board)
{
  unsigned long long buffer_status;
  unsigned long flags;

  spin_lock_irqsave(&(this_board->dma_lock), flags);

  buffer_status = readq(this_board->bar0io + 2048);

  this_board->read_buffers_level  = (unsigned int) (buffer_status & 0x1fllu);
  this_board->read_flushed        = (buffer_status & (1llu << 5)) != 0;
  this_board->read_completed      = (buffer_status & (1llu << 6)) != 0;
  this_board->read_queue_full     = (buffer_status & (1llu << 7)) != 0;
  this_board->read_ok             = (buffer_status & (1llu << 8)) != 0;

  this_board->write_buffers_level = (unsigned int) (buffer_status >> 32) & 0x1fllu;
  this_board->write_completed     = (buffer_status & (1llu << 38)) != 0;
  this_board->write_queue_full    = (buffer_status & (1llu << 39)) != 0;
  this_board->write_ok            = (buffer_status & (1llu << 40)) != 0;

  spin_unlock_irqrestore(&(this_board->dma_lock), flags);
}


/* first routine called on module load */
static int __init bluenoc_init(void)
{
  int status;

  /* dynamically allocate a device number */
  if (alloc_chrdev_region(&device_number, 1, NUM_BOARDS, DEV_NAME) < 0) {
    printk(KERN_ERR "%s: failed to allocate character device region\n", DEV_NAME);
    return -1;
  }

  /* initialize driver data */
  board_list = NULL;

  /* register the driver with the PCI subsystem */
  status = pci_register_driver(&bluenoc_driver);
  if (status < 0) {
    printk(KERN_ERR "%s: failed to register PCI driver\n", DEV_NAME);
    return status;
  }

  /* log the fact that we loaded the driver module */
  printk(KERN_INFO "%s: Registered Bluespec BlueNoC driver %s\n", DEV_NAME, DEV_VERSION);
  printk(KERN_INFO "%s: Major = %d  Minors = %d to %d\n",
         DEV_NAME, MAJOR(device_number), MINOR(device_number), MINOR(device_number) + NUM_BOARDS - 1);

  return 0; /* success */
}

/* routine called on module unload */
static void __exit bluenoc_exit (void)
{
  /* unregister the driver with the PCI subsystem */
  pci_unregister_driver(&bluenoc_driver);

  /* release reserved device numbers */
  unregister_chrdev_region(device_number, NUM_BOARDS);

  /* log that the driver module has been unloaded */
  printk(KERN_INFO "%s: Unregistered Bluespec BlueNoC driver %s\n", DEV_NAME, DEV_VERSION);
}

/* register init and exit routines */
module_init(bluenoc_init);
module_exit(bluenoc_exit);

/* driver PCI operations */

#if USE_DEVINIT_DEVEXIT_ATTRS
static int __devinit bluenoc_probe(struct pci_dev* dev, const struct pci_device_id* id)
#else
static int bluenoc_probe(struct pci_dev* dev, const struct pci_device_id* id)
#endif
{
  int err = 0;
  tBoard* this_board = NULL;

  printk(KERN_INFO "%s: PCI probe for 0x%04x 0x%04x\n", DEV_NAME, dev->vendor, dev->device);

  /* double-check vendor and device */
  if ((dev->vendor != BLUESPEC_VENDOR_ID) || (dev->device != BLUESPEC_NOC_DEVICE_ID)) {
    printk(KERN_ERR "%s: probe with invalid vendor or device ID\n", DEV_NAME);
    err = -EINVAL;
    goto exit_bluenoc_probe;
  }

  /* disable ASPM */
  #if USE_PCI_DIS_LINK_STATE
  pci_disable_link_state(dev, PCIE_LINK_STATE_L0S | PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);
  #endif

  /* allocate a structure for this board */
  this_board = (tBoard*) kmalloc(sizeof(tBoard),GFP_KERNEL);
  if (NULL == this_board) {
    printk(KERN_ERR "%s: unable to allocate memory for board structure\n", DEV_NAME);
    err = -EINVAL;
    goto exit_bluenoc_probe;
  }

  /* if this is the first, create the udev class */
  if (NULL == bluenoc_class)
    bluenoc_class = class_create(THIS_MODULE, "Bluespec");

  /* initially, the board structure contains only the pci_dev pointer and is in
   * the probed state with no assigned number.
   */
  this_board->activation_level = PROBED;
  this_board->pci_dev          = dev;
  this_board->board_number     = UNASSIGNED;
  this_board->next             = NULL;
  this_board->debug_level      = DEBUG_OFF;

  mutex_init(&(this_board->read_mutex));
  mutex_init(&(this_board->write_mutex));

  /* insert board into linked list of boards */
  this_board->next = board_list;
  board_list = this_board;

  /* activate the board */
  if ((err = activate(this_board)) >= 0) {
    dev_t this_device_number = MKDEV(MAJOR(device_number),this_board->board_number);
    open_count[this_board->board_number] = 0;

    /* add the device operations */
    cdev_init(&this_board->cdev,&bluenoc_fops);
    if (cdev_add(&this_board->cdev,this_device_number,1) != 0) {
      printk(KERN_ERR "%s: cdev_add failed\n", DEV_NAME);
      deactivate(this_board);
      err = -EFAULT;
    } else {
      /* create a device node via udev */
#if DEVICE_CREATE_HAS_DRVDATA_ARG
      device_create(bluenoc_class, NULL, this_device_number, NULL, "%s_%d", DEV_NAME, this_board->board_number);
#else
      device_create(bluenoc_class, NULL, this_device_number, "%s_%d", DEV_NAME, this_board->board_number);
#endif
      printk(KERN_INFO "%s: /dev/%s_%d device file created\n", DEV_NAME, DEV_NAME, this_board->board_number);
    }
  }

  if (err < 0) {
    /* remove the board from the list */
    board_list = this_board->next;
    kfree(this_board);
  }

 exit_bluenoc_probe:
  return err;
}

#if USE_DEVINIT_DEVEXIT_ATTRS
static void __devexit bluenoc_remove(struct pci_dev* dev)
#else
static void bluenoc_remove(struct pci_dev* dev)
#endif
{
  tBoard* this_board = NULL;
  tBoard* prev_board = NULL;
  dev_t this_device_number;

  /* locate device-specific data for this board */
  for (this_board = board_list; this_board != NULL; prev_board = this_board, this_board = this_board->next) {
    if (this_board->pci_dev == dev) break;
  }
  if (NULL == this_board) {
    printk(KERN_ERR "%s: Unable to locate board when removing PCI device %p\n", DEV_NAME, dev);
    return;
  }

  /* deactivate the board */
  deactivate(this_board);

  /* remove device node in udev */
  this_device_number = MKDEV(MAJOR(device_number),this_board->board_number);
  device_destroy(bluenoc_class,this_device_number);
  printk(KERN_INFO "%s: /dev/%s_%d device file removed\n", DEV_NAME, DEV_NAME, MINOR(this_device_number));

  /* remove device */
  cdev_del(&this_board->cdev);

  /* free the board structure */
  if (prev_board)
    prev_board->next = this_board->next;
  else
    board_list = this_board->next;
  kfree(this_board);

  /* release udev resources if this is the last board */
  if (NULL == board_list) {
    class_destroy(bluenoc_class);
    bluenoc_class = NULL;
  }
}

/*
 * interrupt handler
 */

#if USE_INTR_PT_REGS_ARG
static irqreturn_t intr_handler(int irq, void* brd, struct pt_regs* unused)
#else
static irqreturn_t intr_handler(int irq, void* brd)
#endif
{
  tBoard* this_board = brd;

  if (this_board->debug_level & DEBUG_PROFILE)
    this_board->interrupt_count += 1;

  update_dma_buffer_status(this_board);

  if (this_board->debug_level & DEBUG_INTR) {
    printk(KERN_INFO "%s_%d: interrupt!  buffer levels: %0d wr / %0d rd\n",
           DEV_NAME, this_board->board_number, this_board->write_buffers_level, this_board->read_buffers_level);
    printk(KERN_INFO "%s_%d:             read is%s allowed   write is%s allowed\n",
           DEV_NAME, this_board->board_number, this_board->read_ok ? "" : " not", this_board->write_ok ? "" : " not");
    if (this_board->write_completed)
      printk(KERN_INFO "%s_%d:   WRITE TRANSFER COMPLETED!\n", DEV_NAME, this_board->board_number);
    if (this_board->read_completed)
      printk(KERN_INFO "%s_%d:   READ TRANSFER COMPLETED!\n", DEV_NAME, this_board->board_number);
    if (this_board->read_flushed)
      printk(KERN_INFO "%s_%d:   READ TRANSFER FLUSHED!\n", DEV_NAME, this_board->board_number);
  }

  wake_up_interruptible(&(this_board->intr_wq));

  return IRQ_HANDLED;
}


/*
 * driver file operations
 */


/* open the device file */
static int bluenoc_open(struct inode *inode, struct file *filp)
{
  int err = 0;
  unsigned int this_board_number = UNASSIGNED;
  tBoard* this_board = NULL;
  tBoard* tmp_board = NULL;

  /* figure out the board number */
  this_board_number = iminor(inode);

  /* store the board pointer for easy access */
  for (tmp_board = board_list; tmp_board != NULL; tmp_board = tmp_board->next) {
    if (tmp_board->board_number == this_board_number) {
      this_board = tmp_board;
      break;
    }
  }
  if (NULL == this_board) {
    printk(KERN_ERR "%s_%d: Unable to locate board\n", DEV_NAME, this_board_number);
    err = -ENXIO;
    goto exit_bluenoc_open;
  }
  filp->private_data = (void*) this_board;

  /* increment the open file count */
  open_count[this_board_number] += 1;

  if (this_board->debug_level & DEBUG_CALLS) {
    /* log the operation */
    printk(KERN_INFO "%s_%d: Opened device file\n", DEV_NAME, this_board_number);
  }

  goto exit_bluenoc_open;

 exit_bluenoc_open:
  return err;
}

/* close the device file */
static int bluenoc_release (struct inode *inode, struct file *filp)
{
  unsigned int this_board_number = UNASSIGNED;
  tBoard* this_board;

  /* figure out the board number */
  this_board_number = iminor(inode);

  /* decrement the open file count */
  open_count[this_board_number] -= 1;

  /* access the tBoard structure for this file */
  this_board = (tBoard*) filp->private_data;

  if (this_board->debug_level & DEBUG_CALLS) {
    /* log the operation */
    printk (KERN_INFO "%s_%d: Closed device file\n", DEV_NAME, this_board_number);
  }

  return 0; /* success */
}

/* read data from the device */
static ssize_t bluenoc_read(struct file* filp, char __user* buf, size_t count, loff_t* loc)
{
  int err = 0;
  int result;
  unsigned long first_page;
  unsigned long last_page;
  unsigned int offset;
  unsigned int first_page_len;
  unsigned int last_page_len;
  int num_pages;
  struct page** pages;
  tBoard* this_board;
  int n;
#if USE_CHAINED_SGLIST_API
  struct sg_table dma_table;
#else
  struct scatterlist* sg_table;
#endif
  struct scatterlist* sg;
  int num_dma_xfers;
  unsigned int slots_free = 0;
  unsigned int byte_count = 0;
  struct timespec start_time;
  struct timespec block_time;
  struct timespec unblock_time;
  struct timespec finish_time;
  unsigned long long ns;

  /* access the tBoard structure for this file */
  this_board = (tBoard*) filp->private_data;

  if (this_board->debug_level & (DEBUG_CALLS | DEBUG_DMA)) {
    /* log the operation */
    printk( KERN_INFO "%s_%d: read %0llu into %p\n"
          , DEV_NAME, this_board->board_number, (unsigned long long)count, buf
          );
  }

  if (this_board->activation_level != BLUENOC_ACTIVE) return -EIO;

  if (this_board->debug_level & DEBUG_PROFILE) {
    this_board->read_call_count += 1;
    getnstimeofday(&start_time);
  }

  /* if asked to read 0 bytes, we're done. */
  if (count == 0) return 0;

  /* convert the user buffer pointer to page / offset format and compute the number
   * of pages in the user buffer
   */
  first_page = (unsigned long) buf & PAGE_MASK;
  last_page = (unsigned long) (buf + count - 1) & PAGE_MASK;
  offset = (unsigned int) ((unsigned long) buf & ~PAGE_MASK);
  num_pages = (last_page >> PAGE_SHIFT) - (first_page >> PAGE_SHIFT) + 1;
  if (1 == num_pages)
    first_page_len = count;
  else
    first_page_len = PAGE_SIZE - offset;

  last_page_len = (unsigned int) ((unsigned long) (buf + count) & ~PAGE_MASK);
  // Corner case when the start of the buffer is perfectly aligned
  if (last_page_len == 0) {
    last_page_len = PAGE_SIZE;
  }

  if (num_pages > 4096) {
    printk(KERN_ERR "%s_%d: Read buffer is too large\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto exit_bluenoc_read;
  }

  /* the buffer must be aligned on 128-byte boundaries */
  if ((offset % 128) != 0) {
    printk(KERN_ERR "%s_%d: Read buffer is not 128B aligned\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto exit_bluenoc_read;
  }

  /* lock the buffer pages in memory */
  pages = kmalloc(num_pages * sizeof(struct page *), GFP_KERNEL);
  if (NULL == pages) {
    printk(KERN_ERR "%s_%d: Failed to allocate memory when mapping user pages\n", DEV_NAME, this_board->board_number);
    err = -ENOMEM;
    goto exit_bluenoc_read;
  }
  result = get_user_pages_fast(first_page, num_pages, 1, pages);
  if (result != num_pages) {
    printk(KERN_ERR "%s_%d: get_user_pages_fast failed\n", DEV_NAME, this_board->board_number);
    err = (result < 0) ? result : -EINVAL;
    if (result > 0) {
      for (n = 0; n < result; ++n)
        put_page(pages[n]);
    }
    goto free_page_pointer_mem;
  }

  /* map the buffer for scatter-gather DMA */
#if USE_CHAINED_SGLIST_API
  result = sg_alloc_table(&dma_table, num_pages, GFP_KERNEL);
  if (result != 0) {
#else
  sg_table = kcalloc(num_pages, sizeof(struct scatterlist), GFP_KERNEL);
  if (sg_table == NULL) {
#endif
    printk(KERN_ERR "%s_%d: Failed to allocate scatter-gather table\n", DEV_NAME, this_board->board_number);
    err = -ENOMEM;
    goto release_locked_pages;
  }
#if USE_CHAINED_SGLIST_API
  sg = dma_table.sgl;
  sg_set_page(sg, pages[0], first_page_len, offset);
#else
  sg = sg_table;
  sg->page   = pages[0];
  sg->offset = offset;
  sg->length = first_page_len;
#endif
  if (this_board->debug_level & DEBUG_DMA)
    printk(KERN_INFO "%s_%d: sg[0] = %0d @ %p + %x\n", DEV_NAME, this_board->board_number, first_page_len, page_address(pages[0]), offset);
#if USE_CHAINED_SGLIST_API
  sg = sg_next(sg);
#else
  ++sg;
#endif
  if (num_pages > 2) {
    for (n = 1; n < num_pages - 1; ++n) {
#if USE_CHAINED_SGLIST_API
      sg_set_page(sg, pages[n], PAGE_SIZE, 0);
#else
      sg->page   = pages[n];
      sg->offset = 0;
      sg->length = PAGE_SIZE;
#endif
      if (this_board->debug_level & DEBUG_DMA)
        printk(KERN_INFO "%s_%d: sg[%0d] = %0lu @ %p + %x\n", DEV_NAME, this_board->board_number, n, PAGE_SIZE, page_address(pages[n]), 0);
#if USE_CHAINED_SGLIST_API
      sg = sg_next(sg);
#else
      ++sg;
#endif
    }
  }
  if (num_pages > 1) {
#if USE_CHAINED_SGLIST_API
    sg_set_page(sg, pages[num_pages-1], last_page_len, 0);
#else
    sg->page   = pages[num_pages-1];
    sg->offset = 0;
    sg->length = last_page_len;
#endif
    if (this_board->debug_level & DEBUG_DMA)
      printk(KERN_INFO "%s_%d: sg[%0d] = %0d @ %p + %x\n", DEV_NAME, this_board->board_number, num_pages-1, last_page_len, page_address(pages[num_pages-1]), 0);
  }

#if USE_CHAINED_SGLIST_API
  num_dma_xfers = pci_map_sg(this_board->pci_dev, dma_table.sgl, num_pages, DMA_FROM_DEVICE);
#else
  num_dma_xfers = pci_map_sg(this_board->pci_dev, sg_table, num_pages, DMA_FROM_DEVICE);
#endif
  if (num_dma_xfers < 1) {
    printk(KERN_ERR "%s_%d: Failed to map scatter-gather list to DMA blocks\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto unmap_sg_list;
  }

  if (this_board->debug_level & DEBUG_DMA) {
    /* check for out-of-range addresses or blocks which are too long */
#if USE_CHAINED_SGLIST_API
    sg = dma_table.sgl;
#endif
    for (n = 0; n < num_dma_xfers; ++n) {
      dma_addr_t   addr;
      unsigned int len;
#if !USE_CHAINED_SGLIST_API
      sg = &sg_table[n];
#endif
      addr = sg_dma_address(sg);
      len  = sg_dma_len(sg);
      printk(KERN_INFO "%s_%d: mapped_sg[%0d] = %0d @ %llx + %x\n", DEV_NAME, this_board->board_number, n, len, (unsigned long long)addr, sg->offset);
      if ((unsigned long long)addr != ((unsigned long long)addr & 0x0000ffffffffffffllu)) {
        printk(KERN_ERR "%s_%d: DMA block address is out-of-range (%llx)\n", DEV_NAME, this_board->board_number, (unsigned long long)addr);
        err = -EFAULT;
        goto unmap_sg_list;
      }
      if (len > 16384) {
        printk(KERN_ERR "%s_%d: DMA block length is out-of-range (%0d)\n", DEV_NAME, this_board->board_number, len);
        err = -EFAULT;
        goto unmap_sg_list;
      }
#if USE_CHAINED_SGLIST_API
      sg = sg_next(sg);
#endif
    }
  }

  /* begin critical section here */
  if (mutex_trylock(&(this_board->read_mutex)) == 0) {
    err = -EBUSY;
    goto unmap_sg_list;
  }

  /* program the device to perform DMA */
  clear_dma_status(this_board,START_READ);
#if USE_CHAINED_SGLIST_API
  sg = dma_table.sgl;
#else
  sg = sg_table;
  n  = 0;
#endif
  slots_free = 16 - this_board->read_buffers_level;
  while (sg != NULL) {
    dma_addr_t   addr = sg_dma_address(sg);
    unsigned int len  = sg_dma_len(sg);
    unsigned long long dma_cmd;
    unsigned int done = 0;
#if USE_CHAINED_SGLIST_API
    sg = sg_next(sg);
#else
    ++n;
    if (n == num_dma_xfers)
      sg = NULL;
    else
      sg = &sg_table[n];
#endif
    dma_cmd = (((sg == NULL) ? 0x1llu : 0x0llu) << 63)
            | (((unsigned long long)len & 0x3fff) << 48)
            | ((unsigned long long)addr & 0x0000ffffffffffffllu);
    while (slots_free == 0) {
      /* wait for more slots to become available */
      if (this_board->debug_level & DEBUG_DMA)
        printk(KERN_INFO "%s_%d: waiting for a free read cmd slot\n", DEV_NAME, this_board->board_number);
      udelay(5); /* must give time for DMA command to be reflected in buffer status */
      update_dma_buffer_status(this_board);
      result = wait_event_interruptible(this_board->intr_wq,!this_board->read_queue_full);
      if (result != 0) {
        err = -EIO;
        mutex_unlock(&(this_board->read_mutex));
        goto unmap_sg_list;
      }
      if (this_board->read_flushed) {
        /* the read was terminated before the entire buffer list was sent,
         * so the device will be flushing its scatter gather list.
         */
        if (this_board->debug_level & DEBUG_DMA)
          printk(KERN_INFO "%s_%d: sending end-of-list due to read flush\n", DEV_NAME, this_board->board_number);
        writeq((0x1llu << 63), this_board->bar0io + 4096);
        done = 1;
        break;
      }
      slots_free = 16 - this_board->read_buffers_level;
    }
    if (done) break;
    if (slots_free == 1) dma_cmd |= (0x1llu << 62);
    if (this_board->debug_level & DEBUG_DMA)
      printk(KERN_INFO "%s_%d: sending dma cmd = %llx\n", DEV_NAME, this_board->board_number, dma_cmd);
    writeq(dma_cmd, this_board->bar0io + 4096);
    --slots_free;
  }
  if (this_board->debug_level & DEBUG_DMA)
    printk(KERN_INFO "%s_%d: finished sending scatter-gather list\n", DEV_NAME, this_board->board_number);

  /* block waiting for the DMA to complete */
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&block_time);
  }
  while (!this_board->read_completed && !this_board->read_flushed) {
    result = wait_event_interruptible(this_board->intr_wq,this_board->read_completed || this_board->read_flushed);
    if (result != 0) {
      err = -EIO;
      break;
    }
  }
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&unblock_time);
  }

  /* figure out how much data was actually transfered */
  byte_count = ioread32(this_board->bar0io + 2056);
  if (this_board->debug_level & (DEBUG_CALLS | DEBUG_DMA))
    printk(KERN_INFO "%s_%d: rd transfer count = %d bytes\n", DEV_NAME, this_board->board_number, byte_count);

  /* end critical section here */
  mutex_unlock(&(this_board->read_mutex));

  /* return a count of bytes read */
  if (err != -EIO) {
    err = byte_count;
    if (this_board->debug_level & DEBUG_PROFILE)
      this_board->total_bytes_read += (unsigned long long)byte_count;
  }

  /* mark modified pages */
  for (n = 0; n < num_pages; ++n) {
    if ((byte_count > 0) && !PageReserved(pages[n]))
      SetPageDirty(pages[n]);
    if (n == 0) {
      if (byte_count <= first_page_len)
        break;
      else
        byte_count -= first_page_len;
    }
    else if (n < num_pages - 1) {
      if (byte_count <= PAGE_SIZE)
        break;
      else
        byte_count -= PAGE_SIZE;
    }
  }

 unmap_sg_list:
#if USE_CHAINED_SGLIST_API
  pci_unmap_sg(this_board->pci_dev, dma_table.sgl, num_pages, DMA_FROM_DEVICE);
  sg_free_table(&dma_table);
#else
  pci_unmap_sg(this_board->pci_dev, sg_table, num_pages, DMA_FROM_DEVICE);
  kfree(sg_table);
#endif

 release_locked_pages:
  for (n = 0; n < num_pages; ++n)
    put_page(pages[n]);

 free_page_pointer_mem:
  kfree(pages);

 exit_bluenoc_read:
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&finish_time);
    ns = (finish_time.tv_sec - start_time.tv_sec) * 1000000000llu;
    ns += (finish_time.tv_nsec - start_time.tv_nsec);
    this_board->total_read_call_ns += ns;
    ns = (unblock_time.tv_sec - block_time.tv_sec) * 1000000000llu;
    ns += (unblock_time.tv_nsec - block_time.tv_nsec);
    this_board->total_read_blocked_ns += ns;
  }
  return err;
}

/* write data to the device */
static ssize_t bluenoc_write(struct file* filp, const char __user* buf, size_t count, loff_t* loc)
{
  int err = 0;
  int result;
  unsigned long first_page;
  unsigned long last_page;
  unsigned int offset;
  unsigned int first_page_len;
  unsigned int last_page_len;
  int num_pages;
  struct page** pages;
  tBoard* this_board;
  int n;
#if USE_CHAINED_SGLIST_API
  struct sg_table dma_table;
#else
  struct scatterlist* sg_table;
#endif
  struct scatterlist* sg;
  int num_dma_xfers;
  unsigned int slots_free = 0;
  unsigned int byte_count = 0;
  struct timespec start_time;
  struct timespec block_time;
  struct timespec unblock_time;
  struct timespec finish_time;
  unsigned long long ns;

  /* access the tBoard structure for this file */
  this_board = (tBoard*) filp->private_data;

  if (this_board->debug_level & (DEBUG_CALLS | DEBUG_DMA))
    printk( KERN_INFO "%s_%d: write %0llu from %p\n"
          , DEV_NAME, this_board->board_number, (unsigned long long) count, buf
          );

  if (this_board->activation_level != BLUENOC_ACTIVE) return -EIO;

  if (this_board->debug_level & DEBUG_PROFILE) {
    this_board->write_call_count += 1;
    getnstimeofday(&start_time);
  }

  /* if asked to write 0 bytes, we're done. */
  if (count == 0) return 0;

  /* convert the user buffer pointer to page / offset format and compute the number
   * of pages in the user buffer
   */
  first_page = (unsigned long) buf & PAGE_MASK;
  last_page = (unsigned long) (buf + count - 1) & PAGE_MASK;
  offset = (unsigned int) ((unsigned long) buf & ~PAGE_MASK);
  num_pages = (last_page >> PAGE_SHIFT) - (first_page >> PAGE_SHIFT) + 1;
  if (1 == num_pages)
    first_page_len = count;
  else
    first_page_len = PAGE_SIZE - offset;

  last_page_len = (unsigned int) ((unsigned long) (buf + count) & ~PAGE_MASK);
  // Corner case when the start of the buffer is perfectly aligned
  if (last_page_len == 0) {
    last_page_len = PAGE_SIZE;
  }

  if (num_pages > 4096) {
    printk(KERN_ERR "%s_%d: Write buffer is too large\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto exit_bluenoc_write;
  }

  /* the buffer must be aligned on 128-byte boundaries */
  if ((offset % 128) != 0) {
    printk(KERN_ERR "%s_%d: Write buffer is not 128B aligned\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto exit_bluenoc_write;
  }

  /* lock the buffer pages in memory */
  pages = kmalloc(num_pages * sizeof(struct page *), GFP_KERNEL);
  if (NULL == pages) {
    printk(KERN_ERR "%s_%d: Failed to allocate memory when mapping user pages\n", DEV_NAME, this_board->board_number);
    err = -ENOMEM;
    goto exit_bluenoc_write;
  }
  result = get_user_pages_fast(first_page, num_pages, 0, pages);
  if (result != num_pages) {
    printk(KERN_ERR "%s_%d: get_user_pages_fast failed\n", DEV_NAME, this_board->board_number);
    err = (result < 0) ? result : -EINVAL;
    if (result > 0) {
      for (n = 0; n < result; ++n)
        put_page(pages[n]);
    }
    goto free_page_pointer_mem;
  }

  /* map the buffer for scatter-gather DMA */
#if USE_CHAINED_SGLIST_API
  result = sg_alloc_table(&dma_table, num_pages, GFP_KERNEL);
  if (result != 0) {
#else
  sg_table = kcalloc(num_pages, sizeof(struct scatterlist), GFP_KERNEL);
  if (sg_table == NULL) {
#endif
    printk(KERN_ERR "%s_%d: Failed to allocate scatter-gather table\n", DEV_NAME, this_board->board_number);
    err = -ENOMEM;
    goto release_locked_pages;
  }

#if USE_CHAINED_SGLIST_API
  sg = dma_table.sgl;
  sg_set_page(sg, pages[0], first_page_len, offset);
#else
  sg = sg_table;
  sg->page   = pages[0];
  sg->offset = offset;
  sg->length = first_page_len;
#endif
  if (this_board->debug_level & DEBUG_DMA)
    printk(KERN_INFO "%s_%d: sg[0] = %0d @ %p + %x\n", DEV_NAME, this_board->board_number, first_page_len, page_address(pages[0]), offset);
#if USE_CHAINED_SGLIST_API
  sg = sg_next(sg);
#else
  ++sg;
#endif
  if (num_pages > 2) {
    for (n = 1; n < num_pages - 1; ++n) {
#if USE_CHAINED_SGLIST_API
      sg_set_page(sg, pages[n], PAGE_SIZE, 0);
#else
      sg->page   = pages[n];
      sg->offset = 0;
      sg->length = PAGE_SIZE;
#endif
      if (this_board->debug_level & DEBUG_DMA)
        printk(KERN_INFO "%s_%d: sg[%0d] = %0lu @ %p + %x\n", DEV_NAME, this_board->board_number, n, PAGE_SIZE, page_address(pages[n]), 0);
#if USE_CHAINED_SGLIST_API
      sg = sg_next(sg);
#else
      ++sg;
#endif
    }
  }
  if (num_pages > 1) {
#if USE_CHAINED_SGLIST_API
    sg_set_page(sg, pages[num_pages-1], last_page_len, 0);
#else
    sg->page   = pages[num_pages-1];
    sg->offset = 0;
    sg->length = last_page_len;
#endif
    if (this_board->debug_level & DEBUG_DMA)
      printk(KERN_INFO "%s_%d: sg[%0d] = %0d @ %p + %x\n", DEV_NAME, this_board->board_number, num_pages-1, last_page_len, page_address(pages[num_pages-1]), 0);
  }

#if USE_CHAINED_SGLIST_API
  num_dma_xfers = pci_map_sg(this_board->pci_dev, dma_table.sgl, num_pages, DMA_TO_DEVICE);
#else
  num_dma_xfers = pci_map_sg(this_board->pci_dev, sg_table, num_pages, DMA_TO_DEVICE);
#endif
  if (num_dma_xfers < 1) {
    printk(KERN_ERR "%s_%d: Failed to map scatter-gather list to DMA blocks\n", DEV_NAME, this_board->board_number);
    err = -EFAULT;
    goto unmap_sg_list;
  }

  if (this_board->debug_level & DEBUG_DMA) {
    /* check for out-of-range addresses or blocks which are too long */
#if USE_CHAINED_SGLIST_API
    sg = dma_table.sgl;
#endif
    for (n = 0; n < num_dma_xfers; ++n) {
      dma_addr_t   addr;
      unsigned int len;
#if !USE_CHAINED_SGLIST_API
      sg = &sg_table[n];
#endif
      addr = sg_dma_address(sg);
      len  = sg_dma_len(sg);
      printk(KERN_INFO "%s_%d: mapped_sg[%0d] = %0d @ %llx + %x\n", DEV_NAME, this_board->board_number, n, len, (unsigned long long)addr, sg->offset);
      if ((unsigned long long)addr != ((unsigned long long)addr & 0x0000ffffffffffffllu)) {
        printk(KERN_ERR "%s_%d: DMA block address is out-of-range (%llx)\n", DEV_NAME, this_board->board_number, (unsigned long long) addr);
        err = -EFAULT;
        goto unmap_sg_list;
      }
      if (len > 16384) {
        printk(KERN_ERR "%s_%d: DMA block length is out-of-range (%0d)\n", DEV_NAME, this_board->board_number, len);
        err = -EFAULT;
        goto unmap_sg_list;
      }
#if USE_CHAINED_SGLIST_API
      sg = sg_next(sg);
#endif
    }
  }

  /* begin critical section here */
  if (mutex_trylock(&(this_board->write_mutex)) == 0) {
    err = -EBUSY;
    goto unmap_sg_list;
  }

  /* program the device to perform DMA */
  clear_dma_status(this_board,START_WRITE);
#if USE_CHAINED_SGLIST_API
  sg = dma_table.sgl;
#else
  sg = sg_table;
  n  = 0;
#endif
  slots_free = 16 - this_board->write_buffers_level;
  while (sg != NULL) {
    dma_addr_t   addr = sg_dma_address(sg);
    unsigned int len  = sg_dma_len(sg);
    unsigned long long dma_cmd;
#if USE_CHAINED_SGLIST_API
    sg = sg_next(sg);
#else
    ++n;
    if (n == num_dma_xfers)
      sg = NULL;
    else
      sg = &sg_table[n];
#endif
    dma_cmd = (((sg == NULL) ? 0x1llu : 0x0llu) << 63)
            | (((unsigned long long)len & 0x3fff) << 48)
            | ((unsigned long long)addr & 0x0000ffffffffffffllu);
    if (this_board->debug_level & DEBUG_DMA)
      printk(KERN_INFO "%s_%d: slots_free = %d\n", DEV_NAME, this_board->board_number, slots_free);
    while (slots_free == 0) {
      /* wait for more slots to become available */
      if (this_board->debug_level & DEBUG_DMA)
        printk(KERN_INFO "%s_%d: waiting for a free write cmd slot\n", DEV_NAME, this_board->board_number);
      udelay(5); /* must give time for DMA command to be reflected in buffer status */
      update_dma_buffer_status(this_board);
      result = wait_event_interruptible(this_board->intr_wq,!this_board->write_queue_full);
      if (result != 0) {
        err = -EIO;
        mutex_unlock(&(this_board->write_mutex));
        goto unmap_sg_list;
      }
      slots_free = 16 - this_board->write_buffers_level;
    }
    if (slots_free == 1) dma_cmd |= (0x1llu << 62);
    if (this_board->debug_level & DEBUG_DMA)
      printk(KERN_INFO "%s_%d: sending dma cmd = %llx\n", DEV_NAME, this_board->board_number, dma_cmd);
    writeq(dma_cmd, this_board->bar0io + 4104);
    --slots_free;
  }
  if (this_board->debug_level & DEBUG_DMA)
    printk(KERN_INFO "%s_%d: finished sending scatter-gather list\n", DEV_NAME, this_board->board_number);

  /* block waiting for the DMA to complete */
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&block_time);
  }
  while (!this_board->write_completed) {
    result = wait_event_interruptible(this_board->intr_wq,this_board->write_completed);
    if (result != 0) {
      err = -EIO;
      break;
    }
  }
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&unblock_time);
  }

  /* figure out how much data was actually transfered */
  byte_count = ioread32(this_board->bar0io + 2060);
  if (this_board->debug_level & (DEBUG_CALLS | DEBUG_DMA))
    printk(KERN_INFO "%s_%d: wr transfer count = %d bytes\n", DEV_NAME, this_board->board_number, byte_count);

  /* end critical section here */
  mutex_unlock(&(this_board->write_mutex));

  /* return a count of bytes written */
  if (err != -EIO) {
    err = byte_count;
    if (this_board->debug_level & DEBUG_PROFILE)
      this_board->total_bytes_written += (unsigned long long)byte_count;
  }

 unmap_sg_list:
#if USE_CHAINED_SGLIST_API
  pci_unmap_sg(this_board->pci_dev, dma_table.sgl, num_pages, DMA_TO_DEVICE);
  sg_free_table(&dma_table);
#else
  pci_unmap_sg(this_board->pci_dev, sg_table, num_pages, DMA_TO_DEVICE);
  kfree(sg_table);
#endif

 release_locked_pages:
  for (n = 0; n < num_pages; ++n)
    put_page(pages[n]);

 free_page_pointer_mem:
  kfree(pages);

 exit_bluenoc_write:
  if (this_board->debug_level & DEBUG_PROFILE) {
    getnstimeofday(&finish_time);
    ns = (finish_time.tv_sec - start_time.tv_sec) * 1000000000llu;
    ns += (finish_time.tv_nsec - start_time.tv_nsec);
    this_board->total_write_call_ns += ns;
    ns = (unblock_time.tv_sec - block_time.tv_sec) * 1000000000llu;
    ns += (unblock_time.tv_nsec - block_time.tv_nsec);
    this_board->total_write_blocked_ns += ns;
  }
  return err;
}

/* poll operation to predict blocking of reads & writes */
static unsigned int bluenoc_poll(struct file* filp, poll_table* wait)
{
  tBoard* this_board = NULL;
  unsigned int mask = 0;

  /* access the tBoard structure for this file */
  this_board = (tBoard*) filp->private_data;

  if (this_board->debug_level & DEBUG_CALLS)
    printk(KERN_INFO "%s_%d: poll function called\n", DEV_NAME, this_board->board_number);

  if (this_board->activation_level != BLUENOC_ACTIVE) return 0;

  if (this_board->debug_level & DEBUG_PROFILE)
    this_board->poll_call_count += 1;

  poll_wait(filp, &this_board->intr_wq, wait);
  if (this_board->read_ok)  mask |= POLLIN  | POLLRDNORM; /* readable */
  if (this_board->write_ok) mask |= POLLOUT | POLLWRNORM; /* writable */

  if (this_board->debug_level & DEBUG_CALLS) {
    char status[3];
    char* ptr = status;
    if (mask & POLLRDNORM) *ptr++ = 'r';
    if (mask & POLLWRNORM) *ptr++ = 'w';
    if (ptr == status) *ptr++ = '-';
    *ptr = '\0';
    printk(KERN_INFO "%s_%d: poll return status is %s\n", DEV_NAME, this_board->board_number, status);
  }

  return mask;
}

/* seek is not supported */
static loff_t bluenoc_llseek(struct file* filp, loff_t off, int whence)
{
  return -ESPIPE; /* unseekable */
}

/*
 * driver IOCTL operations
 */

static long bluenoc_ioctl(struct file* filp, unsigned int cmd, unsigned long arg)
{
  tBoard* this_board = NULL;
  int err = 0;

  /* basic sanity checks */
  if (_IOC_TYPE(cmd) != BNOC_IOC_MAGIC)
    return -ENOTTY;
  if (_IOC_NR(cmd) > BNOC_IOC_MAXNR)
    return -ENOTTY;
  if (_IOC_DIR(cmd) & _IOC_READ)
    err = !access_ok(VERIFY_WRITE, (void __user *)arg, _IOC_SIZE(cmd));
  else if (_IOC_DIR(cmd) & _IOC_WRITE)
    err = !access_ok(VERIFY_READ, (void __user *)arg, _IOC_SIZE(cmd));
  if (err)
    return -EFAULT;

  /* access the tBoard structure for this file */
  this_board = (tBoard*) filp->private_data;

  /* execute the requested action */
  switch (cmd)
  {
    case BNOC_IDENTIFY:
    {
      /* copy board identification info to a user-space struct */
      tBoardInfo info;
      info.is_active      = (this_board->activation_level == BLUENOC_ACTIVE) ? 1 : 0;
      info.board_number   = this_board->board_number;
      info.major_rev      = this_board->major_rev;
      info.minor_rev      = this_board->minor_rev;
      info.build          = this_board->build;
      info.timestamp      = this_board->timestamp;
      info.bytes_per_beat = this_board->bytes_per_beat;
      info.content_id     = this_board->content_id;
      info.subvendor_id   = this_board->pci_dev->subsystem_vendor;
      info.subdevice_id   = this_board->pci_dev->subsystem_device;
      err = copy_to_user((void __user *)arg, &info, sizeof(tBoardInfo));
      if (err != 0)
        return -EFAULT;
      else
        return 0;
    }
    case BNOC_SOFT_RESET:
    {
      printk(KERN_INFO "%s: /dev/%s_%d soft reset\n", DEV_NAME, DEV_NAME, this_board->board_number);

      if (this_board->activation_level == BLUENOC_ACTIVE) {
        /* deactivate the network, wait 100ms and reactivate it */
        iowrite8(0,this_board->bar0io + 257);
        msleep(100);
        iowrite8(1,this_board->bar0io + 257);
      }

      return 0;
    }
    case BNOC_DEACTIVATE:
    {
      printk(KERN_INFO "%s: /dev/%s_%d deactivated\n", DEV_NAME, DEV_NAME, this_board->board_number);

      /* deactivate the whole PCI infrastructure for this board */
      deactivate(this_board);
      msleep(100);
      return 0;
    }
    case BNOC_REACTIVATE:
    {
      printk(KERN_INFO "%s: /dev/%s_%d reactivated\n", DEV_NAME, DEV_NAME, this_board->board_number);
      /* reactivate the PCI infrastructure for this board */
      activate(this_board);
      return 0;
    }
    case BNOC_GET_DEBUG_LEVEL:
    {
      /* copy the debug level to the user-space value */
      err = __put_user(this_board->debug_level, (tDebugLevel __user *)arg);
      if (err != 0)
        return -EFAULT;
      return 0;
    }
    case BNOC_SET_DEBUG_LEVEL:
    {
      /* set the debug level from the user-space value */
      tDebugLevel prev = this_board->debug_level;
      err = __get_user(this_board->debug_level, (tDebugLevel __user *)arg);
      if (err != 0)
        return -EFAULT;
      if (this_board->debug_level != prev) {
        tDebugLevel changed = this_board->debug_level ^ prev;
        if (changed & ~DEBUG_PROFILE) {
          if ((this_board->debug_level & ~DEBUG_PROFILE) == DEBUG_OFF) {
            printk(KERN_INFO "%s_%d: turned off debugging\n", DEV_NAME, this_board->board_number);
          } else {
            if (changed & DEBUG_CALLS) {
              printk(KERN_INFO "%s_%d: turned %s debugging function call sequence\n"
                    , DEV_NAME, this_board->board_number, (prev & DEBUG_CALLS) ? "off" : "on");
            }
            if (changed & DEBUG_DATA) {
              printk(KERN_INFO "%s_%d: turned %s debugging BlueNoC message data\n"
                    , DEV_NAME, this_board->board_number, (prev & DEBUG_DATA) ? "off" : "on");
            }
            if (changed & DEBUG_DMA) {
              printk(KERN_INFO "%s_%d: turned %s debugging DMA operations\n"
                    , DEV_NAME, this_board->board_number, (prev & DEBUG_DMA) ? "off" : "on");
            }
            if (changed & DEBUG_INTR) {
              printk(KERN_INFO "%s_%d: turned %s debugging interrupts\n"
                    , DEV_NAME, this_board->board_number, (prev & DEBUG_INTR) ? "off" : "on");
            }
          }
        }
        if (changed & DEBUG_PROFILE) {
          if (this_board->debug_level & DEBUG_PROFILE) {
            printk(KERN_INFO "%s_%d: turned on profiling BlueNoC driver\n", DEV_NAME, this_board->board_number);
            this_board->read_call_count        = 0llu;
            this_board->write_call_count       = 0llu;
            this_board->poll_call_count        = 0llu;
            this_board->total_bytes_read       = 0llu;
            this_board->total_bytes_written    = 0llu;
            this_board->total_read_call_ns     = 0llu;
            this_board->total_read_blocked_ns  = 0llu;
            this_board->total_write_call_ns    = 0llu;
            this_board->total_write_blocked_ns = 0llu;
            this_board->interrupt_count        = 0llu;
          } else {
            /* NOTE: The do_div macro is required to perform division
             * inside a kernel module. It NOT A FUNCTION and it
             * DOESN'T WORK THE WAY ITS NAME IMPLIES IT SHOULD!
             *
             * The first argument is EVALUATED MULTIPLE TIMES, so
             * beware of side effects in that expression. It is also
             * MODIFIED IN PLACE to contain the QUOTIENT after the
             * macro is executed. The return value of do_div is the
             * REMAINDER, not the quotient!
             */
            unsigned long long s;
            unsigned ns;
            printk(KERN_INFO "%s_%d: turned off profiling BlueNoC driver\n", DEV_NAME, this_board->board_number);
            printk(KERN_INFO "%s_%d:   poll_call_count          = %12llu calls\n",
                   DEV_NAME, this_board->board_number, this_board->poll_call_count);
            printk(KERN_INFO "%s_%d:   read_call_count          = %12llu calls\n",
                   DEV_NAME, this_board->board_number, this_board->read_call_count);
            printk(KERN_INFO "%s_%d:   total_bytes_read         = %12llu bytes\n",
                   DEV_NAME, this_board->board_number, this_board->total_bytes_read);
            s = this_board->total_read_call_ns;
            ns = do_div(s,1000000000);
            printk(KERN_INFO "%s_%d:   total_read_call_time     = %12llu seconds + %12u nanoseconds\n",
                   DEV_NAME, this_board->board_number, s, ns);
            s = this_board->total_read_blocked_ns;
            ns = do_div(s, 1000000000);
            printk(KERN_INFO "%s_%d:   total_read_blocked_time  = %12llu seconds + %12u nanoseconds\n",
                   DEV_NAME, this_board->board_number, s, ns);
            printk(KERN_INFO "%s_%d:   write_call_count         = %12llu calls\n",
                   DEV_NAME, this_board->board_number, this_board->write_call_count);
            printk(KERN_INFO "%s_%d:   total_bytes_written      = %12llu bytes\n",
                   DEV_NAME, this_board->board_number, this_board->total_bytes_written);
            s = this_board->total_write_call_ns;
            ns = do_div(s, 1000000000);
            printk(KERN_INFO "%s_%d:   total_write_call_time    = %12llu seconds + %12u nanoseconds\n",
                   DEV_NAME, this_board->board_number, s, ns);
            s = this_board->total_write_blocked_ns;
            ns = do_div(s, 1000000000);
            printk(KERN_INFO "%s_%d:   total_write_blocked_time = %12llu seconds + %12u nanoseconds\n",
                   DEV_NAME, this_board->board_number, s, ns);
            printk(KERN_INFO "%s_%d:   interrupt_count          = %12llu interrupts\n",
                   DEV_NAME, this_board->board_number, this_board->interrupt_count);
          }
        }
      }
      return 0;
    }
    case BNOC_GET_STATUS:
    {
      unsigned long status = ioread32(this_board->bar0io + 128);
      err = __put_user(status, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      return 0;
    }
    case BNOC_CLK_RD_WORD:
    {
      unsigned long data = ioread32(this_board->bar0io + 384);
      err = __put_user(data, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      return 0;
    }
    case BNOC_CLK_GET_STATUS:
    {
      unsigned long status = ioread32(this_board->bar0io + 388);
      err = __put_user(status, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      return 0;
    }
    case BNOC_CLK_CLR_WORD:
    {
      unsigned long data;
      err = __get_user(data, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      iowrite32(data, this_board->bar0io + 384);
      return 0;
    }
    case BNOC_CLK_SEND_CTRL:
    {
      unsigned long data;
      err = __get_user(data, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      iowrite32(data, this_board->bar0io + 392);
      return 0;
    }
    case BNOC_CAPABILITIES:
    {
      unsigned long data = ioread32(this_board->bar0io + 40);
      err = __put_user(data, (unsigned long __user *)arg);
      if (err != 0)
	return -EFAULT;
      return 0;
    }
    default:
      return -ENOTTY;
  }
}
