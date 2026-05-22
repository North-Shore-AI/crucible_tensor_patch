defmodule CrucibleTensorPatch.Manifest do
  @moduledoc "Deterministic manifest emission for tensor patch outputs."

  @doc "Writes a pretty JSON manifest to `out_dir/manifest.json`."
  @spec write!(Path.t(), map()) :: Path.t()
  def write!(out_dir, manifest) do
    File.mkdir_p!(out_dir)
    path = Path.join(out_dir, "manifest.json")
    File.write!(path, Jason.encode!(manifest, pretty: true))
    path
  end

  @doc "Builds a deterministic manifest from operation reports."
  @spec build([map()], keyword()) :: map()
  def build(operation_reports, opts \\ []) when is_list(operation_reports) do
    %{
      "schema" => "crucible_tensor_patch_manifest.v1",
      "status" => status(operation_reports),
      "tensor_count" => length(operation_reports),
      "completed_count" => Enum.count(operation_reports, &(&1["status"] == "complete")),
      "export_complete" => Enum.all?(operation_reports, &(&1["status"] == "complete")),
      "source" => Keyword.get(opts, :source),
      "operations" => Enum.sort_by(operation_reports, & &1["id"])
    }
  end

  defp status(reports) do
    if Enum.all?(reports, &(&1["status"] == "complete")), do: "complete", else: "partial"
  end
end
