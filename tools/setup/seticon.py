"""Tauscht alle Icons einer Windows-EXE gegen eine .ico-Datei (hier: ChaosWard.exe = umbenannte AutoHotkey64.exe).
Nur für EXE-Dateien, deren Ressourcen-Abschnitt (.rsrc) der letzte Abschnitt ist. Ohne fremde Bibliotheken.
Aufruf: python3 seticon.py <exe> <ico> [<ausgabe.exe>]"""
import struct, sys

RT_ICON, RT_GROUP_ICON = 3, 14


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]


def parse_dir(d, base, off, sec_va, sec_raw, depth):
    """Ressourcen-Verzeichnis -> verschachtelte Liste [(key, node)], key = int-ID oder str-Name, Blatt = (bytes, codepage)"""
    n_named, n_id = u16(d, base + off + 12), u16(d, base + off + 14)
    out = []
    for i in range(n_named + n_id):
        e = base + off + 16 + 8 * i
        name, child = u32(d, e), u32(d, e + 4)
        if name & 0x80000000:
            so = base + (name & 0x7FFFFFFF)
            ln = u16(d, so)
            key = d[so + 2:so + 2 + 2 * ln].decode('utf-16-le')
        else:
            key = name
        if child & 0x80000000:
            out.append((key, parse_dir(d, base, child & 0x7FFFFFFF, sec_va, sec_raw, depth + 1)))
        else:
            de = base + child
            rva, size, cp = u32(d, de), u32(d, de + 4), u32(d, de + 8)
            out.append((key, (d[sec_raw + rva - sec_va:sec_raw + rva - sec_va + size], cp)))
    return out


def build(tree, sec_va):
    """Baum -> Bytes des .rsrc-Abschnitts (Verzeichnisse, Namen, Datenkopf, Daten)"""
    dirs, names, leaves = [], [], []

    def walk(node):
        named = sorted([x for x in node if isinstance(x[0], str)], key=lambda x: x[0].upper())
        ids = sorted([x for x in node if isinstance(x[0], int)], key=lambda x: x[0])
        me = {'entries': named + ids}
        dirs.append(me)
        for k, child in me['entries']:
            if isinstance(k, str) and k not in names:
                names.append(k)
            if isinstance(child, list):
                walk(child)
            else:
                leaves.append(child)
        return me
    walk(tree)
    # Lage berechnen
    pos = 0
    for dr in dirs:
        dr['off'] = pos
        pos += 16 + 8 * len(dr['entries'])
    name_off = {}
    for nm in names:
        name_off[nm] = pos
        pos += 2 + 2 * len(nm)
    pos = (pos + 3) & ~3
    leaf_off = {}
    for i, lf in enumerate(leaves):
        leaf_off[id(lf)] = pos
        pos += 16
    data_off = {}
    for lf in leaves:
        pos = (pos + 7) & ~7
        data_off[id(lf)] = pos
        pos += len(lf[0])
    buf = bytearray(pos)
    # Verzeichnisse schreiben (gleiche Reihenfolge wie beim Durchlaufen oben)
    k = [0]

    def write(node):
        dr = dirs[k[0]]; k[0] += 1
        named = sum(1 for e in dr['entries'] if isinstance(e[0], str))
        struct.pack_into('<IIHHHH', buf, dr['off'], 0, 0, 0, 0, named, len(dr['entries']) - named)
        slots = []
        for i, (key, child) in enumerate(dr['entries']):
            eo = dr['off'] + 16 + 8 * i
            nm = (0x80000000 | name_off[key]) if isinstance(key, str) else key
            slots.append((eo, nm, child))
        for eo, nm, child in slots:
            if isinstance(child, list):
                sub = dirs[k[0]]
                struct.pack_into('<II', buf, eo, nm, 0x80000000 | sub['off'])
                write(child)
            else:
                struct.pack_into('<II', buf, eo, nm, leaf_off[id(child)])
    write(tree)
    for nm, o in name_off.items():
        enc = nm.encode('utf-16-le')
        struct.pack_into('<H', buf, o, len(nm)); buf[o + 2:o + 2 + len(enc)] = enc
    for lf in leaves:
        lo, do = leaf_off[id(lf)], data_off[id(lf)]
        struct.pack_into('<IIII', buf, lo, sec_va + do, len(lf[0]), lf[1], 0)
        buf[do:do + len(lf[0])] = lf[0]
    return bytes(buf)


def main(exe, ico, out):
    d = bytearray(open(exe, 'rb').read())
    pe = u32(d, 0x3c); nsec = u16(d, pe + 6); optsz = u16(d, pe + 20); opt = pe + 24
    is64 = u16(d, opt) == 0x20b
    ddir = opt + (112 if is64 else 96)
    sec_align, file_align = u32(d, opt + 32), u32(d, opt + 36)
    st = opt + optsz
    secs = [(st + 40 * i, d[st + 40 * i:st + 40 * i + 8].rstrip(b'\0')) for i in range(nsec)]
    so, name = secs[-1]
    assert name == b'.rsrc', 'Ressourcen-Abschnitt ist nicht der letzte'
    sec_va, sec_raw = u32(d, so + 12), u32(d, so + 20)
    tree = parse_dir(d, sec_raw, 0, sec_va, sec_raw, 0)
    # neue Icons aus der .ico
    ic = open(ico, 'rb').read()
    n = u16(ic, 4)
    imgs = []
    for i in range(n):
        w, h, cc, _, planes, bpp, size, off = struct.unpack_from('<BBBBHHII', ic, 6 + 16 * i)
        imgs.append((w, h, cc, planes, bpp, ic[off:off + size]))
    lang_of = lambda node: node[0][0] if node else 1033
    icon_lang = 1033
    groups = []
    newtree = []
    for key, node in tree:
        if key == RT_ICON:
            icon_lang = lang_of(node[0][1]) if node else 1033
            continue
        if key == RT_GROUP_ICON:
            groups = [(gk, lang_of(gn)) for gk, gn in node]
            continue
        newtree.append((key, node))
    first_id = 1
    icon_nodes = [(first_id + i, [(icon_lang, (img[5], 0))]) for i, img in enumerate(imgs)]
    grp = struct.pack('<HHH', 0, 1, len(imgs))
    for i, (w, h, cc, planes, bpp, data) in enumerate(imgs):
        grp += struct.pack('<BBBBHHIH', w, h, cc, 0, planes or 1, bpp or 32, len(data), first_id + i)
    group_nodes = [(gk, [(gl, (grp, 0))]) for gk, gl in (groups or [(159, 1033)])]
    newtree += [(RT_ICON, icon_nodes), (RT_GROUP_ICON, group_nodes)]
    newtree.sort(key=lambda x: (isinstance(x[0], int), x[0] if isinstance(x[0], int) else 0))
    raw = build(newtree, sec_va)
    vsize = len(raw)
    rsize = (vsize + file_align - 1) // file_align * file_align
    d = d[:sec_raw] + raw + b'\0' * (rsize - vsize)
    struct.pack_into('<I', d, so + 8, vsize)          # VirtualSize
    struct.pack_into('<I', d, so + 16, rsize)         # SizeOfRawData
    struct.pack_into('<II', d, ddir + 8 * 2, sec_va, vsize)
    img_size = (sec_va + vsize + sec_align - 1) // sec_align * sec_align
    struct.pack_into('<I', d, opt + 56, img_size)     # SizeOfImage
    struct.pack_into('<I', d, opt + 64, 0)            # CheckSum (für normale Programme egal)
    open(out, 'wb').write(d)
    print('ok', len(imgs), 'Icons,', len(group_nodes), 'Gruppen,', len(d), 'Bytes')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else sys.argv[1])
