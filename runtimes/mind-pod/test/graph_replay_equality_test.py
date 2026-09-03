#!/usr/bin/env python3
'''Graph replay equality -- runtimes/graph/README.md prerequisites 1 and 2.

The README says a deployed GRAPH may only be treated as a materialization once a
WHOLE-STORE REPLAY exists, because a reconstructable_from that names a procedure
nobody can execute is a false rollback point rather than a rollback point.

This EXECUTES that procedure and checks the result, which is the only way the
claim means anything:

  1. dump  <urn:mm:pod:state>       the live projection
  2. DROP  <urn:mm:pod:state>       operator teardown, direct to GRAPH
  3. graph.replay through BACK      rebuild from the relational store
  4. dump again, compare AS SETS    must be triple-for-triple equal

Step 2 talks to GRAPH directly. That is an OPERATOR action, not a MIND action:
the boundary rule constrains the agent, and a test that cannot tear down its own
fixture cannot check anything. MIND still has no such path -- mind_boundary_test.py
is what asserts that, and it is unchanged.

WHAT THIS DOES NOT COVER, stated rather than implied: only the STATE graph is
reconstructable. A session graph holds cognitive records published through
graph.publish; those are GROUNDED by an Entry row but not DERIVABLE from it --
the row carries date, name and description, never the triples. Dropping a session
graph loses it. "GRAPH is reconstructable" is therefore true of projected
application state and false of authored session content, and conflating the two
would overstate what a rebuild recovers.
'''
from __future__ import annotations
import json, os, sys, urllib.request, urllib.error

BACK = os.environ.get('BACK_URL', 'http://back:3000')
GRAPH = os.environ.get('MM_OXIGRAPH_URL', 'http://graph:7878')
STATE = 'urn:mm:pod:state'
checks = []


def check(name, ok, detail=''):
    checks.append({'assertion': name, 'ok': bool(ok), 'detail': str(detail)[:200]})
    print(('  ok  ' if ok else '  FAIL') + ' ' + name + ' :: ' + str(detail)[:160])
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


def sparql_update(query):
    '''Operator teardown. Direct to GRAPH, deliberately outside the seam.'''
    req = urllib.request.Request(GRAPH + '/update',
                                 data=('update=' + urllib.parse.quote(query)).encode(),
                                 headers={'Content-Type': 'application/x-www-form-urlencoded'},
                                 method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        e.read()
        return e.code


def dump_state():
    '''Every triple in the state graph, as a comparable set.'''
    q = 'SELECT ?s ?p ?o WHERE { GRAPH <' + STATE + '> { ?s ?p ?o } }'
    rows = unwrap(rpc('graph.query', {'sparql': q})).get('rows') or []
    return {(r.get('s'), r.get('p'), r.get('o')) for r in rows}


def main():
    import urllib.parse  # noqa: F401  (used by sparql_update)

    print('graph replay equality :: BACK=' + BACK + ' GRAPH=' + GRAPH)

    before = dump_state()
    # FAIL CLOSED ON AN EMPTY POPULATION. Replaying nothing into nothing compares
    # equal and proves not one thing. An empty state graph means the projection is
    # not running, which is the very condition this test exists to detect.
    if not check('state graph is populated before replay', len(before) > 0,
                 str(len(before)) + ' triples'):
        return finish()

    sessions_before = unwrap(rpc('graph.count')).get('rows') or []
    check('graph.count answers', bool(sessions_before), sessions_before)

    status = sparql_update('DROP GRAPH <' + STATE + '>')
    check('state graph dropped (operator teardown)', status in (200, 204), 'HTTP ' + str(status))

    emptied = dump_state()
    check('state graph is empty after DROP', len(emptied) == 0, str(len(emptied)) + ' triples')

    replay = unwrap(rpc('graph.replay'))
    check('graph.replay reports ok', replay.get('ok') is True, replay.get('because') or replay.get('replayed'))
    check('graph.replay found models to replay', bool(replay.get('models')), replay.get('models'))

    after = dump_state()
    missing = before - after
    extra = after - before

    check('replay restored every triple', not missing,
          str(len(missing)) + ' missing, e.g. ' + str(sorted(missing)[:2]))
    check('replay invented no triples', not extra,
          str(len(extra)) + ' extra, e.g. ' + str(sorted(extra)[:2]))
    check('state graph is triple-for-triple equal', before == after,
          str(len(before)) + ' before, ' + str(len(after)) + ' after')

    return finish()


def finish():
    failed = [c for c in checks if not c['ok']]
    print()
    print('  ' + str(len(checks) - len(failed)) + '/' + str(len(checks)) + ' assertions passed')
    evidence = {'gate': 'graph-replay-equality',
                'status': 'pass' if not failed else 'fail',
                'policy': 'the state graph rebuilds triple-for-triple from the relational store',
                'assertions': checks}
    out = os.environ.get('EVIDENCE_OUT')
    if out:
        with open(out, 'w') as f:
            json.dump(evidence, f, indent=2)
    print(json.dumps(evidence['status']))
    return 0 if not failed else 1


if __name__ == '__main__':
    import urllib.parse
    sys.exit(main())
