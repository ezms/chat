import Config

config :core, Chat.Endpoint,
  secret_key_base: "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx",
  server: false

config :core,
       :secret_key_base,
       "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
