#!/usr/bin/env python3
"""An open task must leave the editor idle.

Headless tests cannot see this: SafeState is only raised by the main loop of an
editor with a terminal. This starts one in a pseudo-terminal, opens a task and
counts the idle ticks over two seconds. tests/run.sh sets the environment.
"""
import json
import os
import pty
import subprocess
import sys
import tempfile
import threading
import time

BIN = os.environ.get('NVIM_BIN', 'nvim')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIMIT = 100  # ticks in two seconds; a task that keeps the editor awake makes thousands


def main():
    master, slave = pty.openpty()
    with tempfile.TemporaryDirectory() as directory:
        socket = os.path.join(directory, 'nvim.sock')
        editor = subprocess.Popen([BIN, '--clean', '-u', 'tests/init.lua', '-i', 'NONE', '--listen', socket],
                                  cwd=ROOT, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)

        def drain():
            try:
                while os.read(master, 65536):
                    pass
            except OSError:
                pass
        threading.Thread(target=drain, daemon=True).start()

        def lua(code):
            wrapped = 'vim.json.encode((function() ' + code + ' end)())'
            expression = "luaeval('" + wrapped.replace("'", "''") + "')"
            result = subprocess.run([BIN, '--clean', '-i', 'NONE', '--server', socket, '--remote-expr', expression],
                                    capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return json.loads(result.stdout)

        try:
            deadline = time.monotonic() + 10
            while True:
                if time.monotonic() > deadline or editor.poll() is not None:
                    raise RuntimeError('the editor did not start')
                try:
                    if os.path.exists(socket) and lua('return vim.v.vim_did_enter') == 1:
                        break
                except (RuntimeError, subprocess.TimeoutExpired):
                    pass
                time.sleep(.05)
            lua("require('neovim_dojo').setup() "
                "_G.ticks = 0 "
                "vim.api.nvim_create_autocmd('SafeState', { callback = function() _G.ticks = _G.ticks + 1 end }) "
                "return true")
            for task in ('counted-word-ends', 'hjkl-target-grid', 'two-views-one-file'):
                assert lua("return require('neovim_dojo.session').start('" + task + "')"), task
                time.sleep(.5)
                before = lua('return _G.ticks')
                time.sleep(2)
                ticks = lua('return _G.ticks') - before
                print('%-20s %d idle ticks in 2 s' % (task, ticks))
                if ticks > LIMIT:
                    raise SystemExit('DOJO IDLE FAILED: %s keeps the editor awake (%d ticks)' % (task, ticks))
            lua("require('neovim_dojo.session').quit() return true")
        finally:
            editor.terminate()  # lets the editor remove its temporary files
            try:
                editor.wait(timeout=5)
            except subprocess.TimeoutExpired:
                editor.kill()
                editor.wait()
            os.close(master)
    print('DOJO IDLE OK')


if __name__ == '__main__':
    sys.exit(main())
