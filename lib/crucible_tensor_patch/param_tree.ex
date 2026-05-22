defmodule CrucibleTensorPatch.ParamTree do
  @moduledoc "Patch nested parameter trees with shape/type/backend alignment."

  alias CrucibleTensorPatch.{BackendLabel, TensorPath}

  @field_atom_keys %{
    "artifact_key" => :artifact_key,
    "path" => :path,
    "segments" => :segments,
    "selected_tensors" => :selected_tensors
  }

  @doc "Applies manifest-selected tensors into a params tree."
  def patch!(params, manifest, tensors, opts \\ [])

  def patch!(%{data: data} = state, manifest, tensors, opts)
      when is_map(data) and is_map(manifest) and is_map(tensors) do
    %{state | data: patch!(data, manifest, tensors, opts)}
  end

  def patch!(params, manifest, tensors, opts)
      when is_map(params) and is_map(manifest) and is_map(tensors) do
    cast_tensors = Keyword.get(opts, :cast_tensors, true)

    Enum.reduce(selected_tensors(manifest), params, fn entry, acc ->
      path = field(entry, "path")
      key = field(entry, "artifact_key", path)
      tensor = Map.fetch!(tensors, key)
      segments = TensorPath.normalize(field(entry, "segments"), path)
      target = TensorPath.fetch!(acc, segments, path)
      patched = align_tensor_for_target!(tensor, target, cast_tensors, path)
      TensorPath.put!(acc, segments, patched, path)
    end)
  end

  @doc "Returns selected tensor entries from a manifest-like map."
  def selected_tensors(manifest) when is_map(manifest),
    do: field(manifest, "selected_tensors", [])

  defp align_tensor_for_target!(%Nx.Tensor{} = tensor, %Nx.Tensor{} = target, cast?, path) do
    target_type = Nx.type(target)
    target_shape = Nx.shape(target)
    target_backend = BackendLabel.from_label!(backend_label(target))

    if Nx.shape(tensor) != target_shape do
      raise ArgumentError,
            "adapted tensor #{inspect(path)} shape mismatch: expected #{inspect(target_shape)}, got #{inspect(Nx.shape(tensor))}"
    end

    align_tensor!(tensor, target_type, target_backend, cast?)
  end

  defp align_tensor!(tensor, target_type, target_backend, true) do
    tensor
    |> Nx.as_type(target_type)
    |> Nx.backend_transfer(target_backend)
  end

  defp align_tensor!(tensor, target_type, target_backend, false) do
    if Nx.type(tensor) != target_type do
      raise ArgumentError,
            "tensor type mismatch: expected #{inspect(target_type)}, got #{inspect(Nx.type(tensor))}"
    end

    Nx.backend_transfer(tensor, target_backend)
  end

  defp backend_label(%Nx.Tensor{data: %backend_struct{}} = tensor) do
    inspected = inspect(tensor)

    cond do
      String.contains?(inspected, "EXLA.Backend<cuda") -> "EXLA.Backend<cuda:"
      String.contains?(inspected, "EXLA.Backend<host") -> "EXLA.Backend<host:"
      String.contains?(inspected, "EXLA.Backend<") -> "EXLA.Backend"
      true -> backend_struct |> Module.split() |> Enum.join(".")
    end
  end

  defp field(map, key) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Map.fetch!(@field_atom_keys, key))
    end
  end

  defp field(map, key, default) when is_map(map) and is_binary(key) do
    case field(map, key) do
      nil -> default
      value -> value
    end
  end
end
