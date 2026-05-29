defmodule Chat.Contracts.ThreadStore do
  @callback insert_reply(
              room_id :: String.t(),
              parent_sequence_number :: integer(),
              sender_id :: String.t(),
              content :: binary()
            ) :: {:ok, sequence_number :: integer()} | {:error, term()}

  @callback count_replies(room_id :: String.t(), parent_sequence_number :: integer()) ::
              {:ok, integer()} | {:error, term()}
end
