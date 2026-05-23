defmodule CrucibleTensorPatch.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/North-Shore-AI/crucible_tensor_patch"

  unless Code.ensure_loaded?(DependencySources) do
    Code.require_file("build_support/dependency_sources.exs", __DIR__)
  end

  def project do
    [
      app: :crucible_tensor_patch,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_deps: :apps_direct],
      name: "CrucibleTensorPatch",
      description: "Deterministic tensor patch plans and patch application",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        credo: :test,
        dialyzer: :test,
        docs: :dev
      ]
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.12", override: true},
      DependencySources.dep(:crucible_safetensors, __DIR__),
      DependencySources.dep(:crucible_factorization, __DIR__),
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "deps.get",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "dialyzer --format short",
        "docs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "MIGRATION.md", "LICENSE"],
      source_ref: "main",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  defp package do
    [
      name: "crucible_tensor_patch",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib build_support mix.exs README.md LICENSE CHANGELOG.md MIGRATION.md)
    ]
  end
end
