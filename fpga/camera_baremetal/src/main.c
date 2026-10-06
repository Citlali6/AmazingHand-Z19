#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xiicps.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "sleep.h"
#include "sensor_table.h"
#define W 1920U
#define H 1080U
#define SIZE (W*H*3U)
unsigned char frames[3][SIZE] __attribute__((aligned(4096)));
volatile unsigned int preview_request,preview_sequence,preview_status,board_frames;
volatile unsigned int debug_info[8];
volatile unsigned int focus_request=300, focus_applied=0xffffffffU, focus_result;
unsigned char preview_rgb[320*180*3] __attribute__((aligned(4096)));
static const UINTPTR dma_base[2]={0xa0060000U,0xa0070000U};
static XIicPs buses[2];
static volatile u32 events[2];
static void event_handler(void *ref,u32 event){*(volatile u32 *)ref |= event;}
static int transfer(unsigned cam,u8 *bytes,int size,int receive,int skip_busy) {
 unsigned i;
 for(i=0;i<10000;i++){if(skip_busy||!XIicPs_BusIsBusy(&buses[cam]))break;usleep(10);}
 if(i==10000)return -1;
 XIicPs_WriteReg(buses[cam].Config.BaseAddress,XIICPS_ISR_OFFSET,0xffff);
 int rc=receive?XIicPs_MasterRecvPolled(&buses[cam],bytes,size,0x10):XIicPs_MasterSendPolled(&buses[cam],bytes,size,0x10);
 if(rc!=XST_SUCCESS){printf("I2C transfer failed cam=%u rc=%d\r\n",cam,rc);XIicPs_Reset(&buses[cam]);return -1;}
 return 0;
}

static int reg_write(unsigned c,unsigned reg,unsigned val){
 u8 b[3]={reg>>8,reg,val};if(transfer(c,b,3,0,0))return -1;
 for(unsigned i=0;i<10000;i++){
  if(!XIicPs_BusIsBusy(&buses[c])){usleep(100);return 0;}usleep(10);
 }return -1;
}
static int reg_read(unsigned c,unsigned reg,u8 *v){
 u8 b[2]={reg>>8,reg};XIicPs_SetOptions(&buses[c],XIICPS_REP_START_OPTION);
 int rc=transfer(c,b,2,0,0);XIicPs_ClearOptions(&buses[c],XIICPS_REP_START_OPTION);
 if(rc)return -1;
 return transfer(c,v,1,1,1);
}
static int dma_prepare(unsigned c){
 UINTPTR d=dma_base[c];unsigned i;
 Xil_Out32(d+0x30,4);
 for(i=0;i<10000;i++){if(!(Xil_In32(d+0x30)&4))break;usleep(10);}
 if(i==10000)return -1;
 Xil_Out32(d+0x34,0xfff0);Xil_Out32(d+0x44,0);
 /* Three observed active circular frame stores, 64-bit address registers. */
 for(i=0;i<3;i++){u64 a=(UINTPTR)frames[i];Xil_Out32(d+0xac+8*i,(u32)a);Xil_Out32(d+0xb0+8*i,(u32)(a>>32));}
 Xil_Out32(d+0xa4,W*3);Xil_Out32(d+0xa8,W*3);
 /* Warm up continuously, SOF from stream TUSER (source=2). */
 Xil_Out32(d+0x30,0x00011043);Xil_Out32(d+0xa0,H);return 0;
}

int main(void){
 Xil_DCacheDisable();
 printf("\r\nZ19 continuous CAM0 capture / JTAG preview 320x180\r\n");
 Xil_Out32(0xa0080004U,0);Xil_Out32(0xa0080000U,0);usleep(20000);
 Xil_Out32(0xa0080000U,3);usleep(20000);
 XIicPs_Config *cfg=XIicPs_LookupConfig(0);u8 hi=0,lo=0;
 if(!cfg||XIicPs_CfgInitialize(&buses[0],cfg,cfg->BaseAddress)!=XST_SUCCESS){preview_status=1;goto failed;}
 XIicPs_SetStatusHandler(&buses[0],(void *)&events[0],event_handler);XIicPs_SetSClk(&buses[0],100000);
 if(reg_read(0,0x16,&hi)||reg_read(0,0x17,&lo)||hi!=2||lo!=0x14){preview_status=2;goto failed;}
 printf("CAM0 ID=%02x%02x\r\n",hi,lo);
 if(reg_write(0,0x0100,0)){preview_status=3;goto failed;}
 usleep(20000);
 Xil_Out32(0xa0040000U,3);
 if(dma_prepare(0)){preview_status=4;goto failed;}
 for(unsigned j=0;sensor_init_data[j].reg!=SEQUENCE_END;j++){
  unsigned reg=sensor_init_data[j].reg,val=sensor_init_data[j].val;
  if(reg==SEQUENCE_WAIT_MS){usleep(val*1000);continue;}
  if(reg_write(0,reg,val)){preview_status=5;goto failed;}
 }
 usleep(500000);Xil_Out32(dma_base[0]+0x34,0xfff0);
 printf("LIVE_CAPTURE_STARTED\r\n");
 while(1){
  unsigned st=Xil_In32(dma_base[0]+0x34);
  if(st&0xff0){preview_status=0x10000|(st&0xff0);Xil_Out32(dma_base[0]+0x34,st&0xfff0);}
  if(st&0x1000){board_frames++;Xil_Out32(dma_base[0]+0x34,0x1000);preview_status=0;}
  if(focus_request!=focus_applied){
   unsigned pos=focus_request;
   if(pos>1023){focus_result=2;}else{
    u8 b[2]={(pos>>4)&0xff,(pos&15)<<4};
    unsigned n;for(n=0;n<10000 && XIicPs_BusIsBusy(&buses[0]);n++)usleep(10);
    focus_result=(n==10000 || XIicPs_MasterSendPolled(&buses[0],b,2,0x0c)!=XST_SUCCESS)?1:0;
    if(focus_result)XIicPs_Reset(&buses[0]);
   }
   focus_applied=pos;printf("FOCUS position=%u result=%u\r\n",pos,focus_result);
  }
  unsigned request=preview_request;
  if(request==0xffffffffU){
   Xil_Out32(dma_base[0]+0x30,Xil_In32(dma_base[0]+0x30)&~1U);
   reg_write(0,0x0100,0);preview_status=0x20000;
   printf("LIVE_CAPTURE_STOPPED\r\n");while(1)usleep(100000);
  }
  if(request!=preview_sequence && board_frames){
   unsigned current=(Xil_In32(dma_base[0]+0x28)>>24)&31;
   if(current>=3){preview_status=6;continue;}
   unsigned done=(current+2)%3;
   debug_info[0]=current;debug_info[1]=done;
   for(unsigned i=0;i<3;i++){
    unsigned sum=0;for(unsigned q=0;q<60;q++)sum+=frames[i][((q*7919U)%(W*H))*3];
    debug_info[2+i]=sum;
   }
   for(unsigned y=0;y<180;y++)for(unsigned x=0;x<320;x++){
    unsigned src=(y*6*W+x*6)*3,dst=(y*320+x)*3;
    preview_rgb[dst]=frames[done][src];preview_rgb[dst+1]=frames[done][src+1];preview_rgb[dst+2]=frames[done][src+2];
   }
   __asm__ volatile("dsb sy" ::: "memory");
   preview_sequence=request;
  }
  usleep(1000);
 }
 failed:
 printf("LIVE_INIT_FAILED status=%u\r\n",preview_status);
 while(1)usleep(100000);
}
