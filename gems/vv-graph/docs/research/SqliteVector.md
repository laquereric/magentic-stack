---
id: SqliteVector
kind: research
status: current
source:
  kind: snippet
  title: Sqlite Vector
---

AI Overview
SQLite is widely used for vector search through specialized extensions that allow it to store and query high-dimensional embeddings for AI and RAG (Retrieval-Augmented Generation) applications. 
YouTube
YouTube
 +1
Key SQLite Vector Extensions
The ecosystem is currently dominated by two primary community projects and a managed solution:
sqlite-vec: The active successor to sqlite-vss, written in pure C with zero dependencies.
Features: Supports float32, int8 (quantized), and bit (binary) vectors.
Distance Metrics: Includes L2 (Euclidean), L1 (Manhattan), cosine similarity, and Hamming distance.
Compatibility: Runs anywhere SQLite does, including MacOS, Linux, Windows, WASM, and Raspberry Pi.
SQLite-Vector: A cross-platform, ultra-efficient extension designed for blazing-fast performance and stable memory usage even with millions of vectors.
Turso (libSQL): A managed SQLite-based solution that provides native vector search capabilities out-of-the-box, allowing you to treat vectors as standard column types in a distributed environment. 
GitHub
GitHub
 +8
Technical Capabilities
Extensions like sqlite-vec transform SQLite into a lightweight vector database by adding: 
Virtual Tables: Users can create tables optimized for vector operations using modules like vec0_vtab.
K-Nearest Neighbor (KNN) Search: Performs similarity searches using standard SQL syntax:
sql
SELECT id FROM my_vectors 
WHERE vector MATCH ? 
ORDER BY distance LIMIT 5;
Use code with caution.
SIMD Acceleration: Uses hardware acceleration (AVX/NEON) to speed up distance calculations.
Quantization: Supports reducing vector size (e.g., to int8) to save disk space and improve scan speeds with minimal loss in accuracy. 
Hacker News
Hacker News
 +4
When to Use SQLite for Vectors
Local-First / On-Device AI: Ideal for mobile apps or desktop tools where data privacy is paramount and no internet connection is required.
Low Complexity: Best for projects that need relational metadata alongside vectors without the overhead of a dedicated server like Pinecone or Milvus.
Prototyping: Useful for small-to-medium datasets (up to a few million vectors) where a linear scan is "fast enough". 
YouTube
YouTube
 +5
Comparison of Popular Options
Feature 	sqlite-vec	SQLite-Vector	Turso
Status	Active (Successor to sqlite-vss)	Active	Native Cloud SQLite
Primary Language	C (Zero dependencies)	C++ / Cross-platform	Rust/C (libSQL)
Key Advantage	Extreme portability (WASM/Edge)	Performance/Efficiency	Distributed/Managed
Search Type	KNN (Linear scans)	KNN / ANN	Native Vector Columns
For developers using LangChain or Semantic Kernel, official connectors are available to integrate SQLite as a vector store. 
Microsoft Learn
Microsoft Learn
 +1