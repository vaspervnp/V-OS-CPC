#!/usr/bin/env python3
"""mail_server.py [pop3 port] [smtp port] - the POP3 and SMTP servers of
tools/mail_check.py on this PC's ports (2110 and 2525), for MAIL's test
in the 1984 emulator (make test-mail-m4): 22 messages for user vasilis,
password secret; what comes is logged to build/mail_server.log, each
message sent to build/mail_sent.txt."""
import os
import socket
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mail_check as mc  # noqa: E402

log = open('build/mail_server.log', 'ab', buffering=0)
box = {'msgs': mc.messages()}
mails = []


def serve(port, make):
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('0.0.0.0', port))
    srv.listen(1)
    while True:
        conn, _ = srv.accept()
        s = make()
        s.connected()
        while True:
            if s.inbox:
                conn.sendall(s.inbox)
                s.inbox = b''
            if s.closing:
                break
            got = conn.recv(512)
            if not got:
                break
            log.write(got)
            s.got(got)
            if mails:
                with open('build/mail_sent.txt', 'ab') as f:
                    for rcpt, data in mails:
                        f.write(rcpt.encode() + b'\n' + b'\n'.join(data) + b'\n.\n')
                mails.clear()
        conn.close()


pop = int(sys.argv[1]) if len(sys.argv) > 1 else 2110
smtp = int(sys.argv[2]) if len(sys.argv) > 2 else 2525
threading.Thread(target=serve, args=(pop, lambda: mc.Pop3(box)), daemon=True).start()
serve(smtp, lambda: mc.Smtp(mails))
