defmodule RateLimiter.Algorithm.FixedWindow do
  defmacro __using__(_) do
    quote do
      use GenServer

      @default_window_size 120 * 1000
      @default_window_max_request_count 60
      # Client

      def start_link(opts \\ []) do
        window_size_ms = Keyword.get(opts, :window_size) || @default_window_size

        window_max_request_count =
          Keyword.get(opts, :window_max_request_count) || @default_window_max_request_count

        args = %{
          window_size_ms: window_size_ms,
          window_max_request_count: window_max_request_count
        }

        GenServer.start(__MODULE__, args, name: __MODULE__)
      end

      # Server

      @impl true
      def init(args) do
        table = :ets.new(__MODULE__, [:set, :protected])
        state = Map.put(args, :ets_table, table)
        {:ok, state}
      end

      @impl true
      def handle_call({:ready?, key, opts}, _from, state) do
        reply = ready?(key, state, opts)

        {:reply, reply, state}
      end

      @impl true
      def handle_cast(:reset_all, state) do
        %{ets_table: table} = state
        :ets.delete_all_objects(table)
        {:noreply, state}
      end

      @impl true
      def handle_cast({:reset, key}, state) do
        %{ets_table: table} = state
        :ets.delete(table, key)
        {:noreply, state}
      end

      # Private functions

      defp ready?(key, state, opts) do
        %{
          ets_table: table,
          window_size_ms: window_size_ms,
          window_max_request_count: window_max_request_count
        } = state

        now = now()

        case :ets.lookup(table, key) do
          [] ->
            new_window(key, state)
            ready?(key, state, opts)

          [{key, window_start, _}] when window_start + window_size_ms < now ->
            new_window(key, state)
            ready?(key, state, opts)

          [{_, _, request_count} = row] when request_count < window_max_request_count ->
            update_table_row(table, {key, now, request_count + 1})
            true

          _ ->
            false
        end
      end

      defp new_window(delimiter_key, state) do
        %{
          ets_table: table
        } = state

        ets_row = {delimiter_key, now(), 0}
        :ets.insert(table, ets_row)
      end

      defp update_table_row(
             table,
             {delimiter_key, _window_start, _current_count} = row
           ) do
        :ets.insert(table, row)
        [row] = :ets.lookup(table, delimiter_key)
        row
      end

      defp now, do: System.system_time(:millisecond)
    end
  end
end
