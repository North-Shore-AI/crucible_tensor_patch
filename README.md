<p align="center">
  <img src="assets/crucible_tensor_patch.svg" alt="CrucibleTensorPatch Logo" width="200px" />
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

## What It Provides

- `CrucibleTensorPatch.Plan` loads and validates patch plans from maps or JSON
  files.
- `CrucibleTensorPatch.Apply` applies identity and SVF patch operations and
  writes deterministic safetensors outputs.
- `CrucibleTensorPatch.ParamTree` patches nested parameter trees using manifest
  selected-tensor entries.
- `CrucibleTensorPatch.Manifest` emits deterministic operation manifests.
- `CrucibleTensorPatch.BackendLabel` round-trips known Nx/EXLA backend labels.
- `CrucibleTensorPatch.StageCheck` compares stage reports using shared tensor
  comparison behavior.

The package does not fetch models, load provider credentials, run coordination
loops, or own application runtime configuration.

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

## Plan Schema

A plan contains a `schema` string and an ordered `operations` list:

```elixir
plan_doc = %{
  "schema" => "example.v1",
  "operations" => [
    %{
      "id" => "copy_layer",
      "operation" => "identity",
      "source_path" => "layers.0.kernel",
      "output_path" => "layers/0000_kernel.safetensors",
      "expected_shape" => [2, 2],
      "expected_dtype" => "f32"
    }
  ]
}

{:ok, plan} = CrucibleTensorPatch.Plan.load(plan_doc)
```

Supported operations are:

- `"identity"`: copies a source tensor to a safetensors output.
- `"svf_apply"`: reconstructs a tensor from SVD/SVF components and scale
  offsets before writing the output.

Supported dtype strings are `bf16`, `f16`, `f32`, `i32`, and `i64`.

## Applying Identity Operations

```elixir
source = %{
  "layers.0.kernel" => Nx.tensor([[1.0, 2.0], [3.0, 4.0]], type: :f32)
}

{:ok, manifest} =
  CrucibleTensorPatch.Apply.apply(
    plan,
    source,
    "out/patch",
    force: false
  )
```

The result manifest includes operation status, output paths, skip state, and
SHA-256 checksums. `manifest.json` is written by default.

## Applying SVF Operations

SVF operations reference component tensors by name:

```elixir
operation = %{
  "id" => "svf_layer",
  "operation" => "svf_apply",
  "source_path" => "layers.0.kernel",
  "output_path" => "layers/0000_kernel.safetensors",
  "inputs" => %{
    "u" => "layer_0_u",
    "s" => "layer_0_s",
    "v" => "layer_0_v",
    "scale_offsets" => "layer_0_offsets"
  },
  "expected_shape" => [2, 2],
  "expected_dtype" => "f32"
}
```

Pass the component tensors through the `:components` option:

```elixir
CrucibleTensorPatch.Apply.apply(plan, source, "out/patch",
  components: %{
    "layer_0_u" => u,
    "layer_0_s" => s,
    "layer_0_v" => v,
    "layer_0_offsets" => offsets
  }
)
```

## Patching Parameter Trees

```elixir
patched =
  CrucibleTensorPatch.Apply.patch_params!(
    params,
    manifest,
    tensors,
    cast_tensors: true
  )
```

The patcher accepts maps or structs with a `:data` field. Manifest entries may
include explicit `segments`; otherwise the path string is split into traversal
segments.

## Resume And Force

When an operation has `expected_output_sha256` and the output file already
exists, the applier verifies the checksum and skips completed output. A checksum
mismatch raises. Pass `force: true` to rewrite outputs regardless of existing
files.

## CI

```sh
mix ci
```

Large local fixture checks are opt-in:

```sh
mkdir -p tmp
ln -s /path/to/artifact_bundle tmp/crucible_tensor_patch_fixture
mix test --only large_tensor_patch
```

`mix ci` runs dependency fetch, format check, warning-as-error compile, tests,
Credo strict, Dialyzer, and docs generation.
