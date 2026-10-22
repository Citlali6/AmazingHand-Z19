/* Z19 PS transport only: UVC MJPEG decode, native32 PIO, JPEG encode.
 * HSV, threshold decisions, pixel highlighting and statistics execute in PL.
 * No motors, audio, PC inference, or boot-storage writes. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <jpeglib.h>
#include <pthread.h>
#ifndef __aarch64__
#error "Build on the Z19 AArch64 board"
#endif
static volatile sig_atomic_t stopping;
static volatile uint32_t *regs;
static void die(const char *s){perror(s);exit(2);}
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
static void stop(int sig){(void)sig;stopping=1;}
static uint32_t rd(unsigned off){__asm__ volatile("dmb sy":::"memory");uint32_t v=regs[off/4];__asm__ volatile("dsb sy":::"memory");return v;}
static void wr(unsigned off,uint32_t v){__asm__ volatile("dmb sy":::"memory");regs[off/4]=v;__asm__ volatile("dsb sy":::"memory");}
static void wait_flag(unsigned bit,double deadline){
 for(unsigned loops=0;;loops++){
  uint32_t s=rd(0x18);
  if(s&4){fprintf(stderr,"PL_ERROR status=%08x in=%u out=%u\n",s,rd(0x1c),rd(0x28));exit(3);}
  if(s&bit)return;
  if(stopping||(!(loops&1023)&&now()>deadline)){fprintf(stderr,"PL_TIMEOUT\n");exit(3);}
 }
}
static int pl_frame(const uint8_t *src,uint8_t *dst,unsigned width,unsigned height,unsigned color,unsigned saturation,unsigned value,uint32_t sequence){
 unsigned total=width*height;double deadline=now()+60;
 wr(8,1);wr(0x10,width);wr(0x14,height);wr(0x0c,color|(saturation<<8)|(value<<16));wr(0x40,sequence);
 // One empty-to-empty batch fits the reviewed 16-credit FIFO. Native32 stores
 // finish before the next operation; the AXI bridge accepts writes >=3 cycles
 // apart and reads >=2 cycles apart. With >=8 writes the six-stage core cannot
 // be overtaken by the following reads. Small tails retain per-pixel polling.
 for(unsigned first=0;first<total;first+=16){
  if(stopping)return 1;
  unsigned count=total-first<16?total-first:16;
  wait_flag(1,deadline);
  for(unsigned j=0;j<count;j++){
   unsigned n=first+j;
   wr(0x20,((uint32_t)src[3*n]<<16)|((uint32_t)src[3*n+1]<<8)|src[3*n+2]);
  }
  wait_flag(2,deadline);
  for(unsigned j=0;j<count;j++){
   unsigned n=first+j;if(count<8)wait_flag(2,deadline);uint32_t p=rd(0x24);
   dst[3*n]=(p>>16)&255;dst[3*n+1]=(p>>8)&255;dst[3*n+2]=p&255;
  }
 }
 if((rd(0x18)&12)!=8||rd(0x1c)!=total||rd(0x28)!=total||rd(0x40)!=sequence){fprintf(stderr,"PL_FRAME_MISMATCH\n");exit(3);}
 return 0;
}
static void selftest(void){
 uint8_t input[48],output[48];
 for(unsigned i=0;i<16;i++){input[i*3]=(i%4==0||i%4==3)?255:0;input[i*3+1]=(i%4==1||i%4==3)?255:0;input[i*3+2]=(i%4==2||i%4==3)?255:0;}
 for(unsigned color=0;color<4;color++){
  pl_frame(input,output,8,2,color,100,80,100+color);
  for(unsigned i=0;i<16;i++)for(unsigned ch=0;ch<3;ch++){
   unsigned expected=(color==0||i%4==color-1)?input[3*i+ch]:input[3*i+ch]/4;
   if(output[3*i+ch]!=expected){fprintf(stderr,"SELFTEST_PIXEL_FAIL\n");exit(4);}
  }
  unsigned count=rd(0x2c);
  if(count!=(color==0?0:4)){fprintf(stderr,"SELFTEST_COUNT_FAIL %u\n",count);exit(4);}
  printf("{\"selftest_color\":%u,\"count\":%u,\"bbox\":[%u,%u,%u,%u],\"sequence\":%u}\n",color,count,rd(0x30),rd(0x38),rd(0x34),rd(0x3c),rd(0x40));
 }
 wr(8,1);puts("COLOR_BOARD_SELFTEST_PASS");
}
static void benchmark(void){
 const unsigned widths[]={1280,640},heights[]={720,480};
 for(unsigned mode=0;mode<2;mode++){
  unsigned w=widths[mode],h=heights[mode],n=w*h;
  uint8_t *a=malloc(n*3),*b=malloc(n*3);if(!a||!b)die("benchmark malloc");
  for(unsigned i=0;i<n;i++){a[i*3]=(i%4==0||i%4==3)?255:0;a[i*3+1]=(i%4==1||i%4==3)?255:0;a[i*3+2]=(i%4==2||i%4==3)?255:0;}
  for(unsigned c=0;c<4;c++){
   double t=now();if(pl_frame(a,b,w,h,c,100,80,200+c))exit(4);double ms=(now()-t)*1000;
   for(unsigned i=0;i<n;i++)for(unsigned ch=0;ch<3;ch++){
    unsigned expected=(c==0||i%4==c-1)?a[3*i+ch]:a[3*i+ch]/4;
    if(b[3*i+ch]!=expected){fprintf(stderr,"BULK_PIXEL_FAIL at %u\n",i);exit(4);}
   }
   if(rd(0x2c)!=(c?n/4:0)){fprintf(stderr,"BULK_COUNT_FAIL\n");exit(4);}
   printf("BULK_PASS %ux%u color=%u pixels=%u ms=%.3f\n",w,h,c,n,ms);
  }
  free(a);free(b);
 }
 wr(8,1);puts("COLOR_BULK_BENCHMARK_PASS");
}
struct jpeg_err{struct jpeg_error_mgr base;jmp_buf jump;};
static void jpeg_fail(j_common_ptr codec){struct jpeg_err *e=(struct jpeg_err*)codec->err;(*codec->err->output_message)(codec);longjmp(e->jump,1);}
static int decode(const uint8_t *data,size_t bytes,uint8_t *rgb,unsigned width,unsigned height){
 struct jpeg_decompress_struct c;struct jpeg_err e;c.err=jpeg_std_error(&e.base);e.base.error_exit=jpeg_fail;
 if(setjmp(e.jump)){jpeg_destroy_decompress(&c);return -1;}
 jpeg_create_decompress(&c);jpeg_mem_src(&c,data,bytes);jpeg_read_header(&c,TRUE);c.out_color_space=JCS_RGB;
 jpeg_start_decompress(&c);
 if(c.output_width!=width||c.output_height!=height||c.output_components!=3){jpeg_destroy_decompress(&c);return -1;}
 while(c.output_scanline<c.output_height){JSAMPROW row=rgb+c.output_scanline*width*3;jpeg_read_scanlines(&c,&row,1);}
 jpeg_finish_decompress(&c);jpeg_destroy_decompress(&c);return 0;
}
static void encode(const char *path,const uint8_t *rgb,unsigned width,unsigned height){
 FILE *f=fopen(path,"wb");if(!f)die("JPEG file");
 struct jpeg_compress_struct c;struct jpeg_error_mgr e;c.err=jpeg_std_error(&e);jpeg_create_compress(&c);jpeg_stdio_dest(&c,f);
 c.image_width=width;c.image_height=height;c.input_components=3;c.in_color_space=JCS_RGB;
 jpeg_set_defaults(&c);jpeg_set_quality(&c,85,TRUE);jpeg_start_compress(&c,TRUE);
 while(c.next_scanline<c.image_height){JSAMPROW row=(JSAMPROW)(rgb+c.next_scanline*width*3);jpeg_write_scanlines(&c,&row,1);}
 jpeg_finish_compress(&c);jpeg_destroy_compress(&c);fclose(f);
}
static int xioctl(int fd,unsigned long req,void *arg){int v;do{v=ioctl(fd,req,arg);}while(v<0&&errno==EINTR&&!stopping);return v;}
static void save_bytes(const char *path,const void *data,size_t bytes){FILE*f=fopen(path,"wb");if(!f)die("save");if(fwrite(data,1,bytes,f)!=bytes)die("write");fclose(f);}
struct capture_latest {
 int fd,failed;unsigned buffer_count,generation;void **buffers;size_t *lengths;
 uint8_t *jpeg;size_t capacity,bytes;uint32_t sequence;double captured;
 pthread_mutex_t mutex;pthread_cond_t changed;
};
static void *capture_worker(void *arg){
 struct capture_latest *s=arg;
 while(!stopping){
  fd_set fds;FD_ZERO(&fds);FD_SET(s->fd,&fds);struct timeval wait={0,100000};
  int ready=select(s->fd+1,&fds,NULL,NULL,&wait);
  if(ready<0&&errno==EINTR)continue;
  if(ready<0)break;
  if(!ready)continue;
  struct v4l2_buffer b={.type=V4L2_BUF_TYPE_VIDEO_CAPTURE,.memory=V4L2_MEMORY_MMAP};
  if(xioctl(s->fd,VIDIOC_DQBUF,&b)){if(errno==EAGAIN)continue;break;}
  if(b.index>=s->buffer_count||b.bytesused<4||b.bytesused>s->lengths[b.index]||b.bytesused>s->capacity)break;
  double stamp=now();
  if((b.flags&V4L2_BUF_FLAG_TIMESTAMP_MASK)==V4L2_BUF_FLAG_TIMESTAMP_MONOTONIC){
   double camera_stamp=b.timestamp.tv_sec+b.timestamp.tv_usec/1e6;
   if(camera_stamp>0&&camera_stamp<=stamp&&stamp-camera_stamp<60)stamp=camera_stamp;
  }
  pthread_mutex_lock(&s->mutex);
  memcpy(s->jpeg,s->buffers[b.index],b.bytesused);s->bytes=b.bytesused;
  s->sequence=b.sequence;s->captured=stamp;s->generation++;
  pthread_cond_signal(&s->changed);pthread_mutex_unlock(&s->mutex);
  if(xioctl(s->fd,VIDIOC_QBUF,&b))break;
 }
 pthread_mutex_lock(&s->mutex);s->failed=1;pthread_cond_signal(&s->changed);pthread_mutex_unlock(&s->mutex);
 return NULL;
}
int main(int argc,char **argv){
 setbuf(stdout,NULL);signal(SIGTERM,stop);signal(SIGINT,stop);
 if(argc!=2&&argc!=6){fprintf(stderr,"usage: color_camera --selftest | DEVICE WIDTH HEIGHT OUTPUT_DIR MAX_FRAMES\n");return 1;}
 if(access("/run/visiongrasp-color-20261022.loaded",R_OK)){fprintf(stderr,"Load/verify the reviewed color bitstream first\n");return 2;}
 int lockfd=open("/run/visiongrasp-color.lock",O_CREAT|O_RDWR,0600);if(lockfd<0||flock(lockfd,LOCK_EX|LOCK_NB))die("exclusive PL owner");
 int mem=open("/dev/mem",O_RDWR|O_SYNC);if(mem<0)die("devmem");
 regs=mmap(NULL,4096,PROT_READ|PROT_WRITE,MAP_SHARED,mem,0xa0000000UL);if(regs==MAP_FAILED)die("mmap");
 if(rd(0)!=0x31524c43||rd(4)!=0x00010001){fprintf(stderr,"WRONG_PL_PROFILE\n");return 3;}
 if(argc==2){if(!strcmp(argv[1],"--selftest"))selftest();else if(!strcmp(argv[1],"--benchmark"))benchmark();else return 1;return 0;}
 unsigned width=(unsigned)strtoul(argv[2],NULL,10),height=(unsigned)strtoul(argv[3],NULL,10),limit=(unsigned)strtoul(argv[5],NULL,10);
 const char *dir=argv[4];if(!width||width>1280||!height||height>720||!limit||strlen(dir)>1800)return 1;
 int cam=open(argv[1],O_RDWR|O_NONBLOCK);if(cam<0)die("camera");
 struct v4l2_capability cap={0};if(xioctl(cam,VIDIOC_QUERYCAP,&cap))die("QUERYCAP");
 if(!(cap.device_caps&V4L2_CAP_VIDEO_CAPTURE)||!(cap.device_caps&V4L2_CAP_STREAMING)){fprintf(stderr,"Not a capture node\n");return 5;}
 struct v4l2_format fmt={.type=V4L2_BUF_TYPE_VIDEO_CAPTURE};fmt.fmt.pix.width=width;fmt.fmt.pix.height=height;fmt.fmt.pix.pixelformat=V4L2_PIX_FMT_MJPEG;fmt.fmt.pix.field=V4L2_FIELD_ANY;
 if(xioctl(cam,VIDIOC_S_FMT,&fmt))die("S_FMT");
 if(fmt.fmt.pix.width!=width||fmt.fmt.pix.height!=height||fmt.fmt.pix.pixelformat!=V4L2_PIX_FMT_MJPEG){fprintf(stderr,"FORMAT_MISMATCH\n");return 5;}
 struct v4l2_streamparm fps={.type=V4L2_BUF_TYPE_VIDEO_CAPTURE};fps.parm.capture.timeperframe.numerator=1;fps.parm.capture.timeperframe.denominator=30;
 if(xioctl(cam,VIDIOC_S_PARM,&fps))die("S_PARM");
 struct v4l2_requestbuffers req={.count=4,.type=V4L2_BUF_TYPE_VIDEO_CAPTURE,.memory=V4L2_MEMORY_MMAP};
 if(xioctl(cam,VIDIOC_REQBUFS,&req)||req.count<2||req.count>8)die("REQBUFS");
 void *buffers[8];size_t lengths[8];
 for(unsigned i=0;i<req.count;i++){
  struct v4l2_buffer b={.type=req.type,.memory=req.memory,.index=i};if(xioctl(cam,VIDIOC_QUERYBUF,&b))die("QUERYBUF");
  lengths[i]=b.length;buffers[i]=mmap(NULL,b.length,PROT_READ|PROT_WRITE,MAP_SHARED,cam,b.m.offset);if(buffers[i]==MAP_FAILED)die("camera mmap");
  if(xioctl(cam,VIDIOC_QBUF,&b))die("QBUF");
 }
 enum v4l2_buf_type type=V4L2_BUF_TYPE_VIDEO_CAPTURE;if(xioctl(cam,VIDIOC_STREAMON,&type))die("STREAMON");
 uint8_t *rgb=malloc(width*height*3),*processed=malloc(width*height*3);if(!rgb||!processed)die("malloc");
 size_t jpeg_capacity=0;for(unsigned i=0;i<req.count;i++)if(lengths[i]>jpeg_capacity)jpeg_capacity=lengths[i];
 struct capture_latest latest={.fd=cam,.buffer_count=req.count,.buffers=buffers,.lengths=lengths,.capacity=jpeg_capacity,.mutex=PTHREAD_MUTEX_INITIALIZER,.changed=PTHREAD_COND_INITIALIZER};
 latest.jpeg=malloc(jpeg_capacity);uint8_t *frame_jpeg=malloc(jpeg_capacity);if(!latest.jpeg||!frame_jpeg)die("capture malloc");
 pthread_t capture_thread;int thread_error=pthread_create(&capture_thread,NULL,capture_worker,&latest);
 if(thread_error){errno=thread_error;die("capture thread");}
 unsigned generation=0;double previous_publish=0;
 unsigned published=0;char path[2048],status_path[2048],control[2048];snprintf(control,sizeof control,"%s/control.txt",dir);
 while(!stopping&&published<limit){
  pthread_mutex_lock(&latest.mutex);
  struct timespec wake;clock_gettime(CLOCK_REALTIME,&wake);wake.tv_sec+=3;
  int wait_error=0;
  while(!stopping&&!latest.failed&&generation==latest.generation&&!wait_error)wait_error=pthread_cond_timedwait(&latest.changed,&latest.mutex,&wake);
  if(stopping||latest.failed||generation==latest.generation){pthread_mutex_unlock(&latest.mutex);fprintf(stderr,"CAPTURE_STOP_OR_TIMEOUT\n");break;}
  const uint32_t capture_sequence=latest.sequence;double capture_stamp=latest.captured;
  size_t jpeg_bytes=latest.bytes;generation=latest.generation;memcpy(frame_jpeg,latest.jpeg,jpeg_bytes);
  pthread_mutex_unlock(&latest.mutex);
  double work_start=now();
  unsigned frame=published+1,color=0,saturation=100,value=80;
  unsigned long long request_id=0;double requested_at=0;FILE *cf=fopen(control,"r");
  if(cf){unsigned c,s,v;unsigned long long id=0;double stamp=0;
   int fields=fscanf(cf,"%u %u %u %llu %lf",&c,&s,&v,&id,&stamp);
   if(fields>=3&&c<=3&&s<=255&&v<=255){color=c;saturation=s;value=v;if(fields==5&&stamp>=0){request_id=id;requested_at=stamp;}}
   fclose(cf);
  }
  // A new command must use a capture made after the request, not an old frame.
  if(capture_stamp<requested_at)continue;
  if(decode(frame_jpeg,jpeg_bytes,rgb,width,height)){fprintf(stderr,"BAD_MJPEG\n");break;}
  double decode_ms=(now()-work_start)*1000;
  snprintf(path,sizeof path,"%s/frame-%u-source.jpg",dir,frame);save_bytes(path,frame_jpeg,jpeg_bytes);
  double begin=now();if(pl_frame(rgb,processed,width,height,color,saturation,value,capture_sequence))break;double elapsed=now()-begin;
  double encode_start=now();
  snprintf(path,sizeof path,"%s/frame-%u-pl.jpg",dir,frame);encode(path,processed,width,height);
  double published_at=now(),encode_ms=(published_at-encode_start)*1000;
  double display_fps=previous_publish>0?1/(published_at-previous_publish):0;previous_publish=published_at;
  snprintf(path,sizeof path,"%s/status.tmp",dir);FILE *status=fopen(path,"w");if(!status)die("status");
  fprintf(status,"{\"source\":\"Z19_USB_TO_REAL_PL\",\"frame\":%u,\"capture_sequence\":%u,\"pl_sequence\":%u,\"width\":%u,\"height\":%u,\"color\":%u,\"min_s\":%u,\"min_v\":%u,\"mask_count\":%u,\"bbox\":[%u,%u,%u,%u],\"pl_processing_ms\":%.3f,\"published_monotonic\":%.6f,\"decode_ms\":%.3f,\"encode_ms\":%.3f,\"capture_to_publish_ms\":%.3f,\"fps\":%.3f,\"request_id\":%llu,\"captured_monotonic\":%.9f}\n",frame,capture_sequence,rd(0x40),width,height,color,saturation,value,rd(0x2c),rd(0x30),rd(0x38),rd(0x34),rd(0x3c),elapsed*1000,published_at,decode_ms,encode_ms,(published_at-capture_stamp)*1000,display_fps,request_id,capture_stamp);
  fclose(status);snprintf(status_path,sizeof status_path,"%s/status.json",dir);if(rename(path,status_path))die("status publish");
  printf("FRAME %u CAPTURE %u COLOR %u PL_MATCH %u PL_MS %.1f\n",frame,capture_sequence,color,rd(0x2c),elapsed*1000);published=frame;
  if(frame>4){snprintf(path,sizeof path,"%s/frame-%u-source.jpg",dir,frame-4);unlink(path);snprintf(path,sizeof path,"%s/frame-%u-pl.jpg",dir,frame-4);unlink(path);}
 }
 stopping=1;pthread_join(capture_thread,NULL);free(latest.jpeg);free(frame_jpeg);
 xioctl(cam,VIDIOC_STREAMOFF,&type);wr(8,1);for(unsigned i=0;i<req.count;i++)munmap(buffers[i],lengths[i]);
 close(cam);free(rgb);free(processed);munmap((void*)regs,4096);close(mem);close(lockfd);
 printf("STOPPED published=%u\n",published);return published?0:6;
}
