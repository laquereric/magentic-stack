# frozen_string_literal: true

module Vv
  module UseCase
    # Model → vv-miro Effects. No HTTP. Local item.id is the UC id so
    # Share.push can wire connectors.
    module Map
      module_function

      def effects(model)
        m = stringify(model)
        canvas_w = num(m["width"], 900)
        canvas_h = num(m["height"], 1200)
        out = []

        sys = m["system"]
        if sys.is_a?(Hash)
          out << shape_effect(sys, "rectangle", canvas_w, canvas_h, fill: nil)
        end

        Array(m["actors"]).each do |actor|
          out << shape_effect(actor, "round_rectangle", canvas_w, canvas_h, fill: "#f3f4f6")
        end

        Array(m["use_cases"]).each do |uc|
          out << shape_effect(uc, "circle", canvas_w, canvas_h, fill: "#ffffff")
        end

        Array(m["associations"]).each do |edge|
          e = stringify(edge)
          item = {
            "type" => "connector",
            "id" => e["id"].to_s,
            "start" => { "id" => e["from"].to_s },
            "end" => { "id" => e["to"].to_s }
          }
          stereo = e["stereotype"].to_s
          item["captions"] = [{ "content" => "<<#{stereo}>>" }] unless stereo.empty?
          out << { "op" => "create", "item" => item }
        end

        out
      end

      def shape_effect(node, shape, canvas_w, canvas_h, fill:)
        n = stringify(node)
        w = num(n["w"], 120)
        h = num(n["h"], 80)
        x = num(n["x"], 0) + (w / 2.0) - (canvas_w / 2.0)
        y = num(n["y"], 0) + (h / 2.0) - (canvas_h / 2.0)
        item = {
          "type" => "shape",
          "id" => n["id"].to_s,
          "shape" => shape,
          "content" => n["label"].to_s,
          "x" => x,
          "y" => y,
          "width" => w,
          "height" => h
        }
        item["style"] = { "fillColor" => fill.nil? ? "transparent" : fill }
        { "op" => "create", "item" => item }
      end

      def stringify(value)
        Model.stringify(value)
      end

      def num(value, default)
        Model.num(value, default)
      end
    end
  end
end
