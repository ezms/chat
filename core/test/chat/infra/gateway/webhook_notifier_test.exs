defmodule Chat.Infra.Gateway.WebhookNotifierTest do
  use ExUnit.Case, async: true

  alias Chat.Infra.Gateway.WebhookNotifier

  setup do
    Application.delete_env(:core, :gateway_webhook_url)
    Application.delete_env(:core, :gateway_webhook_secret)
    :ok
  end

  describe "notify/4" do
    test "returns :ok when gateway is not configured" do
      assert :ok = WebhookNotifier.notify("room:admin:123", "user_1", "hello", 1)
    end

    test "returns :ok when only url is configured" do
      Application.put_env(:core, :gateway_webhook_url, "http://localhost:9999")
      assert :ok = WebhookNotifier.notify("room:admin:123", "user_1", "hello", 1)
    end

    test "returns :ok when only secret is configured" do
      Application.put_env(:core, :gateway_webhook_secret, "secret")
      assert :ok = WebhookNotifier.notify("room:admin:123", "user_1", "hello", 1)
    end

    test "returns :ok and fires async task when fully configured" do
      Application.put_env(:core, :gateway_webhook_url, "http://localhost:9999")
      Application.put_env(:core, :gateway_webhook_secret, "secret")
      assert :ok = WebhookNotifier.notify("room:admin:123", "user_1", "hello", 1)
    end
  end

  describe "notify_file/6" do
    test "returns :ok when gateway is not configured" do
      assert :ok =
               WebhookNotifier.notify_file(
                 "room:admin:123",
                 "user_1",
                 "some/file_key",
                 "holerite.pdf",
                 "application/pdf",
                 2
               )
    end

    test "returns :ok and fires async task when fully configured" do
      Application.put_env(:core, :gateway_webhook_url, "http://localhost:9999")
      Application.put_env(:core, :gateway_webhook_secret, "secret")

      assert :ok =
               WebhookNotifier.notify_file(
                 "room:admin:123",
                 "user_1",
                 "some/file_key",
                 "holerite.pdf",
                 "application/pdf",
                 2
               )
    end
  end
end
