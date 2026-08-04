---
type: Grammar Rule
title: acia_crud-field
gem: mmg-acia-crud
grammar: lib/mmg/acia_crud/grammar.bnf
resource: lib/mmg/acia_crud/grammar.bnf
generated:
  by: mmg-optimize/okf-grammar/0.1.0
---
## Role
(production rule)

## Production
```bnf
<acia_crud-field> ::= ( "name" ":" VALUE ) | ( "description" ":" VALUE ) | ( "status" ":" VALUE ) VALUE ::= STRING | NUMBER | IDENTIFIER
```

## References
(terminal rule — no sub-rules)

## Terminals
- ":"
- "description"
- "name"
- "status"
- IDENTIFIER
- NUMBER
- STRING
- VALUE
