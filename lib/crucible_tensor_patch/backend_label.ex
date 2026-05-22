defmodule CrucibleTensorPatch.BackendLabel do
  @moduledoc "Recovers an Nx backend specifier from a stored backend label."

  require Logger

  @type backend_spec :: module() | {module(), keyword()}

  @doc "Returns `{:ok, backend_spec}` for known labels."
  @spec from_label(String.t()) ::
          {:ok, backend_spec()} | {:error, {:unknown_backend_label, String.t()}}
  def from_label("EXLA.Backend<cuda" <> _), do: {:ok, {EXLA.Backend, client: :cuda}}
  def from_label("EXLA.Backend<host" <> _), do: {:ok, {EXLA.Backend, client: :host}}
  def from_label("Nx.BinaryBackend"), do: {:ok, Nx.BinaryBackend}
  def from_label("EMLX.Backend" <> _), do: {:ok, {EMLX.Backend, device: :gpu}}
  def from_label(other) when is_binary(other), do: {:error, {:unknown_backend_label, other}}

  @doc "Returns a backend spec, falling back audibly to `Nx.BinaryBackend` for unknown labels."
  @spec from_label!(String.t()) :: backend_spec()
  def from_label!(label) when is_binary(label) do
    case from_label(label) do
      {:ok, backend_spec} ->
        backend_spec

      {:error, {:unknown_backend_label, ^label}} ->
        Logger.warning(
          "unknown backend label #{inspect(label)}, falling back to Nx.BinaryBackend"
        )

        Nx.BinaryBackend
    end
  end
end
