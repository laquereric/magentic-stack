# GENERATED from gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml. Do not hand-edit.
#
# generator:    gen-pydantic (linkml 1.11.1)
# source-sha256: 85faee409000e9842f8812e47cfef23762903f6a83beec6b027e10642d7edba9
#
# Regenerate with tooling/linkml/generate_shapes.py. The shape container
# owns this file; editing it here makes the artifact stop tracing to its
# source, which check_shape_artifacts.py fails on.

from __future__ import annotations

import re
import sys
from datetime import (
    date,
    datetime,
    time
)
from decimal import Decimal
from enum import Enum
from typing import (
    Any,
    ClassVar,
    Literal,
    Optional,
    Union
)

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    RootModel,
    SerializationInfo,
    SerializerFunctionWrapHandler,
    field_validator,
    model_serializer
)


metamodel_version = "1.11.0"
version = "None"


class ConfiguredBaseModel(BaseModel):
    model_config = ConfigDict(
        serialize_by_alias = True,
        validate_by_name = True,
        validate_assignment = True,
        validate_default = True,
        extra = "forbid",
        arbitrary_types_allowed = True,
        use_enum_values = True,
        strict = False,
    )





class LinkMLMeta(RootModel):
    root: dict[str, Any] = {}
    model_config = ConfigDict(frozen=True)

    def __getattr__(self, key:str):
        return getattr(self.root, key)

    def __getitem__(self, key:str):
        return self.root[key]

    def __setitem__(self, key:str, value):
        self.root[key] = value

    def __contains__(self, key:str) -> bool:
        return key in self.root


linkml_meta = LinkMLMeta({'default_prefix': 'pod',
     'default_range': 'string',
     'description': 'The deterministic application state BACK owns and GRAPH '
                    'projects. The sqlite row is the authority; the triples are a '
                    'view of it.',
     'id': 'https://w3id.org/cpcp/osi8/mind-pod/note',
     'imports': ['linkml:types'],
     'license': 'https://creativecommons.org/publicdomain/zero/1.0/',
     'name': 'pod_note',
     'prefixes': {'linkml': {'prefix_prefix': 'linkml',
                             'prefix_reference': 'https://w3id.org/linkml/'},
                  'pod': {'prefix_prefix': 'pod',
                          'prefix_reference': 'urn:mm:vocab/pod#'}},
     'source_file': '/Users/ericlaquer/NoIcloud/magentic-stack/gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml',
     'title': 'mind-pod Note'} )


class Note(ConfiguredBaseModel):
    """
    A note as BACK records it. Closed on purpose: a caller that could add a property this shape does not name would be writing state nothing downstream knows how to read.
    """
    linkml_meta: ClassVar[LinkMLMeta] = LinkMLMeta({'class_uri': 'pod:Note',
         'from_schema': 'https://w3id.org/cpcp/osi8/mind-pod/note'})

    id: str = Field(default=..., description="""The row id. Carried in the subject IRI, not beside it.""", json_schema_extra = { "linkml_meta": {'domain_of': ['Note']} })
    title: str = Field(default=..., description="""Present and non-empty; the model validates presence too.""", json_schema_extra = { "linkml_meta": {'domain_of': ['Note'], 'slot_uri': 'pod:title'} })
    body: Optional[str] = Field(default=None, description="""Optional. Absent emits no triple rather than an empty literal.""", json_schema_extra = { "linkml_meta": {'domain_of': ['Note'], 'slot_uri': 'pod:body'} })
    created_at: datetime  = Field(default=..., description="""Server-stamped, ISO 8601. BACK sets this; a caller does not.""", json_schema_extra = { "linkml_meta": {'domain_of': ['Note'], 'slot_uri': 'pod:createdAt'} })


# Model rebuild
# see https://pydantic-docs.helpmanual.io/usage/models/#rebuilding-a-model
Note.model_rebuild()
