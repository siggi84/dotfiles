"""Behavior checks in disposable homes/repos; no real tmux sessions or downloads."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parents[1]


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / '.config'),
                        ZDOTDIR=str(self.root), PATH=f'{self.bin}:/usr/bin:/bin',
                        TEST_ROOT=str(self.root))
        for name in ('TMUX', 'ZSH', 'ZSH_CUSTOM', 'GIT_DIR', 'GIT_WORK_TREE'):
            self.env.pop(name, None)

    def command(self, args, *, cwd=None, ok=True):
        result = subprocess.run([str(x) for x in args], cwd=cwd or self.root,
                                env=self.env, capture_output=True, text=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def script(self, name, body):
        target = self.bin / name
        target.write_text(body)
        target.chmod(0o755)


class Worktrees(Sandbox):
    def setUp(self):
        super().setUp()
        self.checkout = self.root / 'develop'
        self.command(['git', 'init', '-b', 'develop', self.checkout])
        self.command(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                      'commit', '--allow-empty', '-m', 'initial'], cwd=self.checkout)
        self.worktree = self.root / 'worktrees' / 'task'
        self.script('nvim', '#!/bin/sh\nexit 0\n')
        self.script('codex', '#!/bin/sh\nexit 0\n')
        self.script('tmux', '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['TEST_ROOT'])
a = sys.argv[1:]
with (root / 'tmux.log').open('a') as f:
    f.write(json.dumps(a) + '\\n')
state = root / 'session'
if a[0] == 'has-session':
    sys.exit(0 if state.exists() else 1)
if a[0] == 'display-message':
    print(state.read_text())
if a[0] == 'new-session':
    state.write_text(a[a.index('-c') + 1])
    print('$1 %1')
if a[0] == 'split-window':
    if os.environ.get('FAIL_SPLIT'):
        sys.exit(1)
    print('%2')
if a[0] == 'kill-session':
    state.unlink(missing_ok=True)
''')

    def wt(self, name='task', ok=True):
        return self.command([REPO / 'bin/wt', name], cwd=self.checkout, ok=ok)

    def remove(self, ok=True):
        return self.command([REPO / 'bin/wt-rm', 'task'], cwd=self.checkout, ok=ok)

    def calls(self):
        log = self.root / 'tmux.log'
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def test_create_reuse_switch_and_remove_keeps_branch(self):
        self.wt()
        self.assertTrue(self.worktree.is_dir())
        self.assertEqual(self.calls()[-1], ['attach-session', '-t', '=task'])
        self.env['TMUX'] = '/test,1,0'
        self.wt()
        self.assertEqual(self.calls()[-1], ['switch-client', '-t', '=task'])
        self.assertEqual(sum(c[0] == 'new-session' for c in self.calls()), 1)
        self.remove()
        self.assertFalse(self.worktree.exists())
        self.assertFalse((self.root / 'session').exists())
        self.command(['git', 'show-ref', '--verify', 'refs/heads/feature/task'], cwd=self.checkout)
        self.wt()  # Reuse the retained branch.
        self.assertTrue(self.worktree.exists())

    def test_dirty_worktree_keeps_session(self):
        self.wt()
        (self.worktree / 'uncommitted.txt').write_text('keep me')
        result = self.remove(ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root / 'session').exists())
        self.assertEqual((self.worktree / 'uncommitted.txt').read_text(), 'keep me')
        self.assertFalse(any(c[0] == 'kill-session' for c in self.calls()))

    def test_partial_setup_can_be_retried(self):
        self.env['FAIL_SPLIT'] = '1'
        result = self.wt(ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('worktree and branch kept', result.stderr)
        self.assertTrue(self.worktree.exists())
        self.assertFalse((self.root / 'session').exists())
        self.env.pop('FAIL_SPLIT')
        self.wt()
        self.assertTrue((self.root / 'session').exists())

    def test_collision_does_not_create_worktree(self):
        (self.root / 'session').write_text('/another/repository')
        self.assertNotEqual(self.wt(ok=False).returncode, 0)
        self.assertFalse(self.worktree.exists())
        self.assertFalse(any(c[0] == 'kill-session' for c in self.calls()))

    def test_invalid_names_do_not_mutate(self):
        for name in ('../outside', 'a:b', 'a.b', '-flag', ''):
            self.assertNotEqual(self.wt(name, ok=False).returncode, 0)
        self.assertFalse((self.root / 'worktrees').exists())
        self.assertFalse(self.calls())

    def test_unrelated_directory_is_preserved(self):
        self.worktree.mkdir(parents=True)
        (self.worktree / 'keep').write_text('keep')
        self.assertNotEqual(self.wt(ok=False).returncode, 0)
        self.assertNotEqual(self.remove(ok=False).returncode, 0)
        self.assertTrue((self.worktree / 'keep').exists())

    def test_locked_worktree_keeps_session(self):
        self.wt()
        self.command(['git', 'worktree', 'lock', self.worktree], cwd=self.checkout)
        self.assertNotEqual(self.remove(ok=False).returncode, 0)
        self.assertTrue((self.root / 'session').exists())
        self.assertTrue(self.worktree.exists())


class Installer(Sandbox):
    def install(self, *options, ok=True):
        return self.command([REPO / 'install.sh', '--skip-tmux-plugins',
                             '--skip-zsh-plugins', *options], ok=ok)

    def test_preflight_backup_and_idempotence(self):
        old = self.bin / 'wt'
        old.write_text('original command')
        self.assertNotEqual(self.install(ok=False).returncode, 0)
        self.assertFalse((self.root / '.zshrc').exists())
        self.assertEqual(old.read_text(), 'original command')
        self.install('--force')
        self.assertEqual(old.resolve(), REPO / 'bin/wt')
        backups = list((self.root / '.dotfiles-backups').glob('*/wt'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'original command')
        self.install()
        self.assertEqual(len(list((self.root / '.dotfiles-backups').iterdir())), 1)


@unittest.skipUnless(shutil.which('tmux'), 'tmux is not installed')
class RealTmux(Sandbox):
    def test_layout_reuse_and_removal_on_private_server(self):
        socket = str(self.root / 'test.sock')
        self.env.update(TEST_TMUX_SOCKET=socket, SHELL='/bin/bash')
        real_tmux = shutil.which('tmux')

        def stop_server():
            subprocess.run([real_tmux, '-S', socket, 'kill-server'], capture_output=True)
            time.sleep(0.2)  # Let pane shells finish writing history before home cleanup.

        self.addCleanup(stop_server)
        self.script('tmux', f'''#!/bin/bash
case "$1" in
  attach-session|switch-client) exit 0 ;;
  *) exec {real_tmux} -S "$TEST_TMUX_SOCKET" -f /dev/null "$@" ;;
esac
''')
        for app in ('nvim', 'codex'):
            self.script(app, '#!/bin/sh\nexit 0\n')
        checkout = self.root / 'develop'
        self.command(['git', 'init', '-b', 'develop', checkout])
        self.command(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                      'commit', '--allow-empty', '-m', 'initial'], cwd=checkout)
        self.command([REPO / 'bin/wt', 'smoke'], cwd=checkout)
        panes = self.command(['tmux', 'list-panes', '-t', '=smoke:', '-F', '#{pane_id}'])
        self.assertEqual(len(panes.stdout.splitlines()), 3)
        self.command([REPO / 'bin/wt', 'smoke'], cwd=checkout)
        worktree = self.root / 'worktrees/smoke'
        dirty = worktree / 'dirty'
        dirty.write_text('keep')
        result = self.command([REPO / 'bin/wt-rm', 'smoke'], cwd=checkout, ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.command(['tmux', 'has-session', '-t', '=smoke'])
        dirty.unlink()
        self.command([REPO / 'bin/wt-rm', 'smoke'], cwd=checkout)
        self.assertFalse(worktree.exists())
        self.assertNotEqual(self.command(['tmux', 'has-session', '-t', '=smoke'], ok=False).returncode, 0)


class Helpers(Sandbox):
    def setUp(self):
        super().setUp()
        # Load only function definitions to avoid interactive plugins and user secrets.
        config = (REPO / 'zsh/.zshrc').read_text()
        self.helpers = self.root / 'helpers.zsh'
        self.helpers.write_text(config[config.index('inv() {'):config.index('if (( $+commands[zoxide] ))')])
        self.script('nvim', '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ['TEST_ROOT'], 'nvim.json').write_text(json.dumps(sys.argv[1:]))
''')

    def zsh(self, expression, ok=True):
        return self.command(['zsh', '-fc', 'source "$1"; ' + expression, 'test', self.helpers], ok=ok)

    def test_inv_preserves_spaces_newlines_and_leading_dash(self):
        self.script('fzf', "#!/usr/bin/env python3\nimport sys\nsys.stdout.buffer.write(b'space name\\0line\\nbreak\\0-leading\\0')\n")
        self.zsh('inv')
        self.assertEqual(json.loads((self.root / 'nvim.json').read_text()),
                         ['--', 'space name', 'line\nbreak', '-leading'])

    def test_cancel_does_not_open_editor(self):
        self.script('fzf', '#!/bin/sh\nexit 130\n')
        self.assertEqual(self.zsh('inv', ok=False).returncode, 130)
        self.assertFalse((self.root / 'nvim.json').exists())

    @unittest.skipUnless(shutil.which('fzf'), 'fzf is not installed')
    def test_real_picker_handles_unusual_filenames(self):
        names = ['special space.txt', 'special\nnewline.txt', '-special.txt']
        for name in names:
            (self.root / name).touch()
        self.env['FZF_DEFAULT_OPTS'] = '--filter special'
        self.zsh('inv')
        args = json.loads((self.root / 'nvim.json').read_text())
        self.assertEqual(args[0], '--')
        self.assertEqual({name.removeprefix('./') for name in args[1:]}, set(names))

    def fake_subtitles(self, create=True):
        self.script('yt-dlp', '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
folder = Path(sys.argv[sys.argv.index('-P') + 1])
Path(os.environ['TEST_ROOT'], 'download-dir').write_text(str(folder))
''' + ("(folder / 'Title [id].en.vtt').write_text('new subtitles')\n" if create else ''))
        self.script('clean_vtt.py', '#!/bin/sh\ncat -- "$1"\n')

    def test_ytnotes_only_converts_current_download(self):
        self.fake_subtitles()
        stale = self.root / 'stale.en.vtt'
        stale.write_text('old subtitles')
        self.zsh('ytnotes https://example.invalid/video')
        self.assertEqual((self.root / 'Title [id].txt').read_text(), 'new subtitles')
        self.assertEqual(stale.read_text(), 'old subtitles')
        self.assertFalse(Path((self.root / 'download-dir').read_text()).exists())
        self.assertNotEqual(self.zsh('ytnotes https://example.invalid/video', ok=False).returncode, 0)
        self.assertEqual((self.root / 'Title [id].txt').read_text(), 'new subtitles')

    def test_no_subtitles_does_not_use_stale_file(self):
        self.fake_subtitles(create=False)
        (self.root / 'stale.en.vtt').write_text('old subtitles')
        self.assertNotEqual(self.zsh('ytnotes https://example.invalid/video', ok=False).returncode, 0)
        self.assertFalse((self.root / 'stale.txt').exists())
        self.assertFalse(Path((self.root / 'download-dir').read_text()).exists())

    def test_converter_failure_cleans_temp_without_publishing(self):
        self.fake_subtitles()
        self.script('clean_vtt.py', '#!/bin/sh\necho partial\nexit 1\n')
        self.assertNotEqual(self.zsh('ytnotes https://example.invalid/video', ok=False).returncode, 0)
        self.assertFalse((self.root / 'Title [id].txt').exists())
        self.assertFalse((self.root / 'Title [id].en.vtt').exists())
        self.assertFalse(Path((self.root / 'download-dir').read_text()).exists())


if __name__ == '__main__':
    unittest.main()
