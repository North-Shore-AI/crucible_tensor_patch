defmodule DependencySources do
  @moduledoc false

  def dep(app, repo_root, extra_opts \\ []) when is_atom(app) and is_binary(repo_root) do
    repo_root = Path.expand(repo_root)
    config = load_config!(repo_root)
    dep_config = config |> Map.fetch!(:deps) |> Map.fetch!(app)
    source = select_source!(dep_config, repo_root)
    dep_tuple(app, dep_config, source, repo_root, extra_opts)
  end

  defp load_config!(repo_root) do
    repo_root
    |> Path.join("build_support/dependency_sources.config.exs")
    |> Code.eval_file()
    |> elem(0)
  end

  defp select_source!(config, repo_root) do
    order = Map.get(config, :default_order, [:path, :github, :hex])

    Enum.find(order, fn
      :path -> config[:path] && File.exists?(Path.expand(config[:path], repo_root))
      source -> Map.has_key?(config, source)
    end) || raise ArgumentError, "no dependency source available"
  end

  defp dep_tuple(app, config, :path, repo_root, extra_opts) do
    {app, Keyword.merge([path: Path.expand(config[:path], repo_root)], extra_opts)}
  end

  defp dep_tuple(app, config, :github, _repo_root, extra_opts) do
    github = Map.fetch!(config, :github)
    opts = github |> Map.delete(:repo) |> Map.to_list()
    {app, Keyword.merge([github: github.repo], Keyword.merge(opts, extra_opts))}
  end

  defp dep_tuple(app, config, :hex, _repo_root, extra_opts) do
    case extra_opts do
      [] -> {app, Map.fetch!(config, :hex)}
      opts -> {app, Map.fetch!(config, :hex), opts}
    end
  end
end
