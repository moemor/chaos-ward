#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
typedef unsigned int (__attribute__((ms_abi)) *fn_t)(unsigned int*, unsigned int, unsigned int, unsigned int, unsigned int);
int main(){
  FILE*f=fopen("maxchan.bin","rb"); unsigned char buf[4096]; size_t n=fread(buf,1,sizeof buf,f); fclose(f);
  void*mem=mmap(0,4096,PROT_READ|PROT_WRITE|PROT_EXEC,MAP_PRIVATE|MAP_ANONYMOUS,-1,0); memcpy(mem,buf,n);
  fn_t fn=(fn_t)mem; srand(7); int bad=0;
  for(int t=0;t<200;t++){
    unsigned w=1+rand()%37, h=1+rand()%23, pad=rand()%3, stride=(w+pad)*4, thr=rand()%256;
    unsigned *a=malloc(stride*h), *ref=malloc(stride*h);
    for(unsigned i=0;i<stride/4*h;i++) a[i]=ref[i]=(unsigned)rand()^((unsigned)rand()<<16);
    for(unsigned y=0;y<h;y++) for(unsigned x=0;x<w;x++){unsigned p=ref[y*(stride/4)+x],r=p>>16&255,g=p>>8&255,b=p&255,v=r>g?r:g; v=v>b?v:b; ref[y*(stride/4)+x]=v>thr?0xFFFFFFFF:0xFF000000;}
    unsigned rv=fn(a,w,h,stride,thr);
    if(rv!=0||memcmp(a,ref,stride*h)) bad++;
    free(a);free(ref);
  }
  printf("Tests: 200, Fehler: %d\n",bad); return bad;
}
