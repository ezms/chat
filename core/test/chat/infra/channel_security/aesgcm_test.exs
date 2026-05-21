defmodule Chat.Infra.ChannelSecurity.AESGCMTest do
  use ExUnit.Case, async: true

  alias Chat.Infra.ChannelSecurity.AESGCM

  defp session_assigns do
    {client_pub_key, _client_priv_key} = :crypto.generate_key(:ecdh, :x25519)
    {_server_pub_key, session_key} = AESGCM.derive_session_key(client_pub_key)
    %{session_key: session_key}
  end

  test "encode/decode round-trip returns original payload" do
    assigns = session_assigns()
    payload = "hello encrypted world"
    encoded = AESGCM.encode(payload, assigns)
    assert {:ok, ^payload} = AESGCM.decode(encoded, assigns)
  end

  test "encode produces different ciphertext each call (random nonce)" do
    assigns = session_assigns()
    payload = "same payload"
    assert AESGCM.encode(payload, assigns) != AESGCM.encode(payload, assigns)
  end

  test "decode fails with wrong session key" do
    assigns = session_assigns()
    encoded = AESGCM.encode("secret", assigns)
    wrong_assigns = %{session_key: :crypto.strong_rand_bytes(32)}
    assert {:error, :decrypt_failed} = AESGCM.decode(encoded, wrong_assigns)
  end

  test "decode fails with truncated payload" do
    assigns = session_assigns()
    assert {:error, :invalid_payload} = AESGCM.decode(<<1, 2, 3>>, assigns)
  end

  test "derive_session_key produces same shared secret on both sides" do
    {client_pub_key, client_priv_key} = :crypto.generate_key(:ecdh, :x25519)
    {server_pub_key, server_session_key} = AESGCM.derive_session_key(client_pub_key)

    client_shared = :crypto.compute_key(:ecdh, server_pub_key, client_priv_key, :x25519)
    client_session_key = :crypto.hash(:sha256, client_shared)

    assert client_session_key == server_session_key
  end
end
