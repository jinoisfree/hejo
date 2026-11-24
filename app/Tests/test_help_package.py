"""D-1: production build, dirty rebuild, cross-volume archive and real Bundle lookup."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unicodedata

APP = Path(__file__).resolve().parents[1]


def run(argv, env=None):
    print({'argv': list(map(str, argv)), 'cwd': str(APP)}, flush=True)
    result = subprocess.run(list(map(str, argv)), cwd=APP, env=env)
    print('exit_code=' + str(result.returncode), flush=True)
    assert result.returncode == 0


def main(rebuild=True, archive_out=None):
    original = (APP / 'Resources/연결안내.html').read_bytes()
    with tempfile.TemporaryDirectory(prefix='hejo-help-') as tmp:
        root = Path(tmp)
        env = {**os.environ, 'HEJO_SKIP_GOOGLE_SECRET': '1', 'HEJO_SPARKLE_OFFLINE': '1',
               'HERMES_HOME': str(root / 'unused-airport'), 'COPYFILE_DISABLE': '1'}
        bundle = APP / '.build/hejo.app'
        # Cover the ordinary build, then a reused bundle containing both old spellings.
        if rebuild: run(['bash', 'scripts/build.sh'], env)
        resources = bundle / 'Contents/Resources'
        if rebuild:
            for spelling in ('NFC', 'NFD'):
                (resources / unicodedata.normalize(spelling, '연결안내.html')).write_bytes(b'obsolete resource')
            (resources / 'connection-help.html').write_bytes(b'obsolete ASCII content')
            run(['bash', 'scripts/build.sh'], env)
        assert not [p for p in resources.iterdir() if unicodedata.normalize('NFC', p.name) == '연결안내.html']
        assert (resources / 'connection-help.html').read_bytes() == original
        archive = root / 'hejo.app.tar.gz'
        run(['/usr/bin/tar', '-czf', archive, '-C', bundle.parent, bundle.name], env)
        extracted = root / 'extracted'
        extracted.mkdir()
        run(['/usr/bin/tar', '-xzf', archive, '-C', extracted], env)
        run(['codesign', '--verify', '--deep', '--strict', extracted / bundle.name], env)
        # Compile the actual lookup and its existing dependency; do not stub Bundle or product code.
        probe = root / 'HelpProbe.swift'
        probe.write_text('''import AppKit
@main struct HelpProbe {
    @MainActor static func main() throws {
        guard let bundle = Bundle(path: CommandLine.arguments[1]),
              let url = HooksHelp.guideURL(in: bundle) else { fatalError("resource missing") }
        precondition(url.lastPathComponent == "connection-help.html")
        let actual = try Data(contentsOf: url)
        let expected = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        precondition(actual == expected)
        print("BUNDLE_HELP_LOOKUP_OK")
    }
}
''')
        binary = root / 'help-probe'
        run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
             APP / 'Sources/HooksHelp.swift', APP / 'Sources/OptionWindows.swift', probe,
             '-framework', 'AppKit', '-o', binary], env)
        run([binary, extracted / bundle.name, APP / 'Resources/연결안내.html'], env)
        if archive_out is not None:
            assert not archive_out.exists()
            archive_out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(archive, archive_out)
            print('archive_sha256=' + hashlib.sha256(archive_out.read_bytes()).hexdigest(), flush=True)
        print('HELP_PACKAGE_OK source_sha256=' + hashlib.sha256(original).hexdigest(), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-existing", action="store_true")
    parser.add_argument("--artifact-out", type=Path)
    args = parser.parse_args()
    main(rebuild=not args.verify_existing, archive_out=args.artifact_out)
