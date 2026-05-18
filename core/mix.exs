defmodule Chat.Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Chat.Core, []},
      extra_applications: [:logger, :crypto],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:protobuf, "~> 0.13"},
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.0"},
      {:xandra, "~> 0.19"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
