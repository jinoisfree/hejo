"""Compare server projections against the preserved pre-change Swift observations.

This is a small semantic comparison, not a load test. State values from each
frozen observation are inputs. Early heads follow the completed journal replay; read-plan transitions and AppKit are not tested.
"""
import argparse
import asyncio
import hashlib
import json
import tempfile
from pathlib import Path
from gate.journal import Journal
from gate.history import HistoryIndex, HistoryContext
from gate.history_queries import HistoryQueries, stamp
from gate.tests.history_baseline_semantics import rows


async def compare(path):
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == 'd466f524ca9dfa73fbba37850453a4efadbc8f9d2b3953f7308597adb5c0a281'
    frozen = json.loads(raw)['samples'][0]['semantic']
    with tempfile.TemporaryDirectory() as directory:
        journal = Journal(directory)
        journal.open()
        try:
            for row in rows():
                await journal.append(row)
            replay = [journal.replay(row) for row in journal.records]
        finally:
            journal.close()
    replay_labels = ['welcome:0', *(f"{row['type']}:{row['seq']}" for row in replay), 'sync_done:0']
    assert [s['label'] for s in frozen[:len(replay_labels)]] == replay_labels
    assert [s['applied'] for s in frozen[:len(replay_labels)]] == [0, *(r['seq'] for r in replay), journal.head]
    prefix = HistoryIndex()
    compared = []
    for expected in frozen:
        head = expected['applied']
        while prefix.head < head:
            prefix.apply(replay[prefix.head])
        index = journal.history if head == journal.head else prefix
        items = {}
        def state(key, value):
            items[key] = {'v': str(value), 'at': 0, 'dev': 'fixture-device'}
        for room, value in expected['roomRead'].items():
            state('read:' + room, value)
        for thread in expected['threads']:
            state('thread:' + thread['room'] + '/' + thread['thread'], thread['read'])
            if thread['bell'] is False:
                state('bell:' + thread['room'] + '/' + thread['thread'], max(m['seq'] for m in expected['messages'] if m['room'] == thread['room'] and m['thread'] == thread['thread']))
        for message in expected['messages']:
            if message['confirmed']:
                state('confirm:' + message['id'], '1')
        context = HistoryContext({'session':'fixture-session','generation':1,'memberRevision':0,
            'ready':expected['memberFetched'],'items':items,'home':['alpha','beta','gamma'],
            'hidden':[],'names':{'alpha':'Alpha','beta':'Beta','gamma':'Gamma'},
            'now':1767312000 if expected['label']=='24-hour-boundary' else 1767225600},set(expected['roomOrder']))
        queries = HistoryQueries(index, context)
        summaries = await queries.summaries(expected['roomOrder'])
        by_key = {(s['key']['room'],s['key']['thread']):s for s in summaries}
        assert set(by_key) == {(t['room'], t['thread']) for t in expected['threads']}
        for thread in expected['threads']:
            actual = by_key[(thread['room'],thread['thread'])]
            for field in ['title','preview','latestSeq','unread','bell']:
                assert actual[field] == thread[field], (expected['label'],field,actual[field],thread[field])
            for field in ['working','settled','approved']:
                assert actual['assessment'][field] == thread[field], (expected['label'],field)
            assert (actual['assessment']['pendingID'] or '') == thread['pending']
        for notice in expected['notices']:
            scope = context.document['home'] if notice['room']=='@home' else [notice['room']]
            actual = queries.notices([s for s in summaries if s['key']['room'] in scope])
            groups = []
            for item in actual:
                group = next((g for g in groups if g['id']==item['group']), None)
                if group is None:
                    group = {'id':item['group'],'questions':item['questions'],'messages':[]}
                    groups.append(group)
                group['messages'].append(item['id'])
            assert groups == notice['groups'], (expected['label'],notice['room'],groups,notice['groups'])
        home = sorted([s for s in summaries if s['key']['room'] in context.document['home']],
                      key=lambda s:(stamp(s['lastTime']),s['key']['thread']))
        assert [s['key']['thread'] for s in home] == expected['homeOrder']
        for search in expected['searches']:
            actual = await queries.search(search['query'],expected['roomOrder'],'groups')
            projected = [{'thread':s['key']['thread'],'matches':[m['id'] for m in s['matches']],
                          'root':s['root']['rootID']} for s in actual]
            assert projected == search['groups'], (expected['label'],search['query'],projected,search['groups'])
            sidebar = await queries.search(search['query'],expected['roomOrder'],'sidebar')
            assert [m['id'] for m in sidebar] == search['sidebar']
        compared.append(expected['label'])
    return {'matched':True,'observations':compared,'replayHead':journal.head,'appliedHeads':[s['applied'] for s in frozen],'scope':['summary','assessment','unread','bell','notices','home-order','group-search','sidebar-search'],
            'notCovered':['read-plan-transitions','room-search-locale','copy-format','AppKit','performance']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('frozen',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = asyncio.run(compare(args.frozen))
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('matched',len(result['observations']),'frozen observations')
