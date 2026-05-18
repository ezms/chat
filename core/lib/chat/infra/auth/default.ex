defmodule Chat.Infra.Auth.Default do
  @behaviour Chat.Contracts.Auth

  @impl true
  def verify(token) do
    secret = Application.fetch_env!(:core, :secret_key_base)

    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify(token, signer) do
      {:ok, claims} -> {:ok, claims["sub"]}
      {:error, reason} -> {:error, reason}
    end
  end
end
