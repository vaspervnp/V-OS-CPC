#!/usr/bin/env python3
"""ftp_server.py [port] [data port] - a small FTP server for FTP's test
in the 1984 emulator (make test-ftp-m4), on this PC's ports 2121 and
2122 (PASV's): anonymous, a folder "pub" and two files, LIST in Unix's
lines, RETR, STOR (kept in build/ftp_stored/), CWD, CDUP, DELE. What
comes is logged to build/ftp_server.log."""
import os
import socket
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 2121
dport = int(sys.argv[2]) if len(sys.argv) > 2 else 2122
log = open('build/ftp_server.log', 'ab', buffering=0)
os.makedirs('build/ftp_stored', exist_ok=True)
files = {'hello.txt': 'Γεια σου από το PC.\r\n'.encode('iso-8859-7'),
         'data.bin': bytes(range(256)) * 12}
dsrv = socket.socket()
dsrv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
dsrv.bind(('0.0.0.0', dport))
dsrv.listen(1)


def listing(cwd):
    if cwd:
        return b''
    out = 'drwxr-xr-x    2 ftp      ftp          4096 Nov  1 10:00 pub\r\n'
    for name, data in sorted(files.items()):
        out += '-rw-r--r--    1 ftp      ftp      %8d Nov  1  2026 %s\r\n' % (len(data), name)
    return out.encode()


def session(conn):
    def say(text):
        conn.sendall(text.encode() + b'\r\n')
    say('220 FTP ready')
    cwd, part = [], b''
    while True:
        got = conn.recv(512)
        if not got:
            return
        log.write(got)
        part += got
        while b'\r\n' in part:
            one, part = part.split(b'\r\n', 1)
            word, _, arg = one.decode('latin-1').partition(' ')
            if word == 'USER':
                say('331 password please')
            elif word == 'PASS':
                say('230 in')
            elif word == 'TYPE':
                say('200 binary')
            elif word == 'PWD':
                say('257 "/%s"' % '/'.join(cwd))
            elif word == 'CWD':
                cwd.append(arg)
                say('250 OK')
            elif word == 'CDUP':
                cwd = cwd[:-1]
                say('250 OK')
            elif word == 'PASV':
                say('227 Entering Passive Mode (127,0,0,1,%d,%d)' % (dport >> 8, dport & 255))
            elif word in ('LIST', 'RETR', 'STOR'):
                data, _ = dsrv.accept()
                say('150 data')
                if word == 'STOR':
                    body = b''
                    while True:
                        more = data.recv(1024)
                        if not more:
                            break
                        body += more
                    files[arg.lower()] = body
                    open('build/ftp_stored/' + arg, 'wb').write(body)
                else:
                    data.sendall(listing(cwd) if word == 'LIST' else files.get(arg, b''))
                data.close()
                say('226 done')
            elif word == 'DELE':
                files.pop(arg, None)
                say('250 deleted')
            elif word == 'QUIT':
                say('221 bye')
                return
            else:
                say('502 what?')


srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', port))
srv.listen(1)
while True:
    c, _ = srv.accept()
    try:
        session(c)
    finally:
        c.close()
