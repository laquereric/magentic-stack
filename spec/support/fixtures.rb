# frozen_string_literal: true

# A small but honest ACIA document: one Frame carrying two Meanings, one of
# which carries a Clarification held at a deeper disclosure tier; one Input; and
# one derived Translation. Chrome nodes (the panel, the heading) carry no
# canonical id, which is the normal case and must not be treated as an error.
module Fixtures
  module_function

  def node(id, kind, canonical_id: nil, tier: nil, label: nil, body: nil, children: [])
    value = {}
    value["canonicalId"] = canonical_id if canonical_id
    value["disclosureTier"] = tier.to_s if tier

    props = { "valueJson" => value }
    props["label"] = label if label
    props["body"] = body if body

    { "id" => id, "kind" => kind, "props" => props, "children" => children }
  end

  def frame_document
    clarification = node("n-y1m1c1", "DataItem", canonical_id: "Y1:M1:C1", tier: :sidebar,
                                                 label: "Already alongside is not thereby entitled to stay.")

    meaning_1 = node("n-y1m1", "DataItem", canonical_id: "Y1:M1", tier: :immediate,
                                          label: "Berth allocation is a duty of care",
                                          body: "A berth is not a slot on a chart.",
                                          children: [clarification])

    meaning_2 = node("n-y1m2", "DataItem", canonical_id: "Y1:M2", tier: :immediate,
                                          label: "Tide windows bind everyone equally",
                                          body: "No vessel is owed a window another loses.")

    frame = node("n-y1", "DrillDownCard", canonical_id: "Y1", tier: :immediate,
                                         label: "Harbour operations",
                                         body: "Frames what we are here to look after.",
                                         children: [meaning_1, meaning_2])

    input = node("n-x1", "DrillDownCard", canonical_id: "X1", tier: :immediate,
                                         label: "Berth 4 request, 06:10",
                                         body: "Skipper asks to stay alongside a further tide.")

    translation = node("n-x1y1", "DrillDownCard", canonical_id: "X1:Y1", tier: :immediate,
                                                 label: "Translation under Harbour operations")

    { "rootNode" => node("pnl-1", "PanelFrame",
                         children: [node("hd-1", "Heading"), input, frame, translation]) }
  end

  # The same document with the frame body rewritten and one clarification added.
  def edited_document
    doc = deep_dup(frame_document)

    find(doc["rootNode"], "n-y1")["props"]["body"] =
      "Frames what we are here to look after, and what counts as looking after it."

    find(doc["rootNode"], "n-y1m2")["children"] <<
      node("n-y1m2c1", "DataItem", canonical_id: "Y1:M2:C1", tier: :sidebar,
                                  label: "A window missed by weather is not a window forfeited.")
    doc
  end

  def find(node, id)
    return node if node["id"] == id

    Array(node["children"]).each do |c|
      found = find(c, id)
      return found if found
    end
    nil
  end

  def deep_dup(obj)
    case obj
    when Hash then obj.transform_values { |v| deep_dup(v) }
    when Array then obj.map { |v| deep_dup(v) }
    else obj
    end
  end
end
