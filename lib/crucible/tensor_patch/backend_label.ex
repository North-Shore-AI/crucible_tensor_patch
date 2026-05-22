defmodule Crucible.TensorPatch.BackendLabel do
  @moduledoc "Compatibility namespace for `CrucibleTensorPatch.BackendLabel`."

  defdelegate from_label(label), to: CrucibleTensorPatch.BackendLabel
  defdelegate from_label!(label), to: CrucibleTensorPatch.BackendLabel
end
