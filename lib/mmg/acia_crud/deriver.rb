module Mmg
  module AciaCrud
    # Introspects an ActiveRecord model's schema and emits ACIA nodes (closed vocab:
    # form/field/action/table/row/cell/details/text) for CREATE/READ/UPDATE/DELETE.
    # Field input_type is DERIVED from the column type — never invented.
    class Deriver
      # column.type -> ACIA field input_type (allowed: text,email,url,textarea,password,checkbox,number,hidden,select,date,tel,search)
      TYPE_MAP = {
        string: "text", text: "textarea", integer: "number", bigint: "number",
        float: "number", decimal: "number", boolean: "checkbox", date: "date",
        datetime: "date", time: "date", json: "textarea", jsonb: "textarea", binary: "textarea"
      }.freeze
      SKIP = %w[id created_at updated_at].freeze

      def initialize(model, base_path: nil)
        @model = model
        @name = model.name.to_s.split("::").last
        @base = base_path || "/#{table_name}"
      end

      def columns
        @model.columns.reject { |c| SKIP.include?(c.name.to_s) }
      rescue StandardError
        []
      end

      def form(mode = :create)
        path = mode == :update ? "#{@base}/:id" : @base
        verb = mode == :update ? "Save #{@name}" : "Create #{@name}"
        node("form", "#{@name} details", columns.map { |c| field(c) } + [node("action", verb, [], href: path)], action_path: path)
      end

      def table
        header = node("row", "", columns.first(6).map { |c| node("cell", humanize(c.name), []) })
        node("table", "#{@name} list", [header])
      end

      def details
        node("details", "#{@name}", columns.map { |c| node("text", "#{humanize(c.name)}: —", []) })
      end

      def destroy_action
        node("action", "Delete #{@name}", [], href: "#{@base}/:id")
      end

      def crud
        node("surface", "Manage #{@name}", [
          node("header", @name, []),
          node("pane", "", [details, table]),
          node("pane", "", [form(:create)])
        ])
      end

      private

      def field(col)
        it = input_type(col)
        n = { "kind" => "field", "value" => humanize(col.name), "name" => col.name.to_s, "input_type" => it, "children" => [] }
        n["options"] = [] if it == "select"
        n["required"] = true unless col.null
        n
      end

      def input_type(col)
        name = col.name.to_s
        return "select" if name.end_with?("_id") || name.end_with?("_urn")
        return "email"  if name.include?("email")
        return "url"    if name.include?("url") || name.include?("href")
        return "tel"    if name.include?("phone") || name.include?("tel")
        TYPE_MAP[col.type] || "text"
      end

      def node(kind, value, children = [], **extra)
        { "kind" => kind, "value" => value, "children" => children }.merge(extra.transform_keys(&:to_s))
      end

      def table_name
        (@model.respond_to?(:table_name) && @model.table_name) || "#{@name.downcase}s"
      end

      def humanize(s)
        s.to_s.tr("_", " ").sub(/_?id\z/, "").strip.sub(/\A./, &:upcase)
      end
    end
  end
end
