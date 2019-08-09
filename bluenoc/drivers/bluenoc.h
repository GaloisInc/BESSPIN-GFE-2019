#ifndef __BLUENOC_H__
#define __BLUENOC_H__

#include <linux/ioctl.h>

/*
 * IOCTLs
 */

/* magic number for IOCTLs */
#define BNOC_IOC_MAGIC 0xB5

/* Structures used with IOCTLs */

typedef struct {
  unsigned int       board_number;
  unsigned int       is_active;
  unsigned int       major_rev;
  unsigned int       minor_rev;
  unsigned int       build;
  unsigned int       timestamp;
  unsigned int       bytes_per_beat;
  unsigned long long content_id;
  unsigned int       subvendor_id;
  unsigned int       subdevice_id;
} tBoardInfo;

typedef unsigned int tDebugLevel;

const tDebugLevel DEBUG_OFF     =        0;
const tDebugLevel DEBUG_CALLS   = (1 <<  0);
const tDebugLevel DEBUG_DATA    = (1 <<  1);
const tDebugLevel DEBUG_DMA     = (1 <<  2);
const tDebugLevel DEBUG_INTR    = (1 <<  3);
const tDebugLevel DEBUG_PROFILE = (1 << 31);

/* IOCTL code definitions */

#define BNOC_IDENTIFY        _IOR(BNOC_IOC_MAGIC,0,tBoardInfo*)
#define BNOC_SOFT_RESET      _IO(BNOC_IOC_MAGIC,1)
#define BNOC_DEACTIVATE      _IO(BNOC_IOC_MAGIC,2)
#define BNOC_REACTIVATE      _IO(BNOC_IOC_MAGIC,3)
#define BNOC_GET_DEBUG_LEVEL _IOR(BNOC_IOC_MAGIC,4,tDebugLevel*)
#define BNOC_SET_DEBUG_LEVEL _IOW(BNOC_IOC_MAGIC,5,tDebugLevel*)
#define BNOC_GET_STATUS      _IOR(BNOC_IOC_MAGIC,6,unsigned long*)
#define BNOC_CLK_RD_WORD     _IOR(BNOC_IOC_MAGIC,7,unsigned long*)
#define BNOC_CLK_GET_STATUS  _IOR(BNOC_IOC_MAGIC,8,unsigned long*)
#define BNOC_CLK_CLR_WORD    _IOW(BNOC_IOC_MAGIC,9,unsigned long*)
#define BNOC_CLK_SEND_CTRL   _IOW(BNOC_IOC_MAGIC,10,unsigned long*)
#define BNOC_CAPABILITIES    _IOR(BNOC_IOC_MAGIC,11,unsigned long*)

/* maximum valid IOCTL number */
#define BNOC_IOC_MAXNR 11

#endif /* __BLUENOC_H__ */
