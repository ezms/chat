defmodule Chat.Infra.ChannelSecurity.AESGCM do
  @behaviour Chat.Contracts.ChannelSecurity

  @nonce_size 12
  @tag_size 16

  @impl true
  def encode(payload, %{session_key: key}) do
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, payload, "", true)
    nonce <> tag <> ciphertext
  end

  @impl true
  def decode(
        <<nonce::binary-size(@nonce_size), tag::binary-size(@tag_size), ciphertext::binary>>,
        %{session_key: key}
      ) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, "", tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decrypt_failed}
    end
  end

  def decode(_, _), do: {:error, :invalid_payload}

  @doc """
  Generates a server ECDH key pair, derives the shared session key from the
  client's public key, and returns {server_pub_key, session_key}.

  Session key is SHA-256 of the ECDH shared secret — 32 bytes, suitable for AES-256.
  """
  @impl true
  def derive_session_key(client_pub_key) do
    {server_pub_key, server_priv_key} = :crypto.generate_key(:ecdh, :x25519)
    shared_secret = :crypto.compute_key(:ecdh, client_pub_key, server_priv_key, :x25519)
    session_key = :crypto.hash(:sha256, shared_secret)
    {server_pub_key, session_key}
  end
end
