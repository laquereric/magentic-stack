# GENERATED from gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml. Do not hand-edit.
#
# generator:    gen-python (linkml 1.11.1)
# source-sha256: 85faee409000e9842f8812e47cfef23762903f6a83beec6b027e10642d7edba9
#
# Regenerate with tooling/linkml/generate_shapes.py. The shape container
# owns this file; editing it here makes the artifact stop tracing to its
# source, which check_shape_artifacts.py fails on.

# Auto generated from pod-note.yaml by pythongen.py version: 0.0.1
# Schema: pod_note
#
# id: https://w3id.org/cpcp/osi8/mind-pod/note
# description: The deterministic application state BACK owns and GRAPH projects. The sqlite row is the authority; the triples are a view of it.
# license: https://creativecommons.org/publicdomain/zero/1.0/

import dataclasses
import re
from dataclasses import dataclass
from datetime import (
    date,
    datetime,
    time
)
from typing import (
    Any,
    ClassVar,
    Dict,
    List,
    Optional,
    Union
)

from jsonasobj2 import (
    JsonObj,
    as_dict
)
from linkml_runtime.linkml_model.meta import (
    EnumDefinition,
    PermissibleValue,
    PvFormulaOptions
)
from linkml_runtime.utils.curienamespace import CurieNamespace
from linkml_runtime.utils.enumerations import EnumDefinitionImpl
from linkml_runtime.utils.formatutils import (
    camelcase,
    sfx,
    underscore
)
from linkml_runtime.utils.metamodelcore import (
    bnode,
    empty_dict,
    empty_list
)
from linkml_runtime.utils.slot import Slot
from linkml_runtime.utils.yamlutils import (
    YAMLRoot,
    extended_float,
    extended_int,
    extended_str
)
from rdflib import (
    Namespace,
    URIRef
)

from linkml_runtime.linkml_model.types import Datetime, String
from linkml_runtime.utils.metamodelcore import XSDDateTime

metamodel_version = "1.11.0"
version = None

# Namespaces
LINKML = CurieNamespace('linkml', 'https://w3id.org/linkml/')
POD = CurieNamespace('pod', 'urn:mm:vocab/pod#')
DEFAULT_ = POD


# Types

# Class references
class NoteId(extended_str):
    pass


@dataclass(repr=False)
class Note(YAMLRoot):
    """
    A note as BACK records it. Closed on purpose: a caller that could add a property this shape does not name would be
    writing state nothing downstream knows how to read.
    """
    _inherited_slots: ClassVar[list[str]] = []

    class_class_uri: ClassVar[URIRef] = POD["Note"]
    class_class_curie: ClassVar[str] = "pod:Note"
    class_name: ClassVar[str] = "Note"
    class_model_uri: ClassVar[URIRef] = POD.Note

    id: Union[str, NoteId] = None
    title: str = None
    created_at: Union[str, XSDDateTime] = None
    body: Optional[str] = None

    def __post_init__(self, *_: str, **kwargs: Any):
        if self._is_empty(self.id):
            self.MissingRequiredField("id")
        if not isinstance(self.id, NoteId):
            self.id = NoteId(self.id)

        if self._is_empty(self.title):
            self.MissingRequiredField("title")
        if not isinstance(self.title, str):
            self.title = str(self.title)

        if self._is_empty(self.created_at):
            self.MissingRequiredField("created_at")
        if not isinstance(self.created_at, XSDDateTime):
            self.created_at = XSDDateTime(self.created_at)

        if self.body is not None and not isinstance(self.body, str):
            self.body = str(self.body)

        super().__post_init__(**kwargs)


# Enumerations


# Slots
class slots:
    pass

slots.note__id = Slot(uri=POD.id, name="note__id", curie=POD.curie('id'),
                   model_uri=POD.note__id, domain=None, range=URIRef)

slots.note__title = Slot(uri=POD.title, name="note__title", curie=POD.curie('title'),
                   model_uri=POD.note__title, domain=None, range=str)

slots.note__body = Slot(uri=POD.body, name="note__body", curie=POD.curie('body'),
                   model_uri=POD.note__body, domain=None, range=Optional[str])

slots.note__created_at = Slot(uri=POD.createdAt, name="note__created_at", curie=POD.curie('createdAt'),
                   model_uri=POD.note__created_at, domain=None, range=Union[str, XSDDateTime])
