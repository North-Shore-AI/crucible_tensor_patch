defmodule CrucibleTensorPatch.Plan do
  @moduledoc "Patch plan loading and validation."

  alias CrucibleTensorPatch.{Errors, Operation}

  @operations [:identity, :svf_apply]
  @operation_strings %{"identity" => :identity, "svf_apply" => :svf_apply}
  @field_atom_keys %{
    "checksum_policy" => :checksum_policy,
    "expected_dtype" => :expected_dtype,
    "expected_output_sha256" => :expected_output_sha256,
    "expected_shape" => :expected_shape,
    "id" => :id,
    "inputs" => :inputs,
    "metadata" => :metadata,
    "operation" => :operation,
    "operations" => :operations,
    "output_path" => :output_path,
    "schema" => :schema,
    "segments" => :segments,
    "source_path" => :source_path
  }

  @enforce_keys [:operations]
  defstruct [:source, :schema, operations: [], metadata: %{}]

  @type t :: %__MODULE__{
          source: Path.t() | nil,
          schema: String.t() | nil,
          operations: [Operation.t()],
          metadata: map()
        }

  @doc "Loads a plan from a JSON file path or a map."
  @spec load(Path.t() | map()) :: {:ok, t()} | {:error, Exception.t()}
  def load(path) when is_binary(path) do
    with {:ok, body} <- File.read(path),
         {:ok, decoded} <- Jason.decode(body),
         {:ok, plan} <- load(decoded) do
      {:ok, %{plan | source: path}}
    end
  rescue
    exception -> {:error, exception}
  end

  def load(plan) when is_map(plan) do
    {:ok, load!(plan)}
  rescue
    exception -> {:error, exception}
  end

  @doc "Loads a plan, raising on invalid input."
  @spec load!(map()) :: t()
  def load!(plan) when is_map(plan) do
    operations =
      plan
      |> field("operations", [])
      |> Enum.map(&operation!/1)

    %__MODULE__{
      schema: field(plan, "schema"),
      operations: operations,
      metadata: field(plan, "metadata", %{})
    }
  end

  defp operation!(raw) when is_map(raw) do
    operation = raw |> field("operation") |> normalize_operation!()

    %Operation{
      id: required!(raw, "id"),
      source_path: field(raw, "source_path"),
      output_path: required!(raw, "output_path"),
      operation: operation,
      inputs: field(raw, "inputs", %{}),
      segments: field(raw, "segments"),
      expected_shape: field(raw, "expected_shape"),
      expected_dtype: normalize_dtype(field(raw, "expected_dtype")),
      checksum_policy: normalize_checksum(field(raw, "checksum_policy", "sha256")),
      expected_output_sha256: field(raw, "expected_output_sha256"),
      metadata: field(raw, "metadata", %{})
    }
  end

  defp normalize_operation!(operation) when is_atom(operation) and operation in @operations,
    do: operation

  defp normalize_operation!(operation) when is_binary(operation) do
    case Map.fetch(@operation_strings, operation) do
      {:ok, atom} -> atom
      :error -> raise Errors, "unknown operation #{inspect(operation)}"
    end
  end

  defp normalize_operation!(operation),
    do: raise(Errors, "unknown operation #{inspect(operation)}")

  defp normalize_dtype(nil), do: nil
  defp normalize_dtype(dtype) when is_atom(dtype), do: dtype

  defp normalize_dtype(dtype) when is_binary(dtype),
    do: dtype |> String.downcase() |> String.to_existing_atom()

  defp normalize_checksum(nil), do: nil
  defp normalize_checksum(policy) when is_atom(policy), do: policy
  defp normalize_checksum("sha256"), do: :sha256

  defp normalize_checksum(policy),
    do: raise(Errors, "unsupported checksum policy #{inspect(policy)}")

  defp required!(map, key) do
    field(map, key) || raise Errors, "missing required plan key #{inspect(key)}"
  end

  defp field(map, key, default \\ nil) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(@field_atom_keys, key) do
          {:ok, atom_key} -> Map.get(map, atom_key, default)
          :error -> default
        end
    end
  end
end
