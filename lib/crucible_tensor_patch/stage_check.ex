defmodule CrucibleTensorPatch.StageCheck do
  @moduledoc "Stage comparison wrapper for tensor patch reports."

  alias Crucible.Factorization.StageCheck, as: FactorizationStageCheck

  @doc "Compares plan stages from two reports."
  @spec compare(map(), map(), map() | keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def compare(plan, reference_report, observed_report) do
    {:ok, compare!(plan, reference_report, observed_report)}
  rescue
    exception -> {:error, exception}
  end

  @doc "Compares plan stages, raising on invalid input."
  def compare!(plan, reference_report, observed_report) do
    checks =
      FactorizationStageCheck.compare_stage_tensors(
        stages(observed_report),
        stages(reference_report),
        include_alt_hashes: false,
        include_tensor_summaries: false
      )

    %{
      "schema" => "crucible_tensor_patch_stage_report.v1",
      "plan_schema" => Map.get(plan, "schema") || Map.get(plan, :schema),
      "checks" => checks,
      "functional_passed" => FactorizationStageCheck.checks_passed?(checks)
    }
  end

  defp stages(%{"stages" => stages}) when is_map(stages), do: stages
  defp stages(%{stages: stages}) when is_map(stages), do: stages
  defp stages(stages) when is_map(stages), do: stages
end
