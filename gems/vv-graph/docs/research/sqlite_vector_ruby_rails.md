# SQLite as a Vector Store for Ruby and Rails LLM Applications

*By Manus AI — July 2026*

---

## Introduction

The Rails 8 release marked a turning point in how the Ruby community thinks about SQLite. What was once considered a toy database suitable only for development and testing is now a legitimate production choice for single-server deployments, backed by significant improvements to the Rails SQLite adapter and a growing ecosystem of extensions. Nowhere is this shift more consequential for AI applications than in vector search: the ability to store and query high-dimensional embeddings for Retrieval-Augmented Generation (RAG) pipelines without introducing a separate database server.

This document provides a comprehensive reference for Ruby and Rails developers who want to understand the full landscape of SQLite-based vector stores, covering the available extensions, their Ruby integration paths, practical implementation patterns, embedding model choices, and the trade-offs that determine when SQLite is the right tool for the job.

---

## Why SQLite for Vector Search?

A RAG pipeline requires three things: a way to generate embeddings, a place to store them, and a mechanism to retrieve the most semantically similar ones at query time. The dominant choice in the Rails ecosystem has been PostgreSQL with the `pgvector` extension, which is mature, well-supported, and capable of handling millions of vectors. However, PostgreSQL requires a running server process, connection pooling, and operational overhead that is disproportionate for many use cases.

SQLite, by contrast, is an embedded database that lives entirely within the application process. It requires no server, no network configuration, and no separate deployment concern. For a personal blog, an internal tool, a small SaaS product, or any application that comfortably fits on a single server, SQLite eliminates an entire layer of infrastructure. The Rails 8 ecosystem has leaned into this with the Solid suite of gems (`solid_cache`, `solid_queue`, `solid_cable`), and the vector search story has followed the same trajectory.

The trade-off is scale. SQLite is a single-writer database, and the current leading vector extension (`sqlite-vec`) performs only brute-force exact nearest-neighbor search with no ANN index. For datasets of up to a few hundred thousand vectors, this is entirely acceptable. Beyond that threshold, PostgreSQL with `pgvector` and its HNSW or IVFFlat indexes remains the better choice.

---

## The SQLite Vector Extension Landscape

Four distinct extensions address vector search in SQLite. They differ substantially in maturity, Ruby support, query model, and performance characteristics.

### `sqlite-vec` — The Recommended Choice

**`sqlite-vec`** is the current standard, actively maintained by Alex Garcia. It is written in pure C with no external dependencies, runs on every platform that SQLite supports (Linux, macOS, Windows, Raspberry Pi, and even WASM in the browser), and is dual-licensed under MIT and Apache 2.0 [1].

The extension exposes vector data through `vec0` virtual tables. Vectors are stored in a separate virtual table rather than alongside regular columns, and similarity queries use a `MATCH` operator with a `k` parameter for the number of nearest neighbors:

```sql
SELECT rowid, distance
FROM document_vectors
WHERE embedding MATCH '[0.1, 0.2, ...]'
AND k = 5;
```

The extension supports `float32`, `int8`, and binary vector formats, and distance metrics include cosine, Euclidean (L2), and inner product. The key limitation is that all searches are **brute-force exact KNN** — there is no approximate nearest neighbor index, meaning query time scales linearly with the number of stored vectors. The author has indicated that ANN indexing is planned but not yet available.

### `Vec1` — SQLite's Official Extension

**Vec1** is the vector extension developed by the SQLite project itself, available at `sqlite.org/vec1`. Unlike `sqlite-vec`, Vec1 supports **approximate nearest neighbor (ANN) search**, making it significantly faster for large datasets. It also uses a virtual table interface and is supported by the `neighbor` gem through a custom initializer.

The trade-off is installation complexity. Vec1 must be compiled from source, which adds a build step to the deployment process. There is no pre-packaged Ruby gem equivalent to `sqlite-vec`, so teams must manage the compiled shared library themselves.

### `sqlite-vss` — Deprecated, Do Not Use

**`sqlite-vss`** was the original SQLite vector extension, built on Meta's Faiss C++ library. It had a Ruby gem (`gem install sqlite-vss`) and was the first option available to Ruby developers. The author has since officially deprecated it in favour of `sqlite-vec`, citing integration difficulties with the Faiss dependency [2].

`sqlite-vss` had several hard limitations: Faiss indexes were capped at 1 GB, `UPDATE` statements on virtual tables were unsupported, and installation required native Linux libraries (`libgomp1`, `libatlas-base-dev`, `liblapack-dev`). Any existing code using `sqlite-vss` should be migrated to `sqlite-vec`.

### `sqlite-vector` — A Newer Contender

**`sqlite-vector`** (by SQLite AI) takes a different architectural approach: vectors are stored as BLOBs in **ordinary table columns** rather than virtual tables. This makes the schema feel more natural and eliminates the join required by `sqlite-vec`'s virtual table model.

Performance benchmarks on 100,000 vectors of 384 dimensions show compelling results compared to `sqlite-vec` [3]:

| Metric | `sqlite-vec` | `sqlite-vector` |
|---|---|---|
| Insert time | 1,179 ms | 563 ms (~50% faster) |
| Full-scan query time | 67.8 ms | 56.7 ms (~16% faster) |
| With 8-bit quantization + preload | — | 3.97 ms (~17× faster) |
| Memory usage (100k vectors) | Higher | ~37 MB |

`sqlite-vector` supports quantization (FLOAT32, FLOAT16, BFLOAT16, INT8, UINT8) and selects hardware-specific distance functions at runtime. The significant drawback for Ruby developers is that **there is no dedicated Ruby gem** yet. Integration requires manually loading the compiled extension, and there is no ActiveRecord or `neighbor` gem support. It is free for open-source projects.

### Extension Comparison Summary

| Extension | Ruby Gem | ANN Index | Storage Model | Status |
|---|---|---|---|---|
| **sqlite-vec** | `sqlite-vec` + `neighbor` | No (exact KNN) | Virtual table (`vec0`) | **Active — recommended** |
| **Vec1** | Via `neighbor` initializer | Yes | Virtual table | Active — requires source build |
| **sqlite-vss** | `sqlite-vss` | Yes (Faiss) | Virtual table (`vss0`) | **Deprecated** |
| **sqlite-vector** | None | No (optimised brute-force) | Ordinary columns (BLOB) | Active — no Rails gem |

---

## Ruby and Rails Integration

### The `neighbor` Gem

The `neighbor` gem (by Andrew Kane) is the primary bridge between SQLite vector extensions and ActiveRecord. It provides the `has_neighbors` model macro, the `nearest_neighbors` query method, and Rails generators for scaffolding migrations. The same gem also supports PostgreSQL (`pgvector` and `cube`), MariaDB, and MySQL, making it possible to use an identical application-layer API regardless of the underlying database [4].

#### Setting Up `sqlite-vec` with Rails

**Step 1: Add gems to the Gemfile.**

```ruby
gem "sqlite-vec"
gem "neighbor"
```

**Step 2: Configure the initializer.** The `neighbor` gem needs to know which SQLite extension to load.

```ruby
# config/initializers/neighbor.rb
Neighbor::SQLite.initialize!
```

**Step 3: Generate the migration.** The `neighbor` gem provides a generator that creates the necessary migration for the `sqlite-vec` extension.

```shell
rails generate neighbor:sqlite
rails db:migrate
```

**Step 4: Create the virtual table.** For each model that needs vector search, create a companion virtual table. The Rails 8 `create_virtual_table` helper makes this idiomatic:

```ruby
class CreateDocumentVectors < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table :document_vectors, :vec0, [
      "document_id integer primary key",
      "embedding float[1536] distance_metric=cosine"
    ]
  end
end
```

**Step 5: Define the model.** Create a companion model for the virtual table and declare the `has_neighbors` relationship.

```ruby
class DocumentVector < ApplicationRecord
  self.primary_key = "document_id"
  has_neighbors :embedding, dimensions: 1536
end

class Document < ApplicationRecord
  has_one :document_vector

  def similar(limit = 5)
    Document
      .joins(:document_vector)
      .merge(
        DocumentVector.nearest_neighbors(:embedding, document_vector.embedding, distance: "cosine")
      )
      .where.not(id: id)
      .first(limit)
  end
end
```

**Step 6: Generate and store embeddings.** Embeddings can be generated via any API or local model and stored asynchronously using a background job.

```ruby
class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    embedding = EmbeddingService.generate(document.content)

    DocumentVector.upsert(
      { document_id: document.id, embedding: embedding },
      unique_by: :document_id
    )
  end
end
```

**Step 7: Query for nearest neighbors.**

```ruby
# Find the 5 most similar documents to a query string
query_embedding = EmbeddingService.generate("How do I deploy a Rails app?")
results = DocumentVector
  .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
  .first(5)
  .map(&:document)
```

#### Setting Up Vec1 with Rails

Vec1 requires the compiled shared library to be present on the server. Once available, the `neighbor` gem loads it via the initializer:

```ruby
# config/initializers/neighbor.rb
Neighbor::SQLite.initialize!(extension: "/usr/local/lib/vec1.so")
```

The migration and model setup are identical to the `sqlite-vec` path, as the `neighbor` gem abstracts the underlying extension.

#### Direct `sqlite-vec` Usage (Without Rails)

For non-Rails Ruby scripts or CLI tools, the `sqlite-vec` gem can be loaded directly into any `SQLite3::Database` connection:

```ruby
require 'sqlite3'
require 'sqlite_vec'

db = SQLite3::Database.new('vectors.db')
db.enable_load_extension(true)
SqliteVec.load(db)
db.enable_load_extension(false)

# Vectors must be packed as binary blobs
embedding = [0.1, 0.2, 0.3, 0.4]
packed = embedding.pack("f*")

db.execute("SELECT vec_length(?)", [packed]) # => [[4]]
```

---

## Embedding Model Options

SQLite vector search is database-agnostic with respect to embedding models. Any model that produces a fixed-length float array can be used. The choice of model determines the vector dimension, which must match the `float[N]` declaration in the virtual table schema.

### API-Based Models

The simplest option is to call an external embedding API. OpenAI's `text-embedding-3-small` (1,536 dimensions) is the most widely used in the Ruby community and is accessible via the `ruby-openai` gem or through the `RubyLLM.embed` method:

```ruby
# Via ruby-openai
client = OpenAI::Client.new
response = client.embeddings(
  parameters: { model: "text-embedding-3-small", input: "text to embed" }
)
embedding = response.dig("data", 0, "embedding")

# Via RubyLLM
embedding = RubyLLM.embed("text to embed").vectors
```

The trade-off is cost and latency: every embedding call incurs an API fee and a network round-trip. For bulk ingestion, embedding calls should be batched and run in background jobs.

### Local Models via the `informers` Gem

For applications requiring data privacy or zero marginal cost per embedding, the `informers` gem runs ONNX transformer models directly in the Ruby process. It supports a wide range of sentence-transformer models from Hugging Face:

```ruby
require "informers"

model = Informers.pipeline("embedding", "sentence-transformers/all-MiniLM-L6-v2")
# Produces 384-dimensional vectors
embedding = model.("text to embed")
```

Popular models and their dimensions for use with `sqlite-vec`:

| Model | Dimensions | Notes |
|---|---|---|
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | Fast, lightweight, good general-purpose |
| `sentence-transformers/all-mpnet-base-v2` | 768 | Higher quality, slower |
| `BAAI/bge-base-en-v1.5` | 768 | Strong retrieval performance |
| `nomic-ai/nomic-embed-text-v1` | 768 | Long context support (8,192 tokens) |
| `Snowflake/snowflake-arctic-embed-m-v1.5` | 768 | Strong on retrieval benchmarks |
| `google/embeddinggemma-300m` | 768 | Google's lightweight open model |

The `informers` gem also supports **reranking models**, which can be used as a post-retrieval step to re-score and re-order the candidates returned by the vector search before passing them to the LLM.

### Local Models via a Sidecar Service

For teams that prefer Python's `sentence-transformers` library but want to keep the Rails application in Ruby, a common pattern is to run a small embedding microservice as a Docker container alongside the Rails app. The Rails application calls the sidecar over HTTP to generate embeddings:

```ruby
class EmbeddingService
  SIDECAR_URL = ENV.fetch("EMBEDDING_SERVICE_URL", "http://localhost:8765")

  def self.generate(text)
    response = Faraday.post(
      "#{SIDECAR_URL}/embed",
      { query: text }.to_json,
      "Content-Type" => "application/json"
    )
    JSON.parse(response.body)["embedding"]
  end
end
```

This pattern was used in a March 2026 production deployment of a Rails blog with `sqlite-vec`, using Google's EmbeddingGemma 300M model served from a Docker container. The system ran on a 6 GB RAM, 2-vCPU VM and achieved a median end-to-end search latency of approximately 2.7 seconds, which the author found acceptable for their scale [5].

---

## Building a Complete RAG Pipeline with SQLite

The following walkthrough assembles all the components into a minimal but complete RAG pipeline using `sqlite-vec`, `neighbor`, and `ruby-openai`.

### Schema

```ruby
# db/migrate/..._create_documents.rb
class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.text :content, null: false
      t.string :source
      t.timestamps
    end

    create_virtual_table :document_vectors, :vec0, [
      "document_id integer primary key",
      "embedding float[1536] distance_metric=cosine"
    ]
  end
end
```

### Models

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  has_one :document_vector
  after_create_commit :schedule_embedding

  private

  def schedule_embedding
    GenerateEmbeddingJob.perform_later(id)
  end
end

# app/models/document_vector.rb
class DocumentVector < ApplicationRecord
  self.primary_key = "document_id"
  has_neighbors :embedding, dimensions: 1536
end
```

### Embedding Job

```ruby
# app/jobs/generate_embedding_job.rb
class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    client   = OpenAI::Client.new

    response  = client.embeddings(
      parameters: { model: "text-embedding-3-small", input: document.content }
    )
    embedding = response.dig("data", 0, "embedding")

    DocumentVector.upsert(
      { document_id: document.id, embedding: embedding },
      unique_by: :document_id
    )
  end
end
```

### RAG Query Service

```ruby
# app/services/rag_query_service.rb
class RagQueryService
  TOP_K = 5

  def initialize(question)
    @question  = question
    @client    = OpenAI::Client.new
  end

  def call
    context   = retrieve_context
    generate_answer(context)
  end

  private

  def retrieve_context
    query_embedding = embed(@question)

    DocumentVector
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .first(TOP_K)
      .map { |dv| Document.find(dv.document_id).content }
      .join("\n\n---\n\n")
  end

  def generate_answer(context)
    prompt = <<~PROMPT
      Answer the following question using only the provided context.
      If the context does not contain enough information, say so.

      Context:
      #{context}

      Question: #{@question}
    PROMPT

    response = @client.chat(
      parameters: {
        model:    "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }]
      }
    )
    response.dig("choices", 0, "message", "content")
  end

  def embed(text)
    response = @client.embeddings(
      parameters: { model: "text-embedding-3-small", input: text }
    )
    response.dig("data", 0, "embedding")
  end
end
```

### Usage

```ruby
# Ingest documents
Document.create!(content: "Rails 8 ships with Solid Queue for background jobs.", source: "rails_8_release_notes")
Document.create!(content: "SQLite is now a production-ready database in Rails 8.", source: "rails_8_release_notes")

# Query
answer = RagQueryService.new("What background job system ships with Rails 8?").call
puts answer
# => "Rails 8 ships with Solid Queue for background jobs."
```

---

## Hybrid Search: Combining FTS5 and Vector Search

SQLite ships with a mature full-text search extension, **FTS5**, which provides BM25-ranked keyword search. For production RAG applications, combining FTS5 keyword search with `sqlite-vec` semantic search via Reciprocal Rank Fusion (RRF) often yields better retrieval than either approach alone.

```ruby
class HybridSearchService
  def initialize(query)
    @query     = query
    @embedding = EmbeddingService.generate(query)
  end

  def search(limit: 10)
    keyword_results = keyword_search(limit: limit * 2)
    vector_results  = vector_search(limit: limit * 2)

    reciprocal_rank_fusion(keyword_results, vector_results, limit: limit)
  end

  private

  def keyword_search(limit:)
    Document.where("content MATCH ?", @query).limit(limit).pluck(:id)
  end

  def vector_search(limit:)
    DocumentVector
      .nearest_neighbors(:embedding, @embedding, distance: "cosine")
      .first(limit)
      .map(&:document_id)
  end

  def reciprocal_rank_fusion(*result_lists, limit:, k: 60)
    scores = Hash.new(0.0)

    result_lists.each do |list|
      list.each_with_index do |id, rank|
        scores[id] += 1.0 / (k + rank + 1)
      end
    end

    scores.sort_by { |_, score| -score }.first(limit).map(&:first)
  end
end
```

---

## Production Considerations

### Deployment with Kamal

Because `sqlite-vec` is distributed as a pre-compiled Ruby gem with native extensions, no additional system packages are required. The gem installs cleanly as part of `bundle install` within a standard Docker build. For Kamal deployments, the database file and the Rails application share the same container or volume, which is the standard SQLite-on-Rails deployment pattern.

If using a sidecar embedding service, Kamal's accessory configuration can manage the Docker container lifecycle alongside the main application.

### Asynchronous Embedding with Solid Queue

Rails 8's `solid_queue` gem, backed by SQLite, provides a natural companion for managing embedding jobs. The entire stack — application, vector store, job queue, cache, and Action Cable — can run on a single SQLite database file (or multiple files on the same server), eliminating all external service dependencies:

```ruby
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "default"
      threads: 3
```

### Scaling Limits

The practical upper bound for `sqlite-vec` brute-force search depends on vector dimensions and acceptable query latency. As a rough guideline, 100,000 vectors at 768 dimensions complete a full scan in approximately 68 ms on a modern laptop CPU [3]. For a web application serving interactive queries, a dataset of up to 500,000 vectors is generally manageable with brute-force search. Beyond that, migrating to PostgreSQL with `pgvector` and an HNSW index, or switching to Vec1 for ANN support, is advisable.

---

## Choosing the Right SQLite Vector Extension

| Scenario | Recommendation |
|---|---|
| New Rails 8 project, small-to-medium dataset | `sqlite-vec` gem + `neighbor` gem — the simplest, best-supported path |
| Need ANN indexing for larger datasets on SQLite | Vec1 extension + `neighbor` gem (accept the source-build overhead) |
| Migrating from existing `sqlite-vss` code | Replace with `sqlite-vec` immediately; the APIs differ but the migration is straightforward |
| Maximum raw query performance, comfortable with manual setup | Evaluate `sqlite-vector`; no Rails gem yet, but significantly faster with quantization |
| Dataset exceeds ~500k vectors or multi-writer concurrency required | Move to PostgreSQL + `pgvector`; SQLite's single-writer model becomes a bottleneck |

---

## References

[1] Garcia, A. (2024). asg017/sqlite-vec. GitHub. https://github.com/asg017/sqlite-vec
[2] Garcia, A. (2023). asg017/sqlite-vss. GitHub. https://github.com/asg017/sqlite-vss
[3] Bambini, M. (2025). The State of Vector Search in SQLite. https://marcobambini.substack.com/p/the-state-of-vector-search-in-sqlite
[4] ankane. (2021). ankane/neighbor. GitHub. https://github.com/ankane/neighbor
[5] Posaceanu, M. (2026). Semantic search in Rails using sqlite-vec, Kamal and Docker. https://marianposaceanu.com/articles/semantic-search-in-rails-using-sqlite-vec-kamal-and-docker
[6] Alvarez, S. (2024). Vector search with Rails and SQLite. Telos Labs. https://www.teloslabs.co/post/vector-search-with-rails-and-sqlite/
[7] SQLite.org. (2025). Vec1 Vector Extension. https://sqlite.org/vec1
