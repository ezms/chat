defmodule Chat.Contracts.MessageStore do
  @callback insert(room_id :: String.t(), sender_id :: String.t(), content :: binary()) ::
              {:ok, sequence_number :: integer()} | {:error, term()}

  @callback insert_file(
              room_id :: String.t(),
              sender_id :: String.t(),
              file_key :: String.t(),
              filename :: String.t(),
              content_type :: String.t(),
              size :: integer()
            ) :: {:ok, sequence_number :: integer()} | {:error, term()}
end
