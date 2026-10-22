/* Chaos Ward Setup: kleines Windows-Programm ohne Laufzeitbibliothek.
   Hinten an diese .exe ist das Programm angehängt (eigenes, einfaches Format, siehe pack.py).
   Ablauf: Dateien in einen Temp-Ordner entpacken -> "ChaosWard.exe /setup" starten.
   Das eigentliche Einrichten (Kopieren, Verknüpfungen, Update, Eintrag in "Apps") macht Chaos Ward selbst. */
typedef unsigned short WCHAR;
typedef unsigned int DWORD;
typedef int BOOL;
typedef void *HANDLE;
typedef unsigned long long U64;
typedef long long I64;
#ifdef TEST
#define API
#else
#define API __declspec(dllimport) __stdcall
#endif
API DWORD GetModuleFileNameW(HANDLE, WCHAR *, DWORD);
API HANDLE CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
API BOOL ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
API BOOL WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
API BOOL CloseHandle(HANDLE);
API BOOL SetFilePointerEx(HANDLE, I64, I64 *, DWORD);
API BOOL GetFileSizeEx(HANDLE, I64 *);
API BOOL CreateDirectoryW(const WCHAR *, void *);
API DWORD GetTempPathW(DWORD, WCHAR *);
API DWORD GetTickCount(void);
API void *VirtualAlloc(void *, U64, DWORD, DWORD);
API void ExitProcess(unsigned);
API int MessageBoxW(HANDLE, const WCHAR *, const WCHAR *, unsigned);
typedef struct { DWORD cb; WCHAR *r, *desk, *title; DWORD x, y, xs, ys, xc, yc, fill, flags; unsigned short sw, cb2; void *r2; HANDLE i, o, e; } STARTUPINFOW;
typedef struct { HANDLE hp, ht; DWORD pid, tid; } PROCINFO;
API BOOL CreateProcessW(const WCHAR *, WCHAR *, void *, void *, BOOL, DWORD, void *, const WCHAR *, STARTUPINFOW *, PROCINFO *);

#define GENERIC_READ 0x80000000u
#define GENERIC_WRITE 0x40000000u
#define INVALID ((HANDLE)(I64)-1)
#define CHUNK (1u << 20)

static void zero(void *p, U64 n) { volatile unsigned char *b = p; while (n--) *b++ = 0; }
static int wlen(const WCHAR *s) { int n = 0; while (s[n]) n++; return n; }
static WCHAR *wcat(WCHAR *d, const WCHAR *s) { while (*d) d++; while ((*d++ = *s++)) {} return d - 1; }
static void wnum(WCHAR *d, DWORD v) { WCHAR t[12]; int n = 0; do { t[n++] = (WCHAR)('0' + v % 10); v /= 10; } while (v); while (*d) d++; while (n) *d++ = t[--n]; *d = 0; }
#define W(s) ((const WCHAR *)u##s)

static void fail(const WCHAR *what) {
  static WCHAR msg[1800]; msg[0] = 0;
  wcat(msg, W("Chaos Ward konnte nicht eingerichtet werden / Setup failed:\n\n"));
  wcat(msg, what);
  MessageBoxW(0, msg, W("Chaos Ward Setup"), 0x10);
  ExitProcess(1);
}

static BOOL readAll(HANDLE h, void *buf, DWORD n) {
  DWORD got;
  unsigned char *p = buf;
  while (n) { if (!ReadFile(h, p, n, &got, 0) || !got) return 0; p += got; n -= got; }
  return 1;
}

/* Ordner für eine Datei anlegen (alle Ebenen) */
static void mkdirs(WCHAR *path) {
  for (int i = 3; path[i]; i++)
    if (path[i] == '\\') { WCHAR c = path[i]; path[i] = 0; CreateDirectoryW(path, 0); path[i] = c; }
}

#ifdef TEST
int setup_main(void)
#else
void start(void)
#endif
{
  static WCHAR self[1024], dir[600], path[1200], cmd[1400];   /* statisch: kein großer Stack ohne Stack-Proben */
  if (!GetModuleFileNameW(0, self, 1024)) fail(W("GetModuleFileName"));
  HANDLE h = CreateFileW(self, GENERIC_READ, 1, 0, 3, 0, 0);
  if (h == INVALID) fail(W("Setup-Datei nicht lesbar"));
  I64 size = 0;
  GetFileSizeEx(h, &size);
  unsigned char tail[16];
  if (size < 64 || !SetFilePointerEx(h, size - 16, 0, 0) || !readAll(h, tail, 16)) fail(W("Setup-Datei beschädigt (Ende)"));
  const char *magic = "CWSETUP1";
  for (int i = 0; i < 8; i++) if (tail[i] != (unsigned char)magic[i]) fail(W("Setup-Datei unvollständig - bitte neu herunterladen"));
  I64 off = 0;
  for (int i = 7; i >= 0; i--) off = (off << 8) | tail[8 + i];
  if (off <= 0 || off >= size - 16 || !SetFilePointerEx(h, off, 0, 0)) fail(W("Setup-Datei beschädigt (Anfang)"));

  dir[0] = 0;
  if (!GetTempPathW(500, dir)) fail(W("Temp-Ordner"));
  wcat(dir, W("ChaosWardSetup-"));
  wnum(dir, GetTickCount());
  wcat(dir, W("\\"));
  CreateDirectoryW(dir, 0);

  unsigned char *buf = VirtualAlloc(0, CHUNK, 0x3000, 4);
  if (!buf) fail(W("Speicher"));
  int files = 0;
  for (;;) {
    unsigned char hd[4];
    if (!readAll(h, hd, 4)) fail(W("Setup-Datei beschädigt (Kopf)"));
    DWORD nlen = hd[0] | hd[1] << 8 | hd[2] << 16 | (DWORD)hd[3] << 24;   /* Name in Bytes (UTF-16) */
    if (nlen == 0) break;
    if (nlen > 1000) fail(W("Setup-Datei beschädigt (Name)"));
    path[0] = 0;
    WCHAR *e = wcat(path, dir);
    if (!readAll(h, e, nlen)) fail(W("Setup-Datei beschädigt (Name)"));
    e[nlen / 2] = 0;
    unsigned char sz[8];
    if (!readAll(h, sz, 8)) fail(W("Setup-Datei beschädigt (Größe)"));
    U64 n = 0;
    for (int i = 7; i >= 0; i--) n = (n << 8) | sz[i];
    mkdirs(path);
    HANDLE o = CreateFileW(path, GENERIC_WRITE, 0, 0, 2, 0x80, 0);
    if (o == INVALID) fail(path);
    while (n) {
      DWORD k = n > CHUNK ? CHUNK : (DWORD)n, wr;
      if (!readAll(h, buf, k)) fail(W("Setup-Datei beschädigt (Daten)"));
      if (!WriteFile(o, buf, k, &wr, 0) || wr != k) fail(path);
      n -= k;
    }
    CloseHandle(o);
    files++;
  }
  CloseHandle(h);
  if (files < 3) fail(W("Setup-Datei leer"));

  /* "<temp>\ChaosWard.exe" "<temp>\ChaosWard.ahk" /setup */
  cmd[0] = 0;
  wcat(cmd, W("\""));
  wcat(cmd, dir);
  wcat(cmd, W("ChaosWard.exe\" \""));
  wcat(cmd, dir);
  wcat(cmd, W("ChaosWard.ahk\" /setup"));   /* Skript ausdrücklich nennen, sonst hält AutoHotkey "/setup" für den Skriptnamen */
  path[0] = 0;
  wcat(path, dir);
  wcat(path, W("ChaosWard.exe"));
  static STARTUPINFOW si; static PROCINFO pi;
  zero(&si, sizeof si); zero(&pi, sizeof pi);
  si.cb = sizeof si;
  if (!CreateProcessW(path, cmd, 0, 0, 0, 0, 0, dir, &si, &pi)) fail(W("Chaos Ward konnte nicht gestartet werden"));
  CloseHandle(pi.hp); CloseHandle(pi.ht);
#ifdef TEST
  return 0;
#else
  ExitProcess(0);
#endif
}
