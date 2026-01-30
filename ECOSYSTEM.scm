;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - FormBD Position in Ecosystem
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "FormBD")
  (type "database")
  (purpose "Narrative-first, reversible, audit-grade database core")

  (position-in-ecosystem
    (category "data-storage")
    (subcategory "audit-grade-databases")
    (unique-value
      "Database internals as readable narrative artefacts"
      "Full reversibility guarantee"
      "Explainable constraint rejections"))

  (related-projects
    (projection-layer
      (project "formbd-geo")
      (relationship "projection-layer")
      (description "R-tree spatial indexing over FormBD documents")
      (synergy "Provides geospatial queries without compromising FormBD's auditability principles"))

    (projection-layer
      (project "formbd-analytics")
      (relationship "projection-layer")
      (description "Columnar OLAP analytics over FormBD documents")
      (synergy "Provides fast aggregations and PROMPT score analytics as materialized projections"))

    (sibling-standard
      (project "valence-shell")
      (relationship "sibling-standard")
      (description "Reversible shell with undo semantics")
      (synergy "Both prioritize reversibility; FormBD stores, Valence executes"))

    (sibling-standard
      (project "anamnesis")
      (relationship "sibling-standard")
      (description "Conversation knowledge extraction")
      (synergy "FormBD could be the persistent store for anamnesis memories"))

    (potential-consumer
      (project "git-hud")
      (relationship "potential-consumer")
      (description "Git repository governance")
      (synergy "FormBD for storing governance audit trails"))

    (potential-consumer
      (project "bofig")
      (relationship "potential-consumer")
      (description "Boundary objects and epistemological scoring")
      (synergy "FormBD for storing scored claims with provenance"))

    (potential-consumer
      (project "claim-forge")
      (relationship "potential-consumer")
      (description "IP registration and timestamping")
      (synergy "FormBD for immutable claim storage with audit trails"))

    (inspiration
      (project "datomic")
      (relationship "inspiration")
      (description "Immutable database with time-based queries")
      (differentiation "FormBD adds narrative rendering and reversibility guarantees"))

    (inspiration
      (project "event-sourcing")
      (relationship "inspiration")
      (description "Pattern of storing events, not state")
      (differentiation "FormBD makes events human/agent readable, not just machine processable")))

  (what-this-is
    "A database where storage internals are designed to be read"
    "An audit trail that explains itself"
    "A foundation for systems that need to prove their history"
    "A multi-model store with document and graph capabilities"
    "A teaching tool for understanding database internals")

  (what-this-is-not
    "A drop-in replacement for PostgreSQL or MySQL"
    "A high-performance OLAP solution (see formbd-analytics for analytics projections)"
    "A spatial database (see formbd-geo for geospatial projections)"
    "A distributed database (in PoC phase)"
    "A general-purpose NoSQL database"
    "A time-series optimized store"))
