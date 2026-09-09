# frozen_string_literal: true

# GENERATED FROM types.yaml. Do not hand-edit.
#
# Source: https://raw.githubusercontent.com/linkml/linkml-model/main/\
#         linkml_model/model/schema/types.yaml
# SHA-256: 1c79b264397bec0eadb404d22e9b163458f1b889809b3b482ecc39c98743fe00
# Bytes:   7296   Read: 2026-09-08
#
# 19 types. 03schemas.md lists 14 of them, capitalised. See Types.MISCASED.
# Each row is [curie, uri, base, repr, description, conforms_to].

module Vv
  module Linkml
    module Types
      BUILTIN = {
        "string" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "str", nil,
          "A character string", nil],
        "integer" => ["xsd:integer", "http://www.w3.org/2001/XMLSchema#integer", "int", nil,
          "An integer", nil],
        "boolean" => ["xsd:boolean", "http://www.w3.org/2001/XMLSchema#boolean", "Bool", "bool",
          "A binary (true or false) value", nil],
        "float" => ["xsd:float", "http://www.w3.org/2001/XMLSchema#float", "float", nil,
          "A real number that conforms to the xsd:float specification", nil],
        "double" => ["xsd:double", "http://www.w3.org/2001/XMLSchema#double", "float", nil,
          "A real number that conforms to the xsd:double specification", nil],
        "decimal" => ["xsd:decimal", "http://www.w3.org/2001/XMLSchema#decimal", "Decimal", nil,
          "A real number with arbitrary precision that conforms to the xsd:decimal specification", nil],
        "time" => ["xsd:time", "http://www.w3.org/2001/XMLSchema#time", "XSDTime", "str",
          "A time object represents a (local) time of day, independent of any particular day", nil],
        "date" => ["xsd:date", "http://www.w3.org/2001/XMLSchema#date", "XSDDate", "str",
          "a date (year, month and day) in an idealized calendar", nil],
        "datetime" => ["xsd:dateTime", "http://www.w3.org/2001/XMLSchema#dateTime", "XSDDateTime", "str",
          "The combination of a date and time", nil],
        "date_or_datetime" => ["linkml:DateOrDatetime", "https://w3id.org/linkml/DateOrDatetime", "str", "str",
          "Either a date or a datetime", nil],
        "uriorcurie" => ["xsd:anyURI", "http://www.w3.org/2001/XMLSchema#anyURI", "URIorCURIE", "str",
          "a URI or a CURIE", nil],
        "curie" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "Curie", "str",
          "a compact URI", "https://www.w3.org/TR/curie/"],
        "uri" => ["xsd:anyURI", "http://www.w3.org/2001/XMLSchema#anyURI", "URI", "str",
          "a complete URI", "https://www.ietf.org/rfc/rfc3987.txt"],
        "ncname" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "NCName", "str",
          "Prefix part of CURIE", nil],
        "objectidentifier" => ["shex:iri", "http://www.w3.org/ns/shex#iri", "ElementIdentifier", "str",
          "A URI or CURIE that represents an object in the model.", nil],
        "nodeidentifier" => ["shex:nonLiteral", "http://www.w3.org/ns/shex#nonLiteral", "NodeIdentifier", "str",
          "A URI, CURIE or BNODE that represents a node in a model.", nil],
        "jsonpointer" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "str", "str",
          "A string encoding a JSON Pointer. The value of the string MUST conform to JSON Point syntax and SHOULD dereference to a valid object within the current instance document when encoded in tree form.", "https://datatracker.ietf.org/doc/html/rfc6901"],
        "jsonpath" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "str", "str",
          "A string encoding a JSON Path. The value of the string MUST conform to JSON Point syntax and SHOULD dereference to zero or more valid objects within the current instance document when encoded in tree form.", "https://www.ietf.org/archive/id/draft-goessner-dispatch-jsonpath-00.html"],
        "sparqlpath" => ["xsd:string", "http://www.w3.org/2001/XMLSchema#string", "str", "str",
          "A string encoding a SPARQL Property Path. The value of the string MUST conform to SPARQL syntax and SHOULD dereference to zero or more valid objects within the current instance document when encoded as RDF.", "https://www.w3.org/TR/sparql11-query/#propertypaths"],
      }.freeze
    end
  end
end
