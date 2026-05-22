defmodule CrucibleTensorPatch.Apply do
  @moduledoc "Applies tensor patch plans to source tensors."

  alias Crucible.Factorization.SVD
  alias CrucibleSafetensors.{Checksum, Writer}
  alias CrucibleTensorPatch.{Errors, Manifest, Operation, ParamTree, Plan, TensorPath}

  @doc "Applies a plan to source tensors and writes output safetensors."
  @spec apply(Plan.t(), map(), Path.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def apply(%Plan{} = plan, source_artifact, out_dir, opts \\ []) when is_map(source_artifact) do
    {:ok, apply!(plan, source_artifact, out_dir, opts)}
  rescue
    exception -> {:error, exception}
  end

  @doc "Applies a plan, raising on invalid input."
  @spec apply!(Plan.t(), map(), Path.t(), keyword()) :: map()
  def apply!(%Plan{} = plan, source_artifact, out_dir, opts \\ []) when is_map(source_artifact) do
    opts = Keyword.validate!(opts, components: %{}, force: false, write_manifest?: true)
    File.mkdir_p!(out_dir)

    reports =
      plan.operations
      |> Enum.map(fn operation -> apply_operation!(operation, source_artifact, out_dir, opts) end)

    manifest = Manifest.build(reports, source: plan.source)

    if opts[:write_manifest?] do
      Manifest.write!(out_dir, manifest)
    end

    manifest
  end

  @doc "Applies manifest-style adapted tensors into a params tree."
  defdelegate patch_params!(params, manifest, tensors, opts \\ []), to: ParamTree, as: :patch!

  defp apply_operation!(%Operation{} = operation, source_artifact, out_dir, opts) do
    output_path = Path.join(out_dir, operation.output_path)
    existing = existing_output_status(operation, output_path, opts)

    case existing do
      {:skip, report} ->
        report

      :write ->
        tensor = build_tensor!(operation, source_artifact, opts[:components])
        validate_tensor!(operation, tensor)
        write_tensor!(operation, output_path, tensor)
    end
  end

  defp existing_output_status(operation, output_path, opts) do
    cond do
      opts[:force] ->
        :write

      File.regular?(output_path) and is_binary(operation.expected_output_sha256) ->
        actual = Checksum.file_sha256!(output_path)

        if actual == operation.expected_output_sha256 do
          {:skip, report(operation, output_path, actual, "complete", true)}
        else
          raise Errors,
                "resume checksum mismatch for #{operation.id}: expected #{operation.expected_output_sha256}, got #{actual}"
        end

      true ->
        :write
    end
  end

  defp build_tensor!(%Operation{operation: :identity} = operation, source_artifact, _components) do
    fetch_source_tensor!(source_artifact, operation)
  end

  defp build_tensor!(%Operation{operation: :svf_apply} = operation, source_artifact, components) do
    source = fetch_source_tensor!(source_artifact, operation)
    inputs = operation.inputs || %{}

    decomposition = %{
      u: fetch_input!(inputs, components, "u"),
      s: fetch_input!(inputs, components, "s"),
      v: fetch_input!(inputs, components, "v")
    }

    offsets = fetch_input!(inputs, components, "scale_offsets")

    decomposition
    |> SVD.reconstruct(Nx.as_type(offsets, Nx.type(decomposition.s)))
    |> Nx.as_type(Nx.type(source))
  end

  defp fetch_source_tensor!(source_artifact, operation) do
    cond do
      operation.source_path && Map.has_key?(source_artifact, operation.source_path) ->
        Map.fetch!(source_artifact, operation.source_path)

      operation.segments ->
        source_artifact
        |> TensorPath.fetch!(
          TensorPath.normalize(operation.segments, operation.source_path),
          operation.source_path
        )

      operation.source_path ->
        source_artifact
        |> TensorPath.fetch!(
          TensorPath.normalize(nil, operation.source_path),
          operation.source_path
        )

      true ->
        raise Errors, "operation #{operation.id} has no source_path"
    end
  end

  defp fetch_input!(inputs, components, name) do
    value = Map.get(inputs, name) || Map.get(inputs, String.to_atom(name))

    cond do
      match?(%Nx.Tensor{}, value) -> value
      is_binary(value) -> Map.fetch!(components, value)
      true -> raise Errors, "missing input #{inspect(name)}"
    end
  end

  defp validate_tensor!(operation, %Nx.Tensor{} = tensor) do
    expected_shape = normalize_shape(operation.expected_shape)

    if expected_shape && Nx.shape(tensor) != expected_shape do
      raise Errors,
            "operation #{operation.id} shape mismatch: expected #{inspect(expected_shape)}, got #{inspect(Nx.shape(tensor))}"
    end

    if operation.expected_dtype &&
         normalize_dtype(Nx.type(tensor)) != normalize_dtype(operation.expected_dtype) do
      raise Errors,
            "operation #{operation.id} dtype mismatch: expected #{inspect(operation.expected_dtype)}, got #{inspect(Nx.type(tensor))}"
    end

    :ok
  end

  defp write_tensor!(operation, output_path, tensor) do
    Writer.write!(%{operation.id => tensor_payload(tensor)}, output_path)
    checksum = Checksum.file_sha256!(output_path)
    report(operation, output_path, checksum, "complete", false)
  end

  defp tensor_payload(%Nx.Tensor{} = tensor) do
    host = Nx.backend_transfer(tensor, Nx.BinaryBackend)

    %{
      dtype: writer_dtype!(Nx.type(host)),
      shape: host |> Nx.shape() |> Tuple.to_list(),
      data: Nx.to_binary(host)
    }
  end

  defp report(operation, output_path, checksum, status, skipped?) do
    %{
      "id" => operation.id,
      "operation" => Atom.to_string(operation.operation),
      "source_path" => operation.source_path,
      "output_path" => output_path,
      "status" => status,
      "skipped" => skipped?,
      "sha256" => checksum
    }
  end

  defp writer_dtype!({:f, 16}), do: :f16
  defp writer_dtype!({:bf, 16}), do: :bf16
  defp writer_dtype!({:f, 32}), do: :f32
  defp writer_dtype!({:s, 32}), do: :i32
  defp writer_dtype!({:s, 64}), do: :i64
  defp writer_dtype!(type), do: raise(Errors, "unsupported output dtype #{inspect(type)}")

  defp normalize_shape(nil), do: nil
  defp normalize_shape(shape) when is_tuple(shape), do: shape
  defp normalize_shape(shape) when is_list(shape), do: List.to_tuple(shape)
  defp normalize_dtype({:f, 16}), do: "f16"
  defp normalize_dtype({:bf, 16}), do: "bf16"
  defp normalize_dtype({:f, 32}), do: "f32"
  defp normalize_dtype({:s, 32}), do: "i32"
  defp normalize_dtype({:s, 64}), do: "i64"
  defp normalize_dtype(dtype) when is_atom(dtype), do: Atom.to_string(dtype)
  defp normalize_dtype(dtype), do: inspect(dtype)
end
