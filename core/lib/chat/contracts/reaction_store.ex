defmodule Chat.Contracts.ReactionStore do
  @callback upsert(
              room_id :: String.t(),
              sequence_number :: integer(),
              user_id :: String.t(),
              emoji :: String.t()
            ) :: :ok | {:error, term()}

  @callback delete(
              room_id :: String.t(),
              sequence_number :: integer(),
              user_id :: String.t()
            ) :: :ok | {:error, term()}
end
