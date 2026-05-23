# Migration Notes

This repo was scaffolded during the monolith extraction so framework consumers
could resolve local path dependencies before the public GitHub repos existed.

Source material for the Phase 4 implementation:

- `nshkrdotcom/trinity_coordinator` tag `v0.1.0-monolith`
- source commit `64144a2983950e5fc9f2db2d26323a576c7379a1`
- `lib/trinity_coordinator/runtime/backend_label.ex`
- path traversal and param-tree patching portions of `lib/trinity_coordinator/sakana/artifact.ex`
- patch/export flow from `lib/trinity_coordinator/sakana/exporter.ex`

The implementation keeps the artifact runtime's product-specific loading and
model-head wiring out of this package. This repo owns reusable tensor patch
plans, path traversal, checksum/manifest output, resume behavior, and SVF-based
patch application.
