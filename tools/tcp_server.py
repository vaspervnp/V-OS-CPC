#!/usr/bin/env python3
"""tcp_server.py [port] - a small server for TELNET's test in the 1984
emulator (make test-telnet-m4): it greets each connection, asks a
telnet option (TTYPE: TELNET answers WILL), and answers each line in
capitals; "BYE" ends the connection. What comes is logged to
build/tcp_server.log."""
import socket
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 2323
log = open('build/tcp_server.log', 'ab', buffering=0)
srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', port))
srv.listen(1)
while True:
    conn, _ = srv.accept()
    conn.sendall(b'Hello from the server\r\n' + bytes([255, 253, 24]) +
                 'Καλημέρα από το PC\r\n'.encode('iso-8859-7'))
    data = b''
    while True:
        got = conn.recv(256)
        if not got:
            break
        log.write(got)
        data += got
        while b'\r\n' in data:
            line, data = data.split(b'\r\n', 1)
            if line == b'BYE':
                conn.sendall(b'Bye!\r\n')
                conn.close()
                break
            conn.sendall(b'> ' + line.upper() + b'\r\n')
        else:
            continue
        break
    conn.close()
