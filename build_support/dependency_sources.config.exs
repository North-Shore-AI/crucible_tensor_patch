%{
  deps: %{
    crucible_safetensors: %{
      path: "../crucible_safetensors",
      github: %{repo: "North-Shore-AI/crucible_safetensors", branch: "main"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    crucible_factorization: %{
      path: "../crucible_factorization",
      github: %{repo: "North-Shore-AI/crucible_factorization", branch: "main"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
