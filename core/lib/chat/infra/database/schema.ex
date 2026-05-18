defmodule Chat.Infra.Database.Schema do
  @keyspace_query """
  CREATE KEYSPACE IF NOT EXISTS chat
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}
  """

  @messages_query """
  CREATE TABLE IF NOT EXISTS chat.messages (
    room_id text,
    sequence_number bigint,
    sender_id text,
    content blob,
    inserted_at timestamp,
    PRIMARY KEY (room_id, sequence_number)
  ) WITH CLUSTERING ORDER BY (sequence_number ASC)
  """

  def statements, do: [@keyspace_query, @messages_query]
end
