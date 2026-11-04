#!/usr/bin/env python3
"""Check DIARY (make test-diary).

usage: diary_check.py diary.bin diary.sym

Runs DIARY (myapps/diary, assembled at #4000, with its symbols) in a Z80
emulator with the V-OS calls stubbed as tools/database_check.py does
them (its screen of text, its model of DB.SYS, VOS_INPUT and
VOS_DIALOG from a script), and VX_M4 answering C_TIME. It must start on
the M4's day, show the month a week a row from Monday with the day
inverted, add notes to DIARY.VDB (made on its drive) and mark their day,
change and delete them in the notes, move by days and weeks into the
months around, and by months, with February's 29th in a leap year; and
start on the last day with a note without an M4 board. Exits 1 on the
first difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database_check as dc  # noqa: E402

CMD = dict(ADD=1, CHANGE=2, DELETE=3, TODAY=4, PREV_M=5, NEXT_M=6, DRIVE=7)
TOP_Y, WEEK_Y, CAL_Y, NOTES_Y = 14, 30, 42, 120


def check(what, got, want):
    if got != want:
        sys.exit('diary_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def command(app, c):
    app.call('COMMAND', a=dc.VC_APP + CMD[c])


def char(app, ch):
    app.key(63, ord(ch))


def month(app):
    """the month as drawn: {day: (marked, inverted)}, and each day's
    weekday (0 Monday) and week"""
    days = {}
    for r in range(6):
        y = CAL_Y + 12 * r
        row = app.screen.get(y, [' '] * 48)
        inv = app.inv.get(y, [False] * 48)
        for c in range(7):
            cell = ''.join(row[1 + 3 * c:4 + 3 * c])
            if cell.strip():
                days[int(cell[:2])] = (cell[2] == '*', inv[2 + 3 * c], c, r)
    return days


def notes(app):
    out = []
    for i in range(10):
        line = app.line(NOTES_Y + 14 + 10 * i)[2:]
        if line:
            inv = any(app.inv.get(NOTES_Y + 14 + 10 * i, []))
            out.append((line, inv))
    return out


def chosen(app):
    return [d for d, (_, inv, _, _) in month(app).items() if inv]


def records(app):
    tab = app.db.files[b'\x01DIARY   VDB'][0]
    return sorted(tab.recs[r].decode('vos').rstrip() for r in tab.recs)


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    app = dc.App(prog, sym)
    app.m4 = '09:30:00 2026-11-04'
    app.call('INIT', a=0)
    check('the month', app.line(TOP_Y)[1:14], 'NOVEMBER 2026')
    check('the diary', app.line(TOP_Y)[34:], 'B:DIARY.VDB')
    check('the week', app.line(WEEK_Y)[1:], 'MO TU WE TH FR SA SU')
    days = month(app)
    check('30 days', sorted(days), list(range(1, 31)))
    check('the 1st a Sunday', days[1][2:], (6, 0))
    check('the 4th a Wednesday', days[4][2:], (2, 1))
    check('the 4th chosen', chosen(app), [4])
    check('its day', app.line(NOTES_Y)[1:], '2026-11-04 WE')
    check('no notes', app.line(NOTES_Y + 14)[2:], 'NOTHING ON THIS DAY: ^A ADDS A NOTE')
    # notes added: in DIARY.VDB, the day marked
    app.inputs = ['Dentist at 10']
    command(app, 'ADD')
    app.inputs = ['Call Maria']
    command(app, 'ADD')
    check('the records', records(app), ['2026-11-04Call Maria', '2026-11-04Dentist at 10'])
    check('the notes', [n for n, _ in notes(app)], ['Dentist at 10', 'Call Maria'])
    check('the 4th marked', month(app)[4][0], True)
    check('the 5th not', month(app)[5][0], False)
    app.key('RIGHT')
    check('RIGHT: the 5th', (chosen(app), app.line(NOTES_Y)[1:]), ([5], '2026-11-05 TH'))
    check('nothing on it', notes(app), [('NOTHING ON THIS DAY: ^A ADDS A NOTE', False)])
    app.key('LEFT')
    # the notes: TAB, DOWN, RETURN changes, DEL deletes
    app.key('TAB')
    check('TAB: the first note chosen', notes(app), [('Dentist at 10', True), ('Call Maria', False)])
    app.key('DOWN')
    app.inputs = ['Call Maria at 6']
    app.key('RETURN')
    check('changed', records(app), ['2026-11-04Call Maria at 6', '2026-11-04Dentist at 10'])
    app.key('UP')
    app.buttons = [0]                        # YES
    app.key('DEL')
    check('deleted', records(app), ['2026-11-04Call Maria at 6'])
    check('one note left', [n for n, _ in notes(app)], ['Call Maria at 6'])
    app.key('TAB')
    # by weeks and days into the months around
    app.key('UP')
    check('UP: October 28th', (app.line(TOP_Y)[1:13], chosen(app)), ('OCTOBER 2026', [28]))
    check('31 days', sorted(month(app)), list(range(1, 32)))
    check('November not marked here', month(app)[4][0], False)
    app.key('DOWN')
    app.key('UP')
    app.key('DOWN')
    check('DOWN: November 4th again', (chosen(app), month(app)[4][0]), ([4], True))
    for _ in range(4):
        app.key('LEFT')
    check('LEFT x4: October 31st', (app.line(NOTES_Y)[1:], days_of(app)), ('2026-10-31 SA', 31))
    app.key('RIGHT')
    check('RIGHT: November 1st', app.line(NOTES_Y)[1:], '2026-11-01 SU')
    char(app, '>')
    check('>: December', (app.line(TOP_Y)[1:14], chosen(app)), ('DECEMBER 2026', [1]))
    command(app, 'NEXT_M')
    check('NEXT MONTH: January', (app.line(TOP_Y)[1:13], month(app)[1][2]), ('JANUARY 2027', 4))
    for _ in range(13):
        char(app, '>')
    check('February 2028, a leap year', (app.line(TOP_Y)[1:14], days_of(app), month(app)[1][2]),
          ('FEBRUARY 2028', 29, 1))
    command(app, 'PREV_M')
    command(app, 'PREV_M')
    check('December 2027', (app.line(TOP_Y)[1:14], days_of(app)), ('DECEMBER 2027', 31))
    command(app, 'TODAY')
    check('TODAY', (app.line(TOP_Y)[1:14], chosen(app), month(app)[4][0]),
          ('NOVEMBER 2026', [4], True))
    app.m4 = None
    app.buttons = [0]
    command(app, 'TODAY')
    check('TODAY without an M4: said', app.buttons, [])
    if app.errors:
        sys.exit('diary_check: errors %r' % app.errors)
    # without an M4 board: the last day with a note
    files = app.db.files
    app = dc.App(prog, sym)
    app.db.files = files
    app.inputs = ['Party']
    app.call('INIT', a=0)
    check('no M4: the last day with a note', app.line(NOTES_Y)[1:], '2026-11-04 WE')
    command(app, 'NEXT_M')
    command(app, 'NEXT_M')
    app.key('RIGHT')
    command(app, 'ADD')
    check('a note in January', '2027-01-05Party' in records(app), True)
    app2 = dc.App(prog, sym)
    app2.db.files = files
    app2.call('INIT', a=0)
    check('the last day now', app2.line(NOTES_Y)[1:], '2027-01-05 TU')
    if app.errors or app2.errors:
        sys.exit('diary_check: errors %r' % (app.errors + app2.errors))
    print('diary_check: the M4\'s day, the month a week a row, notes added, marked, changed, '
          'deleted in DIARY.VDB, days, weeks and months on and back, February 2028, TODAY, '
          'the last day without an M4: all right')


def days_of(app):
    return max(month(app))


if __name__ == '__main__':
    main()
