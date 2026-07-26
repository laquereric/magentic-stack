---
"@context":
  "@vocab": urn:mm:vocab/
  mm: 'urn:mm:'
  epic: 'urn:mm:epic:'
  plan: 'urn:mm:plan:'
  inEpic:
    "@id": urn:mm:vocab/inEpic
    "@type": "@id"
  concepts:
    "@id": urn:mmg:curation/mentions
    "@type": "@id"
    "@container": "@set"
"@id": urn:mm:plan:PLAN_0_9_2
"@type": Plan
inEpic: urn:mm:epic:epic_20_telemetry_recovery
concepts:
- urn:mmg:curation:concept:epic:epic_20_telemetry_recovery
- urn:mmg:curation:concept:term:product
- urn:mmg:curation:concept:term:semant
- urn:mmg:curation:concept:term:end
- urn:mmg:curation:concept:term:search
- urn:mmg:curation:concept:term:spec
---

# PLAN 0.9.2 — Vector Search with sqlite-vec

## Source

docs/research/SqliteVector.md — SQLite extensions for vector search. `sqlite-vec` is the active successor: pure C, zero dependencies, float32/int8/bit vectors, L2/cosine/hamming distance, SIMD acceleration, runs everywhere SQLite does.

## Context

MagenticMarket runs on SQLite. No PostgreSQL, no Redis, no external services. The knowledge graph (PLAN 0.9.1) gives us structured relationships. What's missing: **semantic search** — finding products by meaning, not just by spec filters.

A prosumer asking "something quiet for a home office" can't be answered by `WHERE noise_level < X` because most products don't have a `noise_level` spec. But an embedding of the product description + reviews would place "quiet home office" near the right products.

`sqlite-vec` keeps us on SQLite — no new infrastructure, same deploy, same backup, same SolidCache/SolidQueue/SolidCable stack.

## What Vector Search Adds

| Search Type | Method | Example |
|-------------|--------|---------|
| **Exact spec** | SQL WHERE clauses | "printer under $400 with tank ink" |
| **Graph traversal** | PLAN 0.9.1 edges | "what competes with the ET-4850?" |
| **Semantic** | Vector similarity | "something quiet for photos" |

These compose: semantic search finds candidates, graph traversal finds relationships between them, spec filters narrow to constraints.

## Architecture

```
User query: "quiet color printer for home office, good for photos"
  │
  ├─ 1. Embed query → float32[384] vector
  │
  ├─ 2. sqlite-vec KNN search → top 10 nearest products
  │
  ├─ 3. Graph filter: category=printer, HAS_FEATURE=color
  │
  ├─ 4. Spec filter: price ≤ budget, duty_cycle ≥ volume
  │
  └─ 5. Return ranked candidates with provenance
       SEMANTIC (cosine: 0.87) + EXTRACTED (specs) + COMPUTED (TCO)
```

## Implementation

### 1. Install sqlite-vec

```ruby
# Gemfile
gem "sqlite-vec"  # Ruby bindings for sqlite-vec extension
```

Or load the extension directly:

```ruby
# config/initializers/sqlite_vec.rb
ActiveRecord::Base.connection.execute("SELECT load_extension('vec0')")
```

For development, install via:
```bash
# macOS
brew install sqlite-vec
# Or download prebuilt from https://github.com/asg017/sqlite-vec/releases
```

### 2. Embedding Model

Use a local embedding model to keep everything on-device (no API calls for embeddings):

```ruby
# packs/partner_bhphoto/app/services/embedding_service.rb
class EmbeddingService
  MODEL = "all-MiniLM-L6-v2"  # 384 dimensions, fast, good quality
  DIMENSIONS = 384

  def self.embed(text)
    # Option A: Local via Ollama
    response = RubyLLM.embed(text, model: "all-minilm:latest")
    response.embedding

    # Option B: Via API (OpenAI/Anthropic)
    # response = RubyLLM.embed(text, model: "text-embedding-3-small")
    # response.embedding
  end

  def self.embed_product(product)
    text = [
      product.name,
      product.brand,
      product.description,
      product.category,
      product.product_specs.map { |s| "#{s.name}: #{s.value}" }.join(", ")
    ].compact.join(". ")

    embed(text)
  end
end
```

### 3. Vector Table

sqlite-vec uses virtual tables for vector storage:

```ruby
# db/migrate/*_create_product_vectors.rb
class CreateProductVectors < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE product_vectors USING vec0(
        product_id INTEGER PRIMARY KEY,
        embedding float[384]
      );
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS product_vectors"
  end
end
```

### 4. Index Products

```ruby
# packs/partner_bhphoto/app/services/vector_indexer.rb
class VectorIndexer
  def self.index_all!
    Product.includes(:product_specs).find_each do |product|
      index_product!(product)
    end
  end

  def self.index_product!(product)
    embedding = EmbeddingService.embed_product(product)
    vector_json = embedding.to_json

    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT OR REPLACE INTO product_vectors(product_id, embedding)
      VALUES (#{product.id}, '#{vector_json}')
    SQL
  end
end
```

### 5. Semantic Search Operation

```ruby
# packs/partner_bhphoto/app/operations/bhphoto/semantic_search.rb
module Operations::Bhphoto
  class SemanticSearch
    def self.call(params)
      query = params["query"]
      limit = (params["limit"] || 10).to_i

      query_embedding = EmbeddingService.embed(query)
      vector_json = query_embedding.to_json

      results = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          product_id,
          distance
        FROM product_vectors
        WHERE embedding MATCH '#{vector_json}'
        ORDER BY distance
        LIMIT #{limit}
      SQL

      product_ids = results.map { |r| r["product_id"] }
      products = Product.where(id: product_ids).includes(:product_specs).index_by(&:id)

      results.map do |r|
        product = products[r["product_id"]]
        next unless product
        {
          sku: product.sku,
          name: product.name,
          brand: product.brand,
          price: product.price,
          category: product.category,
          similarity: (1.0 - r["distance"]).round(4),
          description: product.description
        }
      end.compact
    end
  end
end
```

### 6. Hybrid Search: Semantic + Graph + Spec

The real power: combine all three search methods:

```ruby
# packs/partner_bhphoto/app/operations/bhphoto/hybrid_search.rb
module Operations::Bhphoto
  class HybridSearch
    def self.call(params)
      query = params["query"]
      constraints = params["constraints"] || {}

      # Step 1: Semantic search — find candidates by meaning
      semantic_results = SemanticSearch.call("query" => query, "limit" => 20)
      candidate_skus = semantic_results.map { |r| r[:sku] }

      # Step 2: Spec filter — apply hard constraints
      scope = Product.where(sku: candidate_skus).includes(:product_specs)
      scope = scope.where("price_cents <= ?", constraints["max_price"].to_i * 100) if constraints["max_price"]
      scope = scope.where(category: constraints["category"]) if constraints["category"]

      # Step 3: Graph enrichment — add relationships
      products = scope.to_a
      enriched = products.map do |product|
        semantic = semantic_results.find { |r| r[:sku] == product.sku }
        edges = ProductEdge.where(source_product: product).limit(5)
        tco = TcoCalculator.calculate(product, 
          years: constraints["years"]&.to_i || 3,
          pages_per_month: constraints["pages_per_month"]&.to_i || 500
        )

        {
          product: {
            sku: product.sku, name: product.name, brand: product.brand,
            price: product.price, category: product.category
          },
          semantic_similarity: semantic&.dig(:similarity),
          tco: tco,
          relationships: edges.map { |e| { type: e.edge_type, target: e.target_product&.sku, provenance: e.provenance } },
          provenance: {
            semantic: "INFERRED (cosine: #{semantic&.dig(:similarity)})",
            specs: "EXTRACTED (database)",
            tco: "COMPUTED (#{constraints['pages_per_month'] || 500}ppm, #{constraints['years'] || 3}yr)"
          }
        }
      end

      # Step 4: Rank by combined score
      enriched.sort_by { |r| -(r[:semantic_similarity] || 0) }
    end
  end
end
```

### 7. AI Agent Tool

```yaml
# Added to agents.yml
tools:
  - semantic_search:
      description: "Search products by natural language description (semantic similarity)"
      params: { query: "quiet color printer for photos", limit: 10 }
  - hybrid_search:
      description: "Combined semantic + spec + graph search with provenance"
      params: { query: "...", constraints: { max_price: 400, category: "printer" } }
```

## samma_esana Provenance for Semantic Search

Semantic search results are inherently probabilistic. The search discipline requires explicit marking:

```
AI response with semantic results:

"Based on your description 'quiet printer for photos,' the closest matches are:

1. Epson EcoTank ET-4850 (similarity: 0.87)
   [EXTRACTED: $349, ink tank, 0.3¢/page]
   [COMPUTED: 3yr TCO $485 at 500ppm]
   [SEMANTIC: matched on 'photo', 'color', 'home office' — cosine 0.87]

2. Canon MAXIFY GX7021 (similarity: 0.82)
   [EXTRACTED: $379, ink tank, 0.2¢/page]

Note: 'quiet' matched semantically but noise specs are not in database.
Noise level: UNKNOWN — check manufacturer spec sheet."
```

The degradation grammar applies: if a semantic match is based on description similarity but the specific claim (e.g., "quiet") isn't backed by a spec, say so.

## Quantization for Scale

For B&H's 400K products, use int8 quantization to reduce storage and speed up search:

```sql
-- Full precision: 400K × 384 floats × 4 bytes = 589 MB
-- int8 quantized: 400K × 384 × 1 byte = 147 MB
-- Binary:         400K × 384 / 8 = 18 MB (for coarse first-pass)

CREATE VIRTUAL TABLE product_vectors_int8 USING vec0(
  product_id INTEGER PRIMARY KEY,
  embedding int8[384]
);
```

Two-pass search for large catalogs:
1. Binary vectors → fast coarse ranking (top 1000)
2. float32 vectors → precise re-ranking (top 10)

## Files

| File | Action |
|------|--------|
| `Gemfile` | Add `sqlite-vec` gem (or load extension in initializer) |
| `config/initializers/sqlite_vec.rb` | NEW — load vec0 extension |
| `db/migrate/*_create_product_vectors.rb` | NEW — virtual table |
| `packs/partner_bhphoto/app/services/embedding_service.rb` | NEW — embed text via local model |
| `packs/partner_bhphoto/app/services/vector_indexer.rb` | NEW — index products |
| `packs/partner_bhphoto/app/operations/bhphoto/semantic_search.rb` | NEW |
| `packs/partner_bhphoto/app/operations/bhphoto/hybrid_search.rb` | NEW — semantic + graph + spec |
| `packs/partner_bhphoto/config/agents.yml` | Add semantic_search, hybrid_search tools |
| `lib/tasks/vectors.rake` | NEW — build/rebuild vector index |

## Verification

1. `sqlite-vec` extension loads: `SELECT vec_version()` returns version string
2. `EmbeddingService.embed("quiet printer")` returns 384-dimension float array
3. `VectorIndexer.index_all!` indexes all 7 products
4. `SemanticSearch.call("query" => "photo scanner")` returns V600 first (highest similarity)
5. `SemanticSearch.call("query" => "cheap high volume mono")` returns LaserJet or ET-2850
6. `HybridSearch.call("query" => "quiet color for home", "constraints" => {"max_price" => 400})` returns ranked results with provenance breakdown
7. Semantic results marked as `INFERRED` — AI doesn't assert semantic match as fact
8. Missing specs surfaced: "noise level: UNKNOWN"
