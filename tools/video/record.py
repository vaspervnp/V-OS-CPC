#!/usr/bin/env python3
"""record - the V-OS demo as a video, in one language: the demo disc of
each part (`make demo-sys`) with SETUP.CFG for the language, run in the
1984 emulator for Windows (VOS_1984, default G:\\Amstrad\\1984) with no
window, 576K, which writes the picture (.gif) and the sound (.wav)
itself, frame by frame; without it CPCEMU (build/linux, `make linux`),
its window recorded through xgrab.py, no sound. Then the captions
(build/demo_captions.json, tools/video/demo.py) are burnt in, twice
the size.

usage: record.py LANG [out.mp4 [PART ...]]   LANG: en el fr es de it
(VOS_REUSE=1: a part's recording, if there is one, again)

CPCEMU needs an X display (WSLg) for its window; the demo plays by
itself (the -DDEMO build), nothing is typed into the emulator.
"""
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
BUILD = os.path.join(ROOT, "build")
EMU = os.path.join(BUILD, "linux", "V-OS", "cpcemu")
WORK = os.path.join(BUILD, "video")
HERE = os.path.dirname(os.path.abspath(__file__))
E1984 = os.environ.get("VOS_1984", "/mnt/g/Amstrad/1984/1984.exe")

# CFG_LANG (0 English, 1 the pack's) and CFG_PACK (kernel/ext.asm)
LANG_CFG = {"en": (0, 0), "el": (1, 0), "fr": (1, 1), "es": (1, 2),
            "de": (1, 3), "it": (1, 4)}
W, H = (768, 576) if os.path.exists(E1984) else (768, 542)  # the picture
BAND = 150                      # under the screen (twice the size), for the captions
FPS = 25
TAIL = 6                        # seconds recorded after the demo


def idsk(*args):
    subprocess.run(["iDSK", *args], check=True, stdout=subprocess.DEVNULL)


PACKS = {"en": "GREEK.LNG", "el": "GREEK.LNG", "fr": "FRENCH.LNG",
         "es": "SPANISH.LNG", "de": "GERMAN.LNG", "it": "ITALIAN.LNG"}
HOLE = 16                       # K left free below block 180 in part 2:
                                # what the demo writes (STREETS.VDB,
                                # WEBGET's file); part 1 writes nothing


def used_blocks(dsk):
    """Blocks in the directory of a DATA format Extended DSK."""
    d = open(dsk, "rb").read()
    sizes = [d[0x34 + t] * 256 for t in range(d[0x30])]
    track = d[0x100:0x100 + sizes[0]]
    secs, pos = {}, 0x100
    for n in range(track[0x15]):
        e = 0x18 + n * 8
        length = track[e + 6] | track[e + 7] << 8
        secs[track[e + 2]] = track[pos:pos + length]
        pos += length
    dirb = b"".join(secs[0xC1 + n] for n in range(4))
    return sum(1 for e in range(64) if dirb[e * 32] < 16
               for b in dirb[e * 32 + 16:e * 32 + 32] if b) + 2


def discs(lang, part):
    """DEMO_A.DSK in CPCEMU's DISC: the system, the language, DEMO.KEY,
    the programs in APPS' order, DISC.BAS, with (part 2) HOLE K free below block
    180 (a file put there, then taken out); the rest goes past it, which
    only an emulator reads. STREETS.VDB (made by STREETS) goes after
    STREETS, for DATABASE: the demo does not run STREETS (demo.py)."""
    os.makedirs(WORK, exist_ok=True)
    a = os.path.join(EMU, "DISC", "DEMO_A.DSK")
    shutil.copy(os.path.join(BUILD, "demo_sys.dsk"), a)
    use, pack = LANG_CFG[lang]
    cfg = os.path.join(WORK, "SETUP.CFG")
    with open(cfg, "wb") as f:     # "VCFG", version 3, setup.asm's bytes
        f.write(b"VCFG" + bytes([3, 0, use, 25, 3, 1, 0, 1, pack, 0]))
    bas = os.path.join(WORK, "DISC.BAS")
    with open(bas, "wb") as f:
        f.write(b'10 RUN"VOS"\r\n\x1a')
    idsk(a, "-i", os.path.join(BUILD, PACKS[lang]), "-t", "1", "-c", "8000", "-e", "8000")
    idsk(a, "-i", cfg, "-t", "1", "-c", "4000", "-e", "4000")
    key = os.path.join(WORK, "DEMO.KEY")
    shutil.copy(os.path.join(BUILD, f"DEMO{part}.KEY"), key)
    idsk(a, "-i", key, "-t", "1", "-c", "4000", "-e", "4000")
    idsk(a, "-i", bas, "-t", "0")       # within AMSDOS's 180 blocks
    data = json.load(open(os.path.join(BUILD, "demo_captions.json"), encoding="utf-8"))
    hole = None
    for _, files in data["parts"][part - 1]["apps"]:
        for name in files:
            path = (os.path.join(ROOT, "myapps", name.split("/")[0], "owndisc", name.split("/")[1])
                    if "/" in name else os.path.join(BUILD, name))
            k = (os.path.getsize(path) + 128 + 1023) // 1024
            used = used_blocks(a)
            if hole is None and part == 2 and used + k > 180 - HOLE:
                hole = os.path.join(WORK, "HOLE.BIN")
                with open(hole, "wb") as f:
                    f.write(bytes((180 - used) * 1024 - 128))
                idsk(a, "-i", hole, "-t", "1", "-c", "4000", "-e", "4000")
            idsk(a, "-i", path, "-t", "1", "-c", "4000", "-e", "4000")
            if name == "STREETS.BIN":   # no header: V-OS reads it whole
                idsk(a, "-i", os.path.join(HERE, "STREETS.VDB"), "-t", "0")
    if hole:
        idsk(a, "-r", "HOLE.BIN")
    total = used_blocks(a)
    assert total + HOLE <= 256, total
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "dsk_ext.py"), a],
                   check=True, stderr=subprocess.DEVNULL)
    conf = open(os.path.join(EMU, "vos.cfg"), newline="").read()
    lines = []
    for line in conf.split("\r\n"):
        if line.startswith("DRIVE_A ="):
            line = 'DRIVE_A = "./DISC/DEMO_A.DSK"\t;the demo'
        lines.append(line)
    with open(os.path.join(EMU, "demo.cfg"), "w", newline="") as f:
        f.write("\r\n".join(lines))
    print(f"record: DEMO_A.DSK, {total} blocks used, {HOLE}K free below 180")


def window():
    for _ in range(100):
        r = subprocess.run(["xdotool", "search", "--name", "^CPCemu"],
                           capture_output=True, text=True)
        ids = r.stdout.split()
        if ids:
            return ids[-1]
        time.sleep(0.1)
    sys.exit("record: no CPCEMU window")


def win_size(win):
    """The window's size, "WxH": Windows' display scaling may make it
    bigger than W x H (the recording is scaled back)."""
    r = subprocess.run(["xwininfo", "-id", win], capture_output=True, text=True,
                       check=True).stdout
    size = {k: v for k, v in (l.strip().split(": ") for l in r.splitlines()
                               if l.strip().startswith(("Width:", "Height:")))}
    return f"{size['Width']}x{size['Height']}"


def record(raw, seconds):
    if os.path.exists(E1984):
        return record_1984(raw, seconds)
    record_cpcemu(raw, seconds)


def record_1984(raw, seconds):
    """The 1984 emulator, no window: its own .gif and .wav -> raw (H.264
    and AAC)."""
    work = os.path.join(WORK, "w")
    os.makedirs(work, exist_ok=True)
    shutil.copy(os.path.join(EMU, "DISC", "DEMO_A.DSK"), os.path.join(work, "A.DSK"))
    gif, wav = (os.path.join(work, f) for f in ("rec.gif", "rec.wav"))
    win = subprocess.run(["wslpath", "-w", work], capture_output=True, text=True,
                         check=True).stdout.strip()
    subprocess.run([E1984, "--headless", "--6128", "--memory=576",
                    f"--disk-a={win}\\A.DSK", "--autostart=VOS",
                    f"--gif-out={win}\\rec.gif", f"--audio-out={win}\\rec.wav",
                    f"--exit-after={int(seconds * 50)}"],
                   cwd=os.path.dirname(E1984), stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, check=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", gif, "-i", wav, "-c:v", "libx264", "-preset", "veryfast",
                    "-crf", "12", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                    "-shortest", raw], check=True)


def record_cpcemu(raw, seconds):
    emu = subprocess.Popen(["./cpcemu", "-c", "demo.cfg", "-t", "2"], cwd=EMU,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        win = window()
        time.sleep(2)                   # (its size settles)
        grab = subprocess.Popen([sys.executable, os.path.join(HERE, "xgrab.py"),
                                 win, str(FPS), str(seconds)],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        # CPCEMU's logo waits for a key: one sent to its window only (an
        # X event of its own; the CPC itself takes no keys from X here)
        subprocess.Popen(["sh", "-c", f"for i in 3 4 5 6 7 8; do sleep 1; "
                          f"xdotool key --window {win} space; done"])
        enc = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                              "-f", "rawvideo", "-pix_fmt", "bgra", "-s", win_size(win),
                              "-r", str(FPS), "-i", "-", "-vf", f"scale={W}:{H}:flags=area",
                              "-c:v", "libx264",
                              "-preset", "veryfast", "-crf", "12", "-pix_fmt", "yuv420p",
                              raw], stdin=grab.stdout)
        grab.wait()
        if enc.returncode:
            sys.exit("record: ffmpeg failed")
    finally:
        emu.kill()
        emu.wait()


def boot_time(raw):
    """Seconds into the recording when V-OS's menu bar first shows: a
    bright band across the top of the screen."""
    p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", raw,
                        "-t", "150", "-vf", f"crop={W}:6:0:16,scale=64:1", "-f", "rawvideo",
                        "-pix_fmt", "gray", "-"], capture_output=True, check=True)
    data = p.stdout
    for n in range(len(data) // 64):
        row = data[n * 64:(n + 1) * 64]
        if sum(1 for v in row[4:60] if v > 200) > 40:
            return n / FPS
    sys.exit("record: V-OS did not start")


def ass_time(s):
    s = max(s, 0)
    return f"{int(s // 3600)}:{int(s % 3600 // 60):02d}:{s % 60:05.2f}"


def changes(raw, begin):
    """-> per frame of the cut video (from begin), how much of the screen
    changed in the half second up to it (0..255, mean of a small grey
    copy): V-OS draws a new screen over several frames."""
    p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", f"{begin:.2f}",
                        "-i", raw, "-vf", "scale=96:68,format=gray", "-f", "rawvideo", "-"],
                       capture_output=True, check=True)
    n = 96 * 68
    frames = [p.stdout[i:i + n] for i in range(0, len(p.stdout) - n + 1, n)]
    lag = FPS // 2
    out = [0.0] * lag
    for a, b in zip(frames, frames[lag:]):
        out.append(sum(abs(x - y) for x, y in zip(a, b)) / n)
    return out


def aligned(times, syncs, diff):
    """The captions' times (seconds, as the demo counts them) -> seconds
    in the video. The demo's frames stop while the disc works, so it runs
    behind the video more and more: a caption whose first key changes the
    whole screen (sync) starts at the first big change from half a second
    before where it should be (with the delay so far) to 8 s after; the
    others, and one with no such change, keep the delay."""
    out, late = [], 0.0
    for t, sync in zip(times, syncs):
        first = int((t + late) * FPS)
        if sync:
            for i in range(max(first - FPS // 2, 0), min(first + 8 * FPS, len(diff))):
                if diff[i] > 15:
                    late = max(late, i / FPS - t - 0.4)
                    break
        out.append(t + late)
    return out


def captions(lang, part, start, path, diff=None):
    """The captions of a part as ASS, from start (the recording's second
    of V-OS's frame 0)."""
    data = json.load(open(os.path.join(BUILD, "demo_captions.json"),
                          encoding="utf-8"))["parts"][part - 1]
    out = ["[Script Info]", "ScriptType: v4.00+", f"PlayResX: {W * 2}",
           f"PlayResY: {H * 2 + BAND}", "WrapStyle: 0", "",
           "[V4+ Styles]",
           "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, "
           "OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, "
           "ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, "
           "MarginR, MarginV, Encoding",
           "Style: Cap,Noto Sans,46,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,"
           "-1,0,0,0,100,100,0,0,1,0,0,2,40,40,30,1", "",
           "[Events]",
           "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"]
    caps = data["captions"]
    times = [start + c[0] / 50 for c in caps]
    ends = [start + c[1] / 50 for c in caps]
    if diff:
        times = aligned(times, [c[3] for c in caps], diff)
        ends = times[1:] + [ends[-1] + (times[-1] - start - caps[-1][0] / 50)]
    for a, b, (first, last, texts, _) in zip(times, ends, caps):
        b -= 0.2
        text = texts[lang].replace("\n", "\\N")
        out.append(f"Dialogue: 0,{ass_time(a)},{ass_time(b)},Cap,,0,0,0,,{text}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    return data["frames"] / 50


def part_video(lang, part, out):
    data = json.load(open(os.path.join(BUILD, "demo_captions.json"),
                          encoding="utf-8"))["parts"][part - 1]
    length = data["frames"] / 50
    raw = os.path.join(WORK, f"raw-{lang}-{part}.mp4")
    if not (os.environ.get("VOS_REUSE") and os.path.exists(raw)):
        discs(lang, part)                 # VOS_REUSE=1: the recording there
        record(raw, length + 120 + TAIL)  # CPCEMU's start (M4), the boot
    boot = boot_time(raw)
    start = boot - 1.0                    # V-OS's frame 0, before its desk
    ass = os.path.join(WORK, f"captions-{lang}-{part}.ass")
    begin = max(boot - 1.5, 0)
    captions(lang, part, start - begin, ass,  # times in the cut video
             changes(raw, begin))
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-ss", f"{begin:.2f}", "-i", raw,
                    "-t", f"{length + TAIL - (begin - start):.2f}",
                    "-vf", f"scale={W * 2}:{H * 2}:flags=neighbor,pad={W * 2}:{H * 2 + BAND}:0:0:black,"
                    "setpts=PTS-STARTPTS,"
                    f"subtitles={ass}:fontsdir=/usr/share/fonts/truetype/noto",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-r", str(FPS),
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", out], check=True)
    print(f"record: part {part}: {length / 60:.1f} minutes, V-OS at {boot:.1f} s")


def main():
    lang = sys.argv[1]
    assert lang in LANG_CFG, lang
    out = sys.argv[2] if sys.argv[2:] else os.path.join(BUILD, f"V-OS-demo-{lang}.mp4")
    parts = sys.argv[3:] or ["1", "2"]
    pieces = []
    for part in parts:
        piece = os.path.join(WORK, f"part-{lang}-{part}.mp4")
        part_video(lang, int(part), piece)
        pieces.append(piece)
    lst = os.path.join(WORK, f"parts-{lang}.txt")
    with open(lst, "w") as f:
        f.write("".join(f"file '{p}'\n" for p in pieces))
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "concat",
                    "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", out],
                   check=True)
    print(f"record: {out}")


if __name__ == "__main__":
    main()
