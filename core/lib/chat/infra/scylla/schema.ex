defmodule Chat.Infra.Scylla.Schema do
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

  @add_file_key_query "ALTER TABLE chat.messages ADD file_key text"

  @reactions_query """
  CREATE TABLE IF NOT EXISTS chat.reactions (
    room_id text,
    sequence_number bigint,
    user_id text,
    emoji text,
    PRIMARY KEY ((room_id, sequence_number), user_id)
  )
  """

  @thread_replies_query """
  CREATE TABLE IF NOT EXISTS chat.thread_replies (
    room_id text,
    parent_sequence_number bigint,
    sequence_number bigint,
    sender_id text,
    content blob,
    inserted_at timestamp,
    PRIMARY KEY ((room_id, parent_sequence_number), sequence_number)
  ) WITH CLUSTERING ORDER BY (sequence_number ASC)
  """

  def statements,
    do: [
      @keyspace_query,
      @messages_query,
      @add_file_key_query,
      @reactions_query,
      @thread_replies_query
    ]
end
