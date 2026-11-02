#!/usr/bin/env python3
"""pagrab - the sound WSLg plays (PulseAudio, the monitor of RDPSink),
through libpulse-simple, as raw 16-bit stereo at 44100 Hz on stdout.

usage: pagrab.py seconds [source]
"""
import ctypes
import sys

RATE, CHANNELS = 44100, 2
PA_STREAM_RECORD, PA_SAMPLE_S16LE = 2, 3


class SampleSpec(ctypes.Structure):
    _fields_ = [("format", ctypes.c_int), ("rate", ctypes.c_uint32),
                ("channels", ctypes.c_uint8)]


def main():
    seconds = float(sys.argv[1])
    source = sys.argv[2].encode() if sys.argv[2:] else b"RDPSink.monitor"
    pa = ctypes.CDLL("libpulse-simple.so.0")
    pa.pa_simple_new.restype = ctypes.c_void_p
    spec = SampleSpec(PA_SAMPLE_S16LE, RATE, CHANNELS)
    err = ctypes.c_int(0)
    s = pa.pa_simple_new(None, b"V-OS demo", PA_STREAM_RECORD, source, b"record",
                         ctypes.byref(spec), None, None, ctypes.byref(err))
    if not s:
        sys.exit(f"pagrab: no PulseAudio source {source.decode()} ({err.value})")
    chunk = RATE * CHANNELS * 2 // 25           # a frame of video's worth
    buf = ctypes.create_string_buffer(chunk)
    out = sys.stdout.buffer
    for _ in range(int(seconds * 25)):
        if pa.pa_simple_read(ctypes.c_void_p(s), buf, chunk, ctypes.byref(err)) < 0:
            break
        out.write(buf.raw)
    pa.pa_simple_free(ctypes.c_void_p(s))


if __name__ == "__main__":
    main()
