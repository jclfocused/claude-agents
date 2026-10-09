#!/usr/bin/env python3
"""Deliver a message into a LIVE interactive Claude Code session on this machine.

For callers that have no SendMessage tool (Codex, cron, shell scripts). A Claude
session should use its own ListAgents + SendMessage tools instead.

  claude-peer-send.py --list
  claude-peer-send.py --to <name|pid|session-uuid|cwd-substring> --message "text"
  claude-peer-send.py --to <...> --file message.md

Reads the registry Claude Code writes at ~/.claude/sessions/<pid>.json, checks the
pid is alive, and writes one JSON line to that session's inbox socket. The receiver
applies its own inbound rules: a session that bypasses permission prompts HOLDS a
message from an unverified sender for its user's approval (dialog, 5 min expiry)
unless its settings set crossSessionInbound=accept. Exit 0 = written to the socket,
not "read by Claude".
"""
import argparse, glob, json, os, socket, sys

REG = os.path.expanduser('~/.claude/sessions')


def sessions():
    out = []
    for f in glob.glob(f'{REG}/*.json'):
        try:
            d = json.load(open(f))
            os.kill(int(d['pid']), 0)  # alive?
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            continue
        if d.get('messagingSocketPath'):
            out.append(d)
    return sorted(out, key=lambda d: d.get('startedAt', 0))


def pick(q, rows):
    exact = [d for d in rows if q in (d.get('name'), str(d.get('pid')), d.get('sessionId'))]
    if exact:
        return exact
    return [d for d in rows if q in d.get('cwd', '')]


ap = argparse.ArgumentParser()
ap.add_argument('--list', action='store_true')
ap.add_argument('--to')
g = ap.add_mutually_exclusive_group()
g.add_argument('--message')
g.add_argument('--file')
a = ap.parse_args()

rows = sessions()
if a.list or not a.to:
    for d in rows:
        print(f"{d.get('name','?'):32} pid={d['pid']:>8} {d.get('status','?'):5} {d.get('kind','?'):11} {d.get('cwd','')}")
    sys.exit(0)

hits = pick(a.to, rows)
if len(hits) != 1:
    sys.exit(f"--to {a.to!r} matched {len(hits)} live sessions; use --list and pass a name or pid")
text = a.message if a.message is not None else open(a.file).read()
if not text.strip():
    sys.exit('empty message')
if len(text) > 900_000:
    sys.exit('message over ~1M chars; send a file path instead')

target = hits[0]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(10)
s.connect(target['messagingSocketPath'])
s.sendall((json.dumps({'type': 'user', 'message': {'role': 'user', 'content': text}}) + '\n').encode())
s.close()
print(f"sent to {target.get('name')} (pid {target['pid']}, {target.get('status')}) at {target['messagingSocketPath']}")
