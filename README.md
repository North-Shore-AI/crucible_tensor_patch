<p align="center">
  <img src="assets/crucible_tensor_patch.svg" alt="CrucibleTensorPatch Logo" width="120px" />
</p>

# CrucibleTensorPatch

<p align="center">
  <a href="https://github.com/North-Shore-AI/crucible_tensor_patch/actions/workflows/ci.yml">
    <img src="https://github.com/North-Shore-AI/crucible_tensor_patch/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI Status" />
  </a>
  <a href="https://github.com/North-Shore-AI/crucible_tensor_patch/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/North-Shore-AI/crucible_tensor_patch" alt="GitHub License" />
  </a>
</p>

Deterministic tensor patch plans and patch application for model surgery.

The package owns generic patch behavior: plan parsing, tensor path traversal,
identity and SVF patch operations, manifest/checksum emission, resume/force
rules, backend label round trips, and stage comparison. It intentionally avoids
provider, tracing, and orchestration dependencies.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `crucible_tensor_patch` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_tensor_patch, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/crucible_tensor_patch>.

## CI

```sh
mix ci
```

Large local fixture checks are opt-in:

```sh
TRINITY_ARTIFACT_DIR=~/p/g/n/trinity_coordinator/priv/sakana_trinity/adapted_qwen3_0_6b_layer26 \
  mix test --only large_tensor_patch
```
