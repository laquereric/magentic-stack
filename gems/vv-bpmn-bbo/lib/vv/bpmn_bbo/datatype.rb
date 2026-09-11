# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Datatype < Record
      KINDS = %w[xsd linkml ar_class item_structure unit].freeze
      ACTOR_CLASS = "Vv::Base::Actor"

      # LinkML types.yaml builtins (19). Names are lower-case — `Boolean` is not a name.
      LINKML_BUILTINS = {
        "string" => "http://www.w3.org/2001/XMLSchema#string",
        "integer" => "http://www.w3.org/2001/XMLSchema#integer",
        "boolean" => "http://www.w3.org/2001/XMLSchema#boolean",
        "float" => "http://www.w3.org/2001/XMLSchema#float",
        "double" => "http://www.w3.org/2001/XMLSchema#double",
        "decimal" => "http://www.w3.org/2001/XMLSchema#decimal",
        "time" => "http://www.w3.org/2001/XMLSchema#time",
        "date" => "http://www.w3.org/2001/XMLSchema#date",
        "datetime" => "http://www.w3.org/2001/XMLSchema#dateTime",
        "date_or_datetime" => "https://w3id.org/linkml/DateOrDatetime",
        "uriorcurie" => "http://www.w3.org/2001/XMLSchema#anyURI",
        "curie" => "http://www.w3.org/2001/XMLSchema#string",
        "uri" => "http://www.w3.org/2001/XMLSchema#anyURI",
        "ncname" => "http://www.w3.org/2001/XMLSchema#string",
        "objectidentifier" => "http://www.w3.org/ns/shex#iri",
        "nodeidentifier" => "http://www.w3.org/ns/shex#nonLiteral",
        "jsonpointer" => "http://www.w3.org/2001/XMLSchema#string",
        "jsonpath" => "http://www.w3.org/2001/XMLSchema#string",
        "sparqlpath" => "http://www.w3.org/2001/XMLSchema#string"
      }.freeze

      STRING_NAMES = %w[
        string time date date_or_datetime uriorcurie curie uri ncname
        objectidentifier nodeidentifier jsonpointer jsonpath sparqlpath
      ].freeze

      belongs_to :parent, class_name: "Datatype", optional: true
      belongs_to :definition_version, optional: true
      has_many :item_definitions, dependent: :restrict_with_error
      has_many :typed_values, dependent: :restrict_with_error

      validates :kind, presence: true, inclusion: { in: KINDS }
      validates :name, presence: true
      validates :ar_class_name, presence: true, if: -> { kind == "ar_class" }

      def catalog? = definition_version_id.nil?
      def actor? = kind == "ar_class" && ar_class_name == ACTOR_CLASS

      def scalar_column
        case kind
        when "ar_class" then :record_id
        when "item_structure" then :json_value
        when "unit" then :decimal_value
        else
          case name
          when "integer" then :integer_value
          when "boolean" then :boolean_value
          when "float", "double", "decimal" then :decimal_value
          when "datetime" then :datetime_value
          when *STRING_NAMES then :string_value
          else :string_value
          end
        end
      end

      def self.seed
        n = 0
        LINKML_BUILTINS.each do |name, uri|
          kind = name == "date_or_datetime" ? "linkml" : (uri.include?("XMLSchema") ? "xsd" : "linkml")
          kind = "linkml" if %w[objectidentifier nodeidentifier date_or_datetime].include?(name)
          row = find_or_initialize_by(kind: kind, name: name, definition_version_id: nil)
          row.uri = uri
          n += 1 if row.new_record? || row.changed?
          row.save!
        end
        actor = find_or_initialize_by(kind: "ar_class", name: ACTOR_CLASS, definition_version_id: nil)
        actor.ar_class_name = ACTOR_CLASS
        n += 1 if actor.new_record? || actor.changed?
        actor.save!
        { ok: true, seeded: n }
      rescue ::StandardError => e
        { ok: false, reason: :seed_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
