---
type: Grammar Rule
title: triple-field
gem: mmg-acia
grammar: lib/mmg/acia/grammar.bnf
resource: lib/mmg/acia/grammar.bnf
generated:
  by: mmg-optimize/okf-grammar/0.1.0
---
## Role
(production rule)

## Production
```bnf
<triple-field> ::= ( "node_id" ":" VALUE ) | ( "subject" ":" VALUE ) | ( "predicate" ":" VALUE ) | ( "object" ":" VALUE ) | ( "object_iri" ":" VALUE ) | ( "graph" ":" VALUE ) VALUE ::= STRING | NUMBER | IDENTIFIER
```

## References
(terminal rule — no sub-rules)

## Terminals
- ":"
- "graph"
- "node_id"
- "object"
- "object_iri"
- "predicate"
- "subject"
- IDENTIFIER
- NUMBER
- STRING
- VALUE
