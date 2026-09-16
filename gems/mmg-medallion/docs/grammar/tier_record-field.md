---
type: Grammar Rule
title: tier_record-field
gem: mmg-medallion
grammar: lib/mmg/medallion/grammar.bnf
resource: lib/mmg/medallion/grammar.bnf
generated:
  by: mmg-optimize/okf-grammar/0.1.0
---
## Role
(production rule)

## Production
```bnf
<tier_record-field> ::= ( "name" ":" VALUE ) | ( "rank" ":" VALUE ) | ( "slug" ":" VALUE ) | ( "description" ":" VALUE ) VALUE ::= STRING | NUMBER | IDENTIFIER
```

## References
(terminal rule — no sub-rules)

## Terminals
- ":"
- "description"
- "name"
- "rank"
- "slug"
- IDENTIFIER
- NUMBER
- STRING
- VALUE
