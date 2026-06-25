defmodule Chat.Infra.Redis.Sequence do
  @moduledoc """
  Atomic per-id sequence backed by Redis `INCR`, with lazy seeding from a durable
  source.

  Redis is the fast authority for `sequence_number` generation. A cold or
  restarted Redis would rewind the counter and cause primary-key collisions in
  the durable store, so on a cold key the counter is reconciled against
  `seed_fn` — the highest value already persisted for this id.
  """

  @doc """
  Returns the next sequence number for `id`.

  On a cold Redis key (`INCR` returns `1`), reconciles against `seed_fn`, a
  zero-arity function returning the durable max for this id (`0` when none),
  so numbering resumes above what is already persisted.
  """
  @spec next(String.t(), (-> integer())) :: {:ok, integer()} | {:error, term()}
  def next(id, seed_fn) when is_function(seed_fn, 0) do
    key = "seq:#{id}"

    case Redix.command(:redix, ["INCR", key]) do
      {:ok, 1} ->
        case seed_fn.() do
          max when is_integer(max) and max > 0 ->
            # ponytail: cold Redis on a populated id. SET fixes future calls; a
            # concurrent burst inside this seeding window can still read 2..n
            # below `max` and collide. Per-id lock / Lua CAS if that ever bites.
            _ = Redix.command(:redix, ["SET", key, max + 1])
            {:ok, max + 1}

          _ ->
            {:ok, 1}
        end

      {:ok, n} ->
        {:ok, n}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
