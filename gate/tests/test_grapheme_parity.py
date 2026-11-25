"""Compare history's display boundaries with the Mac app's Swift String."""
import json
import subprocess

import pytest

from gate.history_queries import prefix
from gate.history_search import clusters


SAMPLES = [
    'a\u0301b',
    '\u1100\u1161\u11a8나',
    '🇰🇷🇨🇦',
    '👍🏽끝',
    '👨‍👩‍👧‍👦끝',
    '1\ufe0f\u20e3끝',
    'क्षअ',
    'a\r\nb',
    '',
]

# Cases from the design comparison, including boundary rules missing from CF.
PROBE_SAMPLES = [
    'a\r\nb',
    '\r\r\n\n',
    'a\rb',
    '\n\r',
    'x\x00y',
    '\t́',
    'क्ष',
    'क्\u200dष',
    'कृ',
    'กำ',
    '\u0600١',
    '🇰🇷🇺',
    '🏻',
    '\u200d',
    'a\u200db',
    '❤️',
    '👩\u200d👩\u200d👧',
    '각',
    '각',
    'é̂',
    '#️⃣',
    '🏳️\u200d🌈',
    'ക്ഷ',
    'بَّ',
]


@pytest.fixture(scope='module')
def swift_results(tmp_path_factory):
    directory = tmp_path_factory.mktemp('swift-grapheme-parity')
    source = directory / 'main.swift'
    source.write_text('''
import Foundation

struct Result: Encodable {
    let count: Int
    let prefixes: [String]
}

let input = FileHandle.standardInput.readDataToEndOfFile()
let samples = try JSONDecoder().decode([String].self, from: input)
let results = samples.map { text in
    Result(count: text.count, prefixes: (0...(text.count + 1)).map { String(text.prefix($0)) })
}
FileHandle.standardOutput.write(try JSONEncoder().encode(results))
''', encoding='utf-8')
    binary = directory / 'grapheme-parity'
    subprocess.run(['swiftc', str(source), '-o', str(binary)], check=True, capture_output=True)
    samples = SAMPLES + PROBE_SAMPLES
    result = subprocess.run([str(binary)], input=json.dumps(samples), text=True,
                            check=True, capture_output=True)
    return dict(zip(samples, json.loads(result.stdout), strict=True))


@pytest.mark.parametrize('text', SAMPLES + PROBE_SAMPLES)
def test_grapheme_parity_with_swift(text, swift_results):
    actual = {'count': len(clusters(text)),
              'prefixes': [prefix(text, count) for count in range(swift_results[text]['count'] + 2)]}
    assert actual == swift_results[text]


@pytest.mark.parametrize('surrogate', ['\ud800', '\udfff'])
def test_lone_surrogate_remains_one_cluster(surrogate):
    assert clusters(surrogate) == [surrogate]
    assert prefix(surrogate, 1) == surrogate
