/* Wie Convert_Monochrome aus OCR.ahk, aber "Helligkeit" = stärkster Farbkanal (max(R,G,B)).
   Farbige Schrift (PoE-Blau #8888FF, Gelb, Orange) zählt dadurch so hell wie weiße Schrift. */
__attribute__((ms_abi)) unsigned int Convert_MaxChannel(unsigned int bitmap[], unsigned int w, unsigned int h, unsigned int Stride, unsigned int threshold)
{
    unsigned int r, g, b, v, ARGB, x, y, offset = Stride / 4;
    for (y = 0; y < h * offset; y += offset) {
        for (x = 0; x < w; ++x) {
            ARGB = bitmap[x + y];
            r = (ARGB >> 16) & 0xFF;
            g = (ARGB >> 8) & 0xFF;
            b = ARGB & 0xFF;
            v = r > g ? r : g;
            v = v > b ? v : b;
            bitmap[x + y] = (v > threshold) ? 0xFFFFFFFF : 0xFF000000;
        }
    }
    return 0;
}
