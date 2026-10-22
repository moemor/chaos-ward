/* Linux-Test für setup.c: Windows-Funktionen auf POSIX abgebildet */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
typedef unsigned short WCHAR; typedef unsigned int DWORD; typedef int BOOL; typedef void *HANDLE; typedef long long I64; typedef unsigned long long U64;
static char *u8(const WCHAR *w) { static char b[4][2048]; static int k; char *o = b[k++ & 3]; int i = 0; for (; *w; w++) o[i++] = *w == '\\' ? '/' : (char)*w; o[i] = 0; return o; }
static void w16(WCHAR *d, const char *s) { while (*s) *d++ = (WCHAR)(*s == '/' ? '\\' : *s), s++; *d = 0; }
DWORD GetModuleFileNameW(HANDLE m, WCHAR *b, DWORD n) { w16(b, getenv("SELF")); return 1; }
HANDLE CreateFileW(const WCHAR *p, DWORD a, DWORD s, void *x, DWORD disp, DWORD f, HANDLE t) { FILE *fp = fopen(u8(p), disp == 3 ? "rb" : "wb"); return fp ? (HANDLE)fp : (HANDLE)(I64)-1; }
BOOL ReadFile(HANDLE h, void *b, DWORD n, DWORD *got, void *o) { *got = fread(b, 1, n, h); return 1; }
BOOL WriteFile(HANDLE h, const void *b, DWORD n, DWORD *w, void *o) { *w = fwrite(b, 1, n, h); return 1; }
BOOL CloseHandle(HANDLE h) { if (h) fclose(h); return 1; }
BOOL SetFilePointerEx(HANDLE h, I64 d, I64 *n, DWORD m) { return fseeko(h, d, SEEK_SET) == 0; }
BOOL GetFileSizeEx(HANDLE h, I64 *s) { fseeko(h, 0, SEEK_END); *s = ftello(h); return 1; }
BOOL CreateDirectoryW(const WCHAR *p, void *x) { mkdir(u8(p), 0755); return 1; }
DWORD GetTempPathW(DWORD n, WCHAR *b) { w16(b, getenv("TMPOUT")); return 1; }
DWORD GetTickCount(void) { return 4242; }
void *VirtualAlloc(void *a, U64 n, DWORD t, DWORD p) { return malloc(n); }
void ExitProcess(unsigned c) { exit(c); }
int MessageBoxW(HANDLE h, const WCHAR *m, const WCHAR *t, unsigned f) { printf("MSGBOX: %s\n", u8(m)); return 1; }
typedef struct { DWORD cb; WCHAR *r, *desk, *title; DWORD x, y, xs, ys, xc, yc, fill, flags; unsigned short sw, cb2; void *r2; HANDLE i, o, e; } STARTUPINFOW;
typedef struct { HANDLE hp, ht; DWORD pid, tid; } PROCINFO;
BOOL CreateProcessW(const WCHAR *a, WCHAR *c, void *p, void *t, BOOL i, DWORD f, void *e, const WCHAR *d, STARTUPINFOW *s, PROCINFO *pi) { printf("RUN: %s | cmd: %s | cwd: %s\n", u8(a), u8(c), u8(d)); pi->hp = pi->ht = 0; return 1; }
int setup_main(void);
int main(void) { return setup_main(); }
