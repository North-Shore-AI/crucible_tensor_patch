defmodule CrucibleTensorPatch.LargeTensorPatchTest do
  use ExUnit.Case, async: false

  alias CrucibleTensorPatch.Plan

  @tag :large_tensor_patch
  test "fixture artifact manifest can seed a patch plan" do
    artifact_dir =
      System.get_env(
        "TRINITY_ARTIFACT_DIR",
        Path.expand("~/p/g/n/trinity_coordinator/priv/sakana_trinity/adapted_qwen3_0_6b_layer26")
      )

    manifest_path = Path.join(artifact_dir, "manifest.json")
    assert File.regular?(manifest_path)
    manifest = manifest_path |> File.read!() |> Jason.decode!()
    [entry | _] = Map.fetch!(manifest, "selected_tensors")

    assert {:ok, plan} =
             Plan.load(%{
               "schema" => "fixture.v1",
               "operations" => [
                 %{
                   "id" => Map.fetch!(entry, "artifact_key"),
                   "operation" => "identity",
                   "source_path" => Map.fetch!(entry, "artifact_key"),
                   "output_path" => Map.fetch!(entry, "checkpoint_path"),
                   "expected_shape" => Map.fetch!(entry, "shape")
                 }
               ]
             })

    assert length(plan.operations) == 1
  end
end
