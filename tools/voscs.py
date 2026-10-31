"""The V-OS character set: one 8-bit code for every language of V-OS.

Codes 0..127 are ASCII. 128..255 are ISO 8859-7 (Greek) as it is, so a
Greek file needs no conversion, with the letters of French, Spanish,
German and Italian in the codes ISO 8859-7 leaves free or that V-OS does
not use (#80-#9F, the rare signs of #A0-#BD, #D2, #FF):

  #80-#95  A grave .. U diaeresis   (capitals, as in LATIN below)
  #96-#9F, #A0 #A5 #A6 #A9 #AA #AC #AD #AE #AF #B1 #B2 #B3 #BD
           their small letters and sharp s
  #D2 #FF  inverted ! and ?

Written in V-OS, two more signs take a code they look like: the acute
accent is the Greek tonos (#B4) and the micro sign is mu (#EC). Not in
it: y diaeresis, OE ligature.

import voscs registers the codec "vos": text.encode("vos"),
data.decode("vos"). tools/mklng.py builds the packs with it, and
tools/mktexts.py, tools/mkvbs.py and blocks/vbc.py the program texts.
"""

import codecs

LATIN_CAPS = "ÀÁÂÄÇÈÉÊËÌÍÎÏÑÒÓÔÖÙÚÛÜ"
LATIN_SMALL = "àáâäçèéêëìíîïñòóôöùúûüß"
SMALL_CODES = list(range(0x96, 0xA0)) + [0xA0, 0xA5, 0xA6, 0xA9, 0xAA, 0xAC,
                                         0xAD, 0xAE, 0xAF, 0xB1, 0xB2, 0xB3,
                                         0xBD]
FREED = [0xA0, 0xA5, 0xA6, 0xA9, 0xAA, 0xAC, 0xAD, 0xAE, 0xAF, 0xB1, 0xB2,
         0xB3, 0xBD]


def _table():
    t = {}
    for code in range(128):
        t[code] = chr(code)
    for code in range(0xA0, 0x100):
        if code in FREED:
            continue
        try:
            t[code] = bytes([code]).decode("iso8859_7")
        except UnicodeDecodeError:
            pass
    for i, ch in enumerate(LATIN_CAPS):
        t[0x80 + i] = ch
    for code, ch in zip(SMALL_CODES, LATIN_SMALL):
        t[code] = ch
    t[0xD2] = "¡"
    t[0xFF] = "¿"
    return t


DECODE = _table()
assert len(DECODE) == 256, sorted(set(range(256)) - set(DECODE))
ENCODE = {ch: code for code, ch in DECODE.items()}
ENCODE["´"] = 0xB4                  # acute accent: tonos
ENCODE["µ"] = 0xEC                  # micro sign: mu
ENCODE["’"] = ENCODE.get("’", 0xA2)


def encode(text, errors="strict"):
    out = bytearray()
    for i, ch in enumerate(text):
        code = ENCODE.get(ch)
        if code is None:
            if errors == "strict":
                raise UnicodeEncodeError("vos", text, i, i + 1,
                                         "not in the V-OS character set")
            if errors == "replace":
                code = ord("?")
            else:
                continue
        out.append(code)
    return bytes(out), len(text)


def decode(data, errors="strict"):
    return "".join(DECODE[b] for b in bytes(data)), len(data)


def _search(name):
    if name in ("vos", "v_os", "v-os"):
        return codecs.CodecInfo(encode, decode, name="vos")
    return None


codecs.register(_search)


def char_table():
    """Code -> character, for the docs: lines of 16."""
    rows = []
    for hi in range(8, 16):
        rows.append("%X_ " % hi + " ".join(
            DECODE[hi * 16 + lo] if DECODE[hi * 16 + lo].isprintable()
            and DECODE[hi * 16 + lo] != "\xa0" else "." for lo in range(16)))
    return "\n".join(rows)


if __name__ == "__main__":
    print(char_table())
