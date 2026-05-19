defmodule Chat.Infra.Auth.DefaultTest do
  use ExUnit.Case, async: false

  @secret "test_secret_key_base"
  @signer Joken.Signer.create("HS256", @secret)

  setup do
    Application.put_env(:core, :secret_key_base, @secret)
    :ok
  end

  defp generate_token(claims) do
    {:ok, token, _} = Joken.encode_and_sign(claims, @signer)
    token
  end

  test "returns user_id and room_ids for valid token" do
    token = generate_token(%{"sub" => "user_123", "room_ids" => ["room_1", "room_2"]})

    assert {:ok, %{user_id: "user_123", room_ids: ["room_1", "room_2"]}} =
             Chat.Infra.Auth.Default.verify(token)
  end

  test "returns empty room_ids when claim is absent" do
    token = generate_token(%{"sub" => "user_123"})
    assert {:ok, %{user_id: "user_123", room_ids: []}} = Chat.Infra.Auth.Default.verify(token)
  end

  test "returns error for invalid token" do
    assert {:error, _} = Chat.Infra.Auth.Default.verify("token_invalido")
  end

  test "returns error for token signed with wrong secret" do
    wrong_signer = Joken.Signer.create("HS256", "outro_secret")
    {:ok, token, _} = Joken.encode_and_sign(%{"sub" => "user_123"}, wrong_signer)
    assert {:error, _} = Chat.Infra.Auth.Default.verify(token)
  end
end
