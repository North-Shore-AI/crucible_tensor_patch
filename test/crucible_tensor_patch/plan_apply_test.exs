defmodule CrucibleTensorPatch.PlanApplyTest do
  use ExUnit.Case, async: true

  alias CrucibleTensorPatch.{Apply, BackendLabel, Errors, ParamTree, Plan, StageCheck}

  test "Plan.load/1 parses operations" do
    assert {:ok, plan} =
             Plan.load(%{
               "schema" => "test.v1",
               "operations" => [
                 %{
                   "id" => "copy",
                   "operation" => "identity",
                   "source_path" => "layer.kernel",
                   "output_path" => "copy.safetensors",
                   "expected_shape" => [1, 2],
                   "expected_dtype" => "f32"
                 }
               ]
             })

    assert [operation] = plan.operations
    assert operation.operation == :identity
    assert operation.expected_dtype == :f32
  end

  test "Plan.load/1 rejects unknown operations" do
    assert {:error, %Errors{message: message}} =
             Plan.load(%{
               "operations" => [%{"id" => "x", "operation" => "bogus", "output_path" => "x"}]
             })

    assert message =~ "unknown operation"
  end

  test "Apply.apply/4 writes identity patches and deterministic manifest" do
    dir = tmp_dir()
    source = %{"layer.kernel" => Nx.tensor([[1.0, 2.0]], type: :f32)}

    {:ok, plan} =
      Plan.load(%{"operations" => [identity_op("copy", "layer.kernel", "copy.safetensors")]})

    assert {:ok, manifest} = Apply.apply(plan, source, dir)

    assert manifest["status"] == "complete"
    assert manifest["tensor_count"] == 1
    assert File.regular?(Path.join(dir, "copy.safetensors"))
    assert File.regular?(Path.join(dir, "manifest.json"))
  end

  test "Apply.apply/4 applies rank-1 SVF patch" do
    dir = tmp_dir()
    source = %{"layer.kernel" => Nx.tensor([[2.0, 4.0], [1.0, 2.0]], type: :f32)}

    decomp =
      CrucibleFactorization.SVD.decompose_tensor(source["layer.kernel"], compute_type: :f32)

    offsets = Nx.broadcast(0.0, {Nx.axis_size(decomp.s, 0)})

    {:ok, plan} =
      Plan.load(%{
        "operations" => [
          %{
            "id" => "svf",
            "operation" => "svf_apply",
            "source_path" => "layer.kernel",
            "output_path" => "svf.safetensors",
            "inputs" => %{"u" => "u", "s" => "s", "v" => "v", "scale_offsets" => "offsets"},
            "expected_shape" => [2, 2],
            "expected_dtype" => "f32"
          }
        ]
      })

    assert {:ok, manifest} =
             Apply.apply(plan, source, dir,
               components: %{
                 "u" => decomp.u,
                 "s" => decomp.s,
                 "v" => decomp.v,
                 "offsets" => offsets
               }
             )

    assert [%{"status" => "complete"}] = manifest["operations"]
  end

  test "Apply.apply/4 supports resume and force" do
    dir = tmp_dir()
    source = %{"layer.kernel" => Nx.tensor([[1.0, 2.0]], type: :f32)}

    {:ok, plan} =
      Plan.load(%{"operations" => [identity_op("copy", "layer.kernel", "copy.safetensors")]})

    {:ok, first} = Apply.apply(plan, source, dir)
    [%{"sha256" => sha}] = first["operations"]

    {:ok, resume_plan} =
      Plan.load(%{
        "operations" => [
          identity_op("copy", "layer.kernel", "copy.safetensors")
          |> Map.put("expected_output_sha256", sha)
        ]
      })

    assert {:ok, resumed} = Apply.apply(resume_plan, source, dir)
    assert [%{"skipped" => true}] = resumed["operations"]

    File.write!(Path.join(dir, "copy.safetensors"), "bad")

    assert {:error, %Errors{message: message}} = Apply.apply(resume_plan, source, dir)
    assert message =~ "resume checksum mismatch"

    assert {:ok, forced} = Apply.apply(resume_plan, source, dir, force: true)
    assert [%{"skipped" => false}] = forced["operations"]
  end

  test "ParamTree.patch!/4 patches nested maps and tuples" do
    params = %{"tuple_container" => {Nx.tensor([0.0], type: :f32), Nx.tensor([1.0], type: :f32)}}

    manifest = %{
      "selected_tensors" => [
        %{"path" => "tuple_container.1", "segments" => ["tuple_container", 1]}
      ]
    }

    tensors = %{"tuple_container.1" => Nx.tensor([9.0], type: :f32)}

    patched = ParamTree.patch!(params, manifest, tensors)

    assert Nx.to_flat_list(elem(patched["tuple_container"], 1)) == [9.0]
  end

  test "StageCheck.compare/3 reports pass and fail" do
    plan = %{"schema" => "test.v1"}
    reference = %{"stages" => %{"stage.source_f32" => Nx.tensor([1.0], type: :f32)}}
    observed = %{"stages" => %{"stage.source_f32" => Nx.tensor([1.0], type: :f32)}}

    assert {:ok, %{"functional_passed" => true}} = StageCheck.compare(plan, reference, observed)

    failed = %{"stages" => %{"stage.source_f32" => Nx.tensor([2.0], type: :f32)}}
    assert {:ok, %{"functional_passed" => false}} = StageCheck.compare(plan, reference, failed)
  end

  test "BackendLabel round trips known labels" do
    assert {:ok, Nx.BinaryBackend} = BackendLabel.from_label("Nx.BinaryBackend")
    assert {:ok, {EXLA.Backend, client: :cuda}} = BackendLabel.from_label("EXLA.Backend<cuda:0>")
  end

  defp identity_op(id, source_path, output_path) do
    %{
      "id" => id,
      "operation" => "identity",
      "source_path" => source_path,
      "output_path" => output_path,
      "expected_shape" => [1, 2],
      "expected_dtype" => "f32"
    }
  end

  defp tmp_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "crucible_tensor_patch_tests/#{System.unique_integer([:positive])}"
      )

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    dir
  end
end
