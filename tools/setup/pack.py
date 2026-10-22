"""Baut ChaosWard-Setup.exe = stub.exe + angehängte Dateien.
Format: je Datei [uint32 Namenslänge in Bytes][Name UTF-16LE, mit \\][uint64 Größe][Daten], Ende = uint32 0,
dann Trailer: b'CWSETUP1' + uint64 Startposition. Aufruf: python3 pack.py stub.exe <ordner> <ausgabe.exe>"""
import os, struct, sys
stub, src, out = sys.argv[1:4]
data = open(stub, 'rb').read()
with open(out, 'wb') as f:
    f.write(data)
    start = f.tell()
    n = 0
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src).replace('/', '\\').encode('utf-16-le')
            body = open(full, 'rb').read()
            f.write(struct.pack('<I', len(rel)) + rel + struct.pack('<Q', len(body)) + body)
            n += 1
    f.write(struct.pack('<I', 0))
    f.write(b'CWSETUP1' + struct.pack('<Q', start))
print('ok', n, 'Dateien', os.path.getsize(out) // 1024, 'KB')
