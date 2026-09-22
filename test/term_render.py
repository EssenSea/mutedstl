#!/usr/bin/env python3
"""Render mutedstl in a real PTY and assert the statusline + colours.

Exits non-zero on failure.  Skips (exit 0) if a PTY or Vim 9 is unavailable.
"""
import os, sys, pty, time, select, fcntl, termios, struct, signal

VIM = os.environ.get('VIM_BIN', '/usr/bin/vim')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCRIPT = r'''
vim9script
set rtp^=%s
silent! colorscheme blue
set laststatus=2
set noshowmode
&statusline = '%%!mutedstl#String()'
call mutedstl#Setup()
setlocal buftype=nofile
call setline(1, ['hello'])
redraw!
sleep 200m
qall!
''' % ROOT

def run():
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.pop('VIM', None)
        os.environ['TERM'] = 'xterm-256color'
        open('/tmp/_mutedstl_term.vim', 'w').write(SCRIPT)
        os.execv(VIM, ['vim', '-N', '-u', 'NONE', '-i', 'NONE', '-S', '/tmp/_mutedstl_term.vim'])
        os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    out = b''; deadline = time.time() + 10
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.3)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: break
            if not d: break
            out += d
        else:
            try:
                if os.waitpid(pid, os.WNOHANG)[0]: break
            except ChildProcessError: break
    try: os.kill(pid, signal.SIGTERM); os.waitpid(pid, 0)
    except Exception: pass
    os.close(fd)
    return out

def main():
    try:
        import pyte
    except ImportError:
        print('SKIP: pyte not installed'); return 0
    try:
        raw = run()
    except Exception as e:
        print(f'SKIP: no PTY ({e})'); return 0
    screen = pyte.Screen(80, 24); pyte.Stream(screen).feed(raw.decode('utf-8','replace'))
    row = next((i for i in range(23,-1,-1) if 'Buf:' in screen.display[i]), None)
    if row is None:
        print('FAIL: no statusline row found'); return 1
    text = screen.display[row]
    print(f'statusline: |{text}|')
    assert 'NORMAL' in text, 'FAIL: NORMAL (emphasis) missing'
    assert 'Buf:' in text,   'FAIL: ordinary section missing'
    line = screen.buffer[row]
    segs = []
    prev = None
    for x in range(80):
        c = line[x]
        if (str(c.fg), str(c.bg)) != prev:
            segs.append((x, str(c.fg), str(c.bg), c.data)); prev = (str(c.fg), str(c.bg))
    # Expect at least two colour segments (emphasis vs ordinary), with distinct bg
    # The first two colour segments are the emphasis (NORMAL) and the ordinary
    # section that follows it; their backgrounds must differ.
    print('colour segments:', segs[:4])
    if len(segs) < 2 or segs[0][2] == segs[1][2]:
        print('FAIL: emphasis/ordinary backgrounds not distinct: %s' % [(x, bg) for x, _, bg, _ in segs[:2]])
        return 1
    print('PASS: emphasis bg=%s ordinary bg=%s' % (segs[0][2], segs[1][2]))
    return 0

if __name__ == '__main__':
    sys.exit(main())
