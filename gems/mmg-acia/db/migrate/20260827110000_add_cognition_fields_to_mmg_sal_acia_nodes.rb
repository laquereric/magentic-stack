# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# A node produces TWO artifacts: something visible and something a model reads.
#
# Until now `value` served both, which quietly asserts they are the same text.
# They are not. A pane cell shows "arc_flow_run_show"; the context a model needs
# for that node is a sentence about what the action does and when to use it.
# Conflating them means improving one degrades the other.
#
# preview_text is Profile 2's p2:previewText -- the BOUNDED text handed to a
# model, which dereferences cpcp:references (entity_iri) when it needs the whole
# thing. Nullable: a node with nothing extra to say falls back to `value`, and a
# node with no referent produces no preview at all.
#
# cognition_summary is p2:summary for a cpcp:Insight -- a statement ABOUT a
# subtree rather than about one node. Only a root carries one.
class AddCognitionFieldsToMmgSalAciaNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :mmg_sal_acia_nodes, :preview_text, :text
    add_column :mmg_sal_acia_nodes, :cognition_summary, :text
  end
end
