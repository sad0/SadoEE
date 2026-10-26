"""Builds the SadoEE release zips from the generated mod folder (run build_sadoee.py first). Publishes nothing.

    python make_release.py v1.0.0

Checks that SadoEE.tp2 says that version, then writes into release/:
  SadoEE-<v>.zip        SadoEE/ + setup-SadoEE.exe + LICENSE (GitHub release)
  SadoEE-<v>-nexus.zip  SadoEE/ + INSTALL.txt + LICENSE, no executable (Nexus refuses them)
"""
import os
import shutil
import re
import sys
import zipfile

import build_sadoee

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'release')
MOD = build_sadoee.OUT
EXE = os.path.join(build_sadoee.GAME, 'setup-SadoEE.exe')

INSTALL = '''SadoEE {v} - installation (Nexus package)

Nexus does not allow executables, so this package has no installer.
SadoEE is installed with WeiDU, the standard installer of every Infinity Engine mod:

1. Install EEex first: https://github.com/Bubb13/EEex/releases
2. If you have Party Stash or SadoQoL installed, uninstall them first (SadoEE replaces both; saves keep working).
3. Extract this archive into your game folder (the folder with chitin.key).
4. Download WeiDU (Windows build) from https://github.com/WeiDUorg/weidu/releases
   and copy weidu.exe into the game folder, renamed to setup-SadoEE.exe
5. Run setup-SadoEE.exe and pick the components you want.
6. Start the game with InfinityLoader.exe (EEex).

The full package with setup-SadoEE.exe included:
https://github.com/sad0/SadoEE/releases/latest

Before uninstalling: in game, Ctrl + left click on the big bag next to the weight to empty the stash.
Readme in 15 languages: SadoEE/readme/
'''


def mod_files():
    for root, _dirs, files in os.walk(MOD):
        for f in sorted(files):
            full = os.path.join(root, f)
            yield full, 'SadoEE/' + os.path.relpath(full, MOD).replace('\\', '/')


def main(version):
    tp2 = open(os.path.join(MOD, 'SadoEE.tp2'), encoding='utf-8').read()
    found = re.search(r'VERSION\s*~([^~]+)~', tp2).group(1)
    assert found == version, 'SadoEE.tp2 says %s' % found
    os.makedirs(OUT, exist_ok=True)
    install = os.path.join(OUT, 'INSTALL.txt')
    with open(install, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(INSTALL.format(v=version))
    lic = os.path.join(HERE, 'LICENSE')
    for name, extra in (('SadoEE-%s.zip' % version, [(EXE, 'setup-SadoEE.exe'), (lic, 'LICENSE')]),
                        ('SadoEE-%s-nexus.zip' % version, [(install, 'INSTALL.txt'), (lic, 'LICENSE')])):
        path = os.path.join(OUT, name)
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
            n = 0
            for full, arc in list(mod_files()) + extra:
                z.write(full, arc)
                n += 1
        print(name, n, 'files', os.path.getsize(path), 'bytes')
    # the mod itself is versioned in the repository too (SadoEE/ = what the zip installs), so a release commit
    # shows the real code changes (lynx on Gibberlings3, 2026-10-26)
    repo_mod = os.path.join(HERE, 'SadoEE')
    if os.path.isdir(repo_mod):
        shutil.rmtree(repo_mod)
    for full, arc in mod_files():
        dst = os.path.join(HERE, arc)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(full, dst)
    print('repository SadoEE/ updated: commit it with the release')


if __name__ == '__main__':
    main(sys.argv[1])
