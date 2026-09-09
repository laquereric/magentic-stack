#!/usr/bin/env python3
"""Refuse schemas that would generate shapes which only APPEAR to validate.

Pseudo validation is worse than no validation. A missing shape is visible; a
shape that reports `conforms: true` over data nothing actually constrained is
an assurance nobody has reason to doubt. Every rule here is a way that has
happened or can happen with linkml 1.11.1, and each one was measured -- see
docs/architecture/LinkMlGaps.md.

The gaps themselves live upstream and cannot be fixed here. What CAN be fixed
is emitting an artifact that inherits one silently. So this fails closed at
generation time, where the author is present, rather than at validation time,
where only a green report is present.

  MAXCARD_ZERO       maximum_cardinality: 0 emits sh:maxCount 1 -- it PERMITS
                     one value of exactly the property it was written to
                     forbid. Express a prohibition by omitting the slot and
                     letting sh:closed refuse it.

  UNRESOLVABLE_RANGE A range naming nothing does not raise. It falls through
                     to default_range, so `range: Boolean` (the spec's own
                     list prints the 19 builtin types capitalised, and none of
                     them resolve that way) silently becomes a string.

  EMPTY_SECTION      class rules, unique_keys and classification rules are
                     four headings with no bodies in the validation chapter.
                     A schema leaning on them gets a report that says nothing
                     about them.

  UNRESOLVED_IMPORT  A derivation over an unresolved import is SHORT: it
                     carries no constraint for what it never saw, and the
                     validator then passes data against constraints that were
                     never loaded.

  VACUOUS_CLASS      A class whose every slot is optional with an unconstrained
                     range generates a NodeShape that refuses nothing. It will
                     conform to anything, including an empty node.

FAILS CLOSED: an empty source register is an error, not a pass.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
REGISTER = ROOT / "tooling/linkml/sources.json"


def find_class_slots(view, class_name):
    """Induced slots for a class, tolerant of linkml API drift."""
    try:
        return view.class_induced_slots(class_name)
    except Exception:
        out = []
        for slot_name in view.class_slots(class_name):
            try:
                out.append(view.induced_slot(slot_name, class_name))
            except Exception:
                continue
        return out


def lint(schema_path: Path) -> list[str]:
    from linkml_runtime.utils.schemaview import SchemaView

    findings: list[str] = []

    # An unresolved import raises during SchemaView construction, not later, so
    # this has to be caught here rather than in a loop over schema.imports --
    # that loop is unreachable for the case it was written for. Reported as a
    # finding rather than allowed to surface as a traceback: in a sweep a
    # traceback reads as tooling rot, and this is a defect in the schema.
    try:
        view = SchemaView(str(schema_path))
        known = set(view.all_types()) | set(view.all_classes()) | set(view.all_enums())
    except Exception as exc:
        detail = str(exc).strip().splitlines()[0][:160] if str(exc).strip() else type(exc).__name__
        return [
            f"UNRESOLVED_IMPORT or unreadable schema: {type(exc).__name__}: {detail}. "
            f"A derivation over an unresolved import is SHORT -- it carries no constraint "
            f"for what it never saw, and a validator then passes data against constraints "
            f"that were never loaded."
        ]

    lowered = {k.lower(): k for k in known}

    for class_name in view.all_classes():
        cls = view.get_class(class_name)

        # EMPTY_SECTION -- the spec defines no behaviour for these.
        for attr, label in (("rules", "rules"), ("unique_keys", "unique_keys"),
                            ("classification_rules", "classification rules")):
            value = getattr(cls, attr, None)
            if value:
                findings.append(
                    f"EMPTY_SECTION {class_name}.{label}: the validation chapter leaves this "
                    f"section a heading with no body, so nothing validates it. Express the "
                    f"constraint another way or enforce it outside the shape."
                )

        slots = find_class_slots(view, class_name)
        constrained = 0

        for slot in slots:
            where = f"{class_name}.{slot.name}"

            # MAXCARD_ZERO -- the inversion. This is the dangerous one.
            if getattr(slot, "maximum_cardinality", None) == 0:
                findings.append(
                    f"MAXCARD_ZERO {where}: emits sh:maxCount 1 and therefore PERMITS one "
                    f"value of the property it was written to forbid. Omit the slot; "
                    f"sh:closed refuses it as a ClosedConstraintComponent violation."
                )

            # UNRESOLVABLE_RANGE -- silently becomes default_range.
            rng = getattr(slot, "range", None)
            if rng and rng not in known:
                hint = ""
                if rng.lower() in lowered:
                    hint = f" Did you mean {lowered[rng.lower()]!r}? The specification's own type list prints these capitalised, and capitalised names resolve to nothing."
                findings.append(
                    f"UNRESOLVABLE_RANGE {where}: range {rng!r} names nothing in this schema "
                    f"and does not raise -- it falls through to default_range.{hint}"
                )

            if (
                getattr(slot, "required", False)
                or getattr(slot, "identifier", False)
                or getattr(slot, "key", False)
                or getattr(slot, "pattern", None)
                or getattr(slot, "minimum_value", None) is not None
                or getattr(slot, "maximum_value", None) is not None
                or (rng and rng in set(view.all_enums()))
                or (rng and rng in set(view.all_classes()))
            ):
                constrained += 1

        # VACUOUS_CLASS -- a shape that refuses nothing.
        if slots and constrained == 0:
            findings.append(
                f"VACUOUS_CLASS {class_name}: every slot is optional with an unconstrained "
                f"range, so the generated NodeShape refuses nothing and conforms to anything."
            )

    return findings


def satisfying_node(shapes, target: str):
    """A data graph holding one node of `target` that satisfies every declared property.

    Read off the shapes graph rather than the schema, because it is the
    artifact's own constraints that have to be satisfied -- if the two ever
    disagree, the artifact is what validation sees.

    Returns (graph, reason_it_could_not_be_built).
    """
    from rdflib import Graph, Literal, RDF, URIRef  # noqa: PLC0415
    from rdflib.namespace import XSD  # noqa: PLC0415

    SH = "http://www.w3.org/ns/shacl#"
    P = lambda name: URIRef(SH + name)  # noqa: E731

    graph = Graph()
    node = URIRef("urn:probe:pseudo-validation:1")
    graph.add((node, RDF.type, URIRef(target)))

    literal_for = {
        str(XSD.integer): Literal(1),
        str(XSD.boolean): Literal(True),
        str(XSD.float): Literal(1.0),
        str(XSD.double): Literal(1.0),
        str(XSD.decimal): Literal(1),
        str(XSD.date): Literal("2026-01-01", datatype=XSD.date),
        str(XSD.dateTime): Literal("2026-01-01T00:00:00Z", datatype=XSD.dateTime),
        str(XSD.time): Literal("00:00:00", datatype=XSD.time),
    }

    for shape in shapes.subjects(P("targetClass"), URIRef(target)):
        for prop in shapes.objects(shape, P("property")):
            path = next(shapes.objects(prop, P("path")), None)
            if path is None:
                continue

            permitted = next(shapes.objects(prop, P("in")), None)
            if permitted is not None:
                first = next(shapes.objects(permitted, RDF.first), None)
                graph.add((node, path, first if first is not None else Literal("x")))
                continue

            klass = next(shapes.objects(prop, P("class")), None)
            if klass is not None:
                graph.add((node, path, URIRef("urn:probe:related:1")))
                continue

            datatype = next(shapes.objects(prop, P("datatype")), None)
            if datatype is not None:
                value = literal_for.get(str(datatype))
                if value is None:
                    pattern = next(shapes.objects(prop, P("pattern")), None)
                    # A pattern-constrained string needs a value that matches it;
                    # guessing one is not something this probe can do honestly.
                    if pattern is not None:
                        return None, f"slot <{path}> is pattern-constrained"
                    value = Literal("probe")
                graph.add((node, path, value))
                continue

            graph.add((node, path, Literal("probe")))

    return graph, None


def prove_refusal(shacl_path: Path) -> list[str]:
    """Prove the generated shapes REFUSE something.

    Every rule above reasons about the schema. This one reasons about the
    artifact, and it is the only check here that would survive the schema
    being fine and the pipeline being broken: a shape that was mis-targeted,
    written to the wrong graph, or silently emptied still reports
    `conforms: true` over everything, and a green report is indistinguishable
    from a working one.

    The probe is the one violation every generated class is guaranteed to
    have an opinion about: gen-shacl emits `sh:closed true`, so a node of the
    target class carrying an undeclared property MUST be refused. If it
    conforms, the shape is not constraining that class -- whatever the reason.
    """
    findings: list[str] = []
    try:
        from pyshacl import validate  # noqa: PLC0415
        from rdflib import Graph, RDF, URIRef  # noqa: PLC0415

        SH = "http://www.w3.org/ns/shacl#"
        shapes = Graph().parse(str(shacl_path), format="turtle")
        targets = [
            str(o)
            for s in shapes.subjects(RDF.type, URIRef(SH + "NodeShape"))
            for o in shapes.objects(s, URIRef(SH + "targetClass"))
        ]
        if not targets:
            return [
                f"NO_TARGETS {shacl_path.name}: no sh:NodeShape carries an sh:targetClass, so "
                f"the shapes apply to nothing and every graph conforms vacuously."
            ]

        for target in targets:
            # Build a node that SATISFIES the shape: every declared property
            # populated with a value of the right datatype. Without this the
            # probe is refused for missing a required slot, and a shape whose
            # sh:closed had been removed would still look like it refuses --
            # passing for a reason the check does not claim.
            base, unsatisfiable = satisfying_node(shapes, target)
            if unsatisfiable:
                findings.append(
                    f"CANNOT_PROVE {shacl_path.name}: could not build a conforming node for "
                    f"<{target}> ({unsatisfiable}), so closedness cannot be probed here."
                )
                continue

            node = URIRef("urn:probe:pseudo-validation:1")
            clean_conforms, _, _ = validate(
                data_graph=base, shacl_graph=shapes, advanced=True, inplace=False
            )
            if not clean_conforms:
                findings.append(
                    f"CANNOT_PROVE {shacl_path.name}: the probe node for <{target}> does not "
                    f"conform even before an undeclared property is added, so a refusal below "
                    f"would not be evidence of closedness."
                )
                continue

            probed = Graph()
            for triple in base:
                probed.add(triple)
            probed.add((node, URIRef("urn:probe:undeclared-property"), URIRef("urn:probe:value")))
            conforms, _, _ = validate(
                data_graph=probed, shacl_graph=shapes, advanced=True, inplace=False
            )
            if conforms:
                findings.append(
                    f"DOES_NOT_REFUSE {shacl_path.name}: a node of <{target}> that satisfies "
                    f"every declared property still CONFORMS while carrying an undeclared one. "
                    f"The closed-world guarantee is gone, so a caller can supply "
                    f"server-authoritative fields the shape was written to refuse."
                )
    except ImportError as exc:
        findings.append(f"CANNOT_PROVE {shacl_path.name}: {exc}. An unprovable shape is not a passing one.")
    except Exception as exc:
        findings.append(f"CANNOT_PROVE {shacl_path.name}: {type(exc).__name__}: {str(exc)[:160]}")
    return findings


def main() -> int:
    if not REGISTER.is_file():
        print("FAIL: no source register at tooling/linkml/sources.json", file=sys.stderr)
        return 1

    register = json.loads(REGISTER.read_text(encoding="utf-8"))
    sources = register.get("sources", [])
    if not sources:
        print("FAIL: source register names no schemas -- an empty population is not a pass", file=sys.stderr)
        return 1

    total = 0
    examined = 0
    for entry in sources:
        schema = ROOT / entry["schema"]
        if not schema.is_file():
            print("  FAIL missing schema %s" % entry["schema"], file=sys.stderr)
            total += 1
            continue
        examined += 1
        findings = lint(schema)

        shacl_rel = entry.get("artifacts", {}).get("shacl")
        if shacl_rel and (ROOT / shacl_rel).is_file():
            findings += prove_refusal(ROOT / shacl_rel)

        if findings:
            for f in findings:
                print("  FAIL %s: %s" % (entry["schema"], f), file=sys.stderr)
            total += len(findings)
        else:
            print("  ok %s" % entry["schema"])

    print("population: %d examined, 0 skipped" % examined)
    if total:
        print("pseudo-validation: FAIL (%d)" % total, file=sys.stderr)
        return 1
    print("pseudo-validation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
