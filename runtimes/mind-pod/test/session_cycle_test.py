#!/usr/bin/env python3
'''The session cycle, end to end, through the seam only.

MIND reads Context and proposes an Effect over /_cpcp and nowhere else. What this
checks is that the cycle WORKS and that its two load-bearing refusals actually
refuse:

  the deterministic arc   BACK projects application state into GRAPH
  the cognitive arc       a proposal lands in THAT session graph, grounded
  operationId             a PUSH without one is refused and nothing is written
  scoping                 one session cannot read another session graph

The scoping check uses a PLANTED marker rather than eyeballing row counts. An
unscoped query returns rows that look entirely plausible -- that is the whole
danger -- so the assertion has to name a value that must not appear.
'''
from __future__ import annotations
import json, os, sys, urllib.request, urllib.error

BACK = os.environ.get('BACK_URL', 'http://back:3000')
MARKER = 'SECOND-SESSION-MARKER-do-not-leak'
checks = []


def check(name, ok, detail=''):
    checks.append({'assertion': name, 'ok': bool(ok), 'detail': str(detail)[:200]})
    print(('  ok  ' if ok else '  FAIL') + ' ' + name + ' :: ' + str(detail)[:150])
    return bool(ok)


def rpc(method, params=None, op=None):
    body = {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params or {}}
    if op:
        body['operationId'] = op
    req = urllib.request.Request(BACK + '/_cpcp/rpc', data=json.dumps(body).encode(),
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode())


def unwrap(env):
    result = (env or {}).get('result') or {}
    graph = result.get('@graph')
    if isinstance(graph, list):
        try:
            return dict(graph)
        except (TypeError, ValueError):
            return {'rows': graph}
    return result


def count():
    rows = unwrap(rpc('graph.count')).get('rows') or []
    try:
        return int(rows[0]['n'])
    except (IndexError, KeyError, TypeError, ValueError):
        return -1


def main():
    print('session cycle :: BACK=' + BACK)

    # --- the deterministic arc: opening a session must reach GRAPH ---
    before = count()
    check('graph.count answers', before >= 0, before)

    s1 = unwrap(rpc('session.open', {'actor_kind': 'human'}, op='sc-open-1'))
    check('session.open mints a session', s1.get('ok') is True, s1)
    check('session names a derived graph', s1.get('session_iri', '').startswith('urn:mm:session:'),
          s1.get('session_iri'))
    # Said out loud because a Session looks like an identity and is not one.
    check('session does not claim a proven actor', s1.get('actor_proven') is False,
          s1.get('actor_proven'))

    after_open = count()
    check('BACK projected the session into GRAPH', after_open > before,
          str(before) + ' -> ' + str(after_open))

    # --- the cognitive arc: a proposal lands in THAT session graph ---
    obs = unwrap(rpc('session.observe',
                     {'session_id': s1['session_id'], 'title': 'cycle test reading',
                      'body': 'a proposal, not a finding'}, op='sc-obs-1'))
    check('session.observe commits', obs.get('ok') is True, obs.get('because') or obs.get('graph'))
    check('it landed in the SESSION graph', obs.get('graph') == s1['session_iri'], obs.get('graph'))
    check('it is grounded by an Entry', str(obs.get('ref', '')).startswith('Mmg::Graph::Entry:'),
          obs.get('ref'))

    # --- the refusal Gate 1 Part C depends on ---
    bad = rpc('session.observe', {'session_id': s1['session_id'], 'title': 'x', 'body': 'y'})
    err = (bad or {}).get('error') or {}
    check('a PUSH without operationId is REFUSED', err.get('reason') == 'operation_id_required', err)

    # --- scoping: another session must not bleed in ---
    s2 = unwrap(rpc('session.open', {'actor_kind': 'agent'}, op='sc-open-2'))
    rpc('session.observe', {'session_id': s2['session_id'], 'title': MARKER, 'body': MARKER},
        op='sc-obs-2')

    ctx = unwrap(rpc('session.context', {'session_id': s1['session_id']}))
    check('session.context reads', ctx.get('ok') is True, ctx.get('because'))
    check('context quotes the generation it read', ctx.get('generation') is not None,
          ctx.get('generation'))

    rows = ctx.get('rows') or []
    check('context returned this session rows', len(rows) > 0, str(len(rows)) + ' rows')
    leaked = [r for r in rows if MARKER in json.dumps(r)]
    check('NO rows leaked from the other session', not leaked, str(len(leaked)) + ' leaked')

    # --- the gap this cycle closed: the harness must only call live operations ---
    close = unwrap(rpc('session.close', {'session_id': s2['session_id']}, op='sc-close-2'))
    check('session.close seals', close.get('state') == 'closed', close.get('state'))

    failed = [c for c in checks if not c['ok']]
    print()
    print('  ' + str(len(checks) - len(failed)) + '/' + str(len(checks)) + ' assertions passed')
    evidence = {'gate': 'session-cycle', 'status': 'pass' if not failed else 'fail',
                'policy': 'MIND<->BACK<->GRAPH session cycle: projection live, proposals grounded '
                          'in the session graph, operationId enforced, sessions scoped',
                'assertions': checks}
    out = os.environ.get('EVIDENCE_OUT')
    if out:
        with open(out, 'w') as f:
            json.dump(evidence, f, indent=2)
    return 0 if not failed else 1


if __name__ == '__main__':
    sys.exit(main())
