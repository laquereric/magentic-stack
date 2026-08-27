# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1
#
# THE AR HARNESS -- separate from spec_helper.rb on purpose.
#
# spec_helper.rb is deliberately AR-free ("pure Tree + Markdown, no Rails engine,
# no AR") and must stay that way: those specs prove the tree builders work with
# nothing mounted. The dimension tables and Node relations need a database, so
# they get their own harness rather than dragging ActiveRecord into the other one.

require "rspec"
require "active_record"
require "ancestry"

GEM_LIB = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(GEM_LIB) unless $LOAD_PATH.include?(GEM_LIB)

require "mmg/acia/state"
require "mmg/acia/term_seeds"
require "mmg/acia/preview_composer"
require_relative "../app/models/mmg/acia/acia_term"
require_relative "../app/models/mmg/acia/triple"
require_relative "../app/models/mmg/acia/node"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

Mmg::Acia::AciaTerm.schema_sql.split(";").map(&:strip).reject(&:empty?).each do |stmt|
  ActiveRecord::Base.connection.execute(stmt)
end

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS mmg_sal_acia_nodes (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    ancestry               varchar,
    tree_key               varchar,
    position               INTEGER,
    kind                   varchar,
    value                  TEXT,
    entity_iri             varchar,
    semantic_role          varchar,
    sal_component          varchar,
    styling                TEXT,
    hint                   varchar,
    created_at             datetime(6) NOT NULL,
    updated_at             datetime(6) NOT NULL,
    semantic_state         TEXT,
    semantic_state_version varchar,
    lock_version           INTEGER NOT NULL DEFAULT 0,
    slt_semantic_role_id   INTEGER,
    content_role_id        INTEGER,
    layout_kind_id         INTEGER,
    layout_arity_id        INTEGER,
    behavior_kind_id       INTEGER,
    preview_text           TEXT,
    cognition_summary      TEXT
  );
SQL

# Node has_many :triples, dependent: :destroy -- so this table has to exist or
# every destroy raises NameError before it reaches anything worth testing. Its
# absence is why the harness never exercised destroy at all.
ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS mmg_acia_triples (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id    bigint,
    subject    varchar,
    predicate  varchar,
    object     TEXT,
    object_iri boolean,
    graph      varchar,
    created_at datetime(6) NOT NULL,
    updated_at datetime(6) NOT NULL
  );
SQL

Mmg::Acia::TermSeeds.load!

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  # Seeds are loaded ONCE above and must survive; only per-example writes roll back.
  config.around { |ex| ActiveRecord::Base.transaction { ex.run; raise ActiveRecord::Rollback } }
end
