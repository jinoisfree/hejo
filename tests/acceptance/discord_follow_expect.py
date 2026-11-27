"""HEJO-DISCORD-FOLLOW AC-18 expected values, computed independently of gate/discord.py.

Reads a copy of the shared hejo folder (journal/*.jsonl, discord/sent.jsonl,
discord/channels.json) and prints, as JSON, what the startup reconcile must delete.
Definitions follow spec.md section 2:

- mapped messages of post P: sent.jsonl lines of the current tag with post == P,
  plus journal owner messages whose client_msg_id is discord:{tag}:{ch}:P:{id}.
- deleted message: a message delete record (scope != thread) for that msg_id, or a
  thread delete record (scope == thread) for its thread, and only when the journal
  also has the original message row. Room deletion alone, msg_ids missing from the
  journal, and delete records without a message row do not count (the post is kept).

Units: remove_posts are Discord post ids. remove_messages maps each remaining post
to the Discord message ids (sent.jsonl `dc`) the door must delete; every sent.jsonl
line of a deleted msg_id counts, text chunks and file messages alike.

Any unreadable line or missing field is an input error: the script exits 2 and
prints nothing, because a skipped line could hide a live message (spec AC-18).
`since_seq` lists items whose deciding delete record is newer than a given seq.

Usage: python3 -I discord_follow_expect.py <copied shared/hejo folder> [approved_seq]
Output contains real ids; keep it in the private ops folder only.
"""
import json
import sys
from collections import defaultdict
from pathlib import Path


class InputError(Exception):
    pass


def lines(path):
    result = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except ValueError:
            raise InputError(f'{path.name}:{number}') from None
        if not isinstance(row, dict):
            raise InputError(f'{path.name}:{number}')
        result.append(row)
    return result


def expected(root, approved_seq=None):
    root = Path(root)
    rows = [row for path in sorted((root / 'journal').glob('*.jsonl')) for row in lines(path)]
    tag = json.loads((root / 'discord' / 'channels.json').read_text())['tag']
    try:
        delete_seq = {}
        thread_seq = {}
        thread_of = {}
        for r in rows:
            if r['type'] == 'delete' and r.get('scope') == 'thread':
                thread_seq.setdefault((r['room'], r['thread']), r['seq'])
            elif r['type'] == 'delete':
                delete_seq.setdefault(r['msg_id'], r['seq'])
            elif r['type'] == 'message':
                thread_of[r['msg_id']] = (r.get('room', r['employee']), r['thread'])
        sent = [r for r in lines(root / 'discord' / 'sent.jsonl')]
        door, door_dc, owner = defaultdict(set), defaultdict(list), defaultdict(set)
        for r in sent:
            if r['tag'] == tag:
                door[r['post']].add(r['msg_id'])
                door_dc[(r['post'], r['msg_id'])].append(r['dc'])
        for r in rows:
            parts = r.get('client_msg_id', '').split(':') if r['type'] == 'message' else []
            if len(parts) == 5 and parts[:2] == ['discord', tag]:
                owner[parts[3]].add(r['msg_id'])
    except (KeyError, TypeError):
        raise InputError('missing field') from None

    def deleted_at(msg_id):
        # A delete record without the original message row is not proof of deletion (spec 2).
        if msg_id not in thread_of:
            return None
        seqs = [s for s in (delete_seq.get(msg_id), thread_seq.get(thread_of.get(msg_id))) if s is not None]
        return min(seqs) if seqs else None

    posts = set(door) | set(owner)
    remove_posts = sorted(p for p in posts if all(deleted_at(m) is not None for m in door[p] | owner[p]))
    remove_messages = {}
    for p in sorted(posts):
        if p in remove_posts:
            continue
        ids = sorted(dc for m in door[p] if deleted_at(m) is not None for dc in door_dc[(p, m)])
        if ids:
            remove_messages[p] = ids
    result = {'through_seq': max((r.get('seq', 0) for r in rows), default=0),
              'remove_posts': remove_posts, 'remove_messages': remove_messages,
              'counts': {'posts': len(posts), 'remove_posts': len(remove_posts),
                         'partial_posts': len(remove_messages),
                         'remove_message_ids': sum(len(v) for v in remove_messages.values()),
                         'remove_hejo_messages': sum(1 for p in remove_messages for m in door[p]
                                                     if deleted_at(m) is not None)}}
    if approved_seq is not None:
        # A post or message becomes a target after the approval only through a newer delete record.
        result['since_seq'] = {
            'posts': [p for p in remove_posts
                      if max(deleted_at(m) for m in door[p] | owner[p]) > approved_seq],
            'messages': {p: [dc for m in door[p] if (deleted_at(m) or 0) > approved_seq for dc in door_dc[(p, m)]]
                         for p in remove_messages}}
    return result


if __name__ == '__main__':
    try:
        value = expected(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else None)
    except (InputError, OSError, ValueError) as exc:
        print(f'input_error {exc}', file=sys.stderr)
        sys.exit(2)
    json.dump(value, sys.stdout, ensure_ascii=False, indent=1)
    print()
