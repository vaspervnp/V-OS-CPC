#!/usr/bin/env python3
"""xgrab - a window's pixels through libX11's XGetImage (no MIT-SHM, which
WSLg's rootless windows refuse), as raw BGRA frames on stdout.

usage: xgrab.py window_id fps seconds
"""
import ctypes
import ctypes.util
import sys
import time


class XImage(ctypes.Structure):
    _fields_ = [("width", ctypes.c_int), ("height", ctypes.c_int),
                ("xoffset", ctypes.c_int), ("format", ctypes.c_int),
                ("data", ctypes.POINTER(ctypes.c_char)),
                ("byte_order", ctypes.c_int), ("bitmap_unit", ctypes.c_int),
                ("bitmap_bit_order", ctypes.c_int), ("bitmap_pad", ctypes.c_int),
                ("depth", ctypes.c_int), ("bytes_per_line", ctypes.c_int),
                ("bits_per_pixel", ctypes.c_int)]


class XWindowAttributes(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int), ("y", ctypes.c_int),
                ("width", ctypes.c_int), ("height", ctypes.c_int),
                ("pad", ctypes.c_byte * 200)]


x = ctypes.CDLL(ctypes.util.find_library("X11"))
x.XOpenDisplay.restype = ctypes.c_void_p
x.XGetImage.restype = ctypes.POINTER(XImage)
x.XGetImage.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int,
                        ctypes.c_uint, ctypes.c_uint, ctypes.c_ulong, ctypes.c_int]
x.XDestroyImage = x.XDestroyImage if hasattr(x, "XDestroyImage") else None


def main():
    win = int(sys.argv[1], 0)
    fps = float(sys.argv[2])
    seconds = float(sys.argv[3])
    d = x.XOpenDisplay(None)
    a = XWindowAttributes()
    x.XGetWindowAttributes(ctypes.c_void_p(d), ctypes.c_ulong(win), ctypes.byref(a))
    w, h = a.width, a.height
    sys.stderr.write(f"xgrab: {w}x{h}\n")
    out = sys.stdout.buffer
    start = time.monotonic()
    n = 0
    last = None
    while True:
        due = start + n / fps
        now = time.monotonic()
        if now - start > seconds:
            break
        if due > now:
            time.sleep(due - now)
        im = x.XGetImage(d, win, 0, 0, w, h, 0xFFFFFFFF, 2)   # ZPixmap
        if im:
            i = im.contents
            frame = ctypes.string_at(i.data, i.bytes_per_line * h)
            if i.bytes_per_line != w * 4:
                frame = b"".join(frame[r * i.bytes_per_line:r * i.bytes_per_line + w * 4] for r in range(h))
            x.XDestroyImage(im)
            last = frame
        if last is None:
            last = bytes(w * h * 4)
        out.write(last)
        n += 1
        # catch up: a late frame is written again rather than skipped
        while start + n / fps < time.monotonic() - 1.0 / fps:
            out.write(last)
            n += 1


if __name__ == "__main__":
    main()
