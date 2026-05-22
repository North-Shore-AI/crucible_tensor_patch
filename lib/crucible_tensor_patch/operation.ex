defmodule CrucibleTensorPatch.Operation do
  @moduledoc "One tensor patch operation in a patch plan."

  @enforce_keys [:id, :operation, :output_path]
  defstruct [
    :id,
    :source_path,
    :output_path,
    :operation,
    :inputs,
    :segments,
    :expected_shape,
    :expected_dtype,
    :checksum_policy,
    :expected_output_sha256,
    metadata: %{}
  ]

  @type operation :: :identity | :svf_apply

  @type t :: %__MODULE__{
          id: String.t(),
          source_path: String.t() | nil,
          output_path: String.t(),
          operation: operation(),
          inputs: map() | nil,
          segments: [term()] | nil,
          expected_shape: [non_neg_integer()] | nil,
          expected_dtype: atom() | nil,
          checksum_policy: :sha256 | nil,
          expected_output_sha256: String.t() | nil,
          metadata: map()
        }
end
