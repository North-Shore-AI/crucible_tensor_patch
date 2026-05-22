defmodule CrucibleTensorPatch.TensorPath do
  @moduledoc "Path normalization and traversal helpers for nested tensor containers."

  @doc "Normalizes stored segments or a dotted path into traversal segments."
  @spec normalize(term(), String.t() | nil) :: [term()]
  def normalize(nil, path) when is_binary(path), do: String.split(path, ".")

  def normalize(segments, _path) when is_list(segments) do
    Enum.map(segments, &normalize_segment/1)
  end

  def normalize(other, path) do
    raise ArgumentError, "invalid segments #{inspect(other)} for #{inspect(path)}"
  end

  @doc "Fetches a nested value by normalized segments."
  @spec fetch!(term(), [term()], String.t()) :: term()
  def fetch!(_container, [], path),
    do: raise(ArgumentError, "invalid segment path for #{inspect(path)}")

  def fetch!(container, segments, path) when is_list(segments) do
    Enum.reduce(segments, container, fn segment, acc -> fetch_child!(acc, segment, path) end)
  end

  @doc "Puts a nested value by normalized segments."
  @spec put!(term(), [term()], term(), String.t()) :: term()
  def put!(_container, [], _value, path),
    do: raise(ArgumentError, "cannot patch empty segment path for #{inspect(path)}")

  def put!(container, [segment], value, path), do: put_child!(container, segment, value, path)

  def put!(container, [segment | rest], value, path) do
    container
    |> fetch_child!(segment, path)
    |> put!(rest, value, path)
    |> then(&put_child!(container, segment, &1, path))
  end

  defp fetch_child!(container, segment, path) when is_map(container) do
    case resolve_map_key(container, segment) do
      nil -> raise ArgumentError, "missing path segment #{inspect(segment)} for #{inspect(path)}"
      resolved -> Map.fetch!(container, resolved)
    end
  end

  defp fetch_child!(container, segment, _path) when is_list(container) and is_integer(segment) do
    if valid_index?(segment, length(container)),
      do: Enum.at(container, segment),
      else: raise(ArgumentError, "missing list index #{inspect(segment)}")
  end

  defp fetch_child!(container, segment, _path) when is_tuple(container) and is_integer(segment) do
    if valid_index?(segment, tuple_size(container)),
      do: elem(container, segment),
      else: raise(ArgumentError, "missing tuple index #{inspect(segment)}")
  end

  defp fetch_child!(container, segment, path) do
    raise ArgumentError,
          "cannot descend into #{inspect(container)} at #{inspect(segment)} for #{inspect(path)}"
  end

  defp put_child!(container, segment, value, path) when is_map(container) do
    case resolve_map_key(container, segment) do
      nil -> raise ArgumentError, "missing map key #{inspect(segment)} for #{inspect(path)}"
      resolved -> Map.put(container, resolved, value)
    end
  end

  defp put_child!(container, segment, value, _path)
       when is_list(container) and is_integer(segment) do
    if valid_index?(segment, length(container)),
      do: List.update_at(container, segment, fn _ -> value end),
      else: raise(ArgumentError, "missing list index #{inspect(segment)}")
  end

  defp put_child!(container, segment, value, _path)
       when is_tuple(container) and is_integer(segment) do
    if valid_index?(segment, tuple_size(container)),
      do: put_elem(container, segment, value),
      else: raise(ArgumentError, "missing tuple index #{inspect(segment)}")
  end

  defp put_child!(container, segment, _value, path) do
    raise ArgumentError,
          "cannot patch #{inspect(path)} at #{inspect(segment)} in #{inspect(container)}"
  end

  defp valid_index?(segment, size), do: segment >= 0 and segment < size

  defp resolve_map_key(container, key) when is_map(container) do
    cond do
      Map.has_key?(container, key) -> key
      is_binary(key) -> existing_atom_map_key(container, key)
      is_atom(key) -> string_map_key(container, key)
      true -> nil
    end
  end

  defp existing_atom_map_key(container, key) do
    Enum.find(Map.keys(container), fn
      atom_key when is_atom(atom_key) -> Atom.to_string(atom_key) == key
      _ -> false
    end)
  end

  defp string_map_key(container, key) do
    string_key = Atom.to_string(key)
    if Map.has_key?(container, string_key), do: string_key
  end

  defp normalize_segment(value) when is_integer(value), do: value
  defp normalize_segment(value) when is_binary(value), do: parse_integer(value) || value
  defp normalize_segment(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
