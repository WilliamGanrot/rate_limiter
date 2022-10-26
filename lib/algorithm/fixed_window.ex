defmodule RateLimiter.Algorithm.FixedWindow do
  defmacro __using__(_) do
    quote do
      use GenServer

      @default_window_size 120 * 1000
      @default_window_max_request_count 60
      # Client

      def start_link(opts) do
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
        table = :ets.new(:fixed_window_reqistry, [:set, :protected])
        state = args |> Map.put(:fixed_window_reqistry, table)
        {:ok, state}
      end

      @impl true
      def handle_call({:ready?, delimiter_key}, _from, state) do
        %{
          fixed_window_reqistry: table,
          window_size_ms: window_size_ms,
          window_max_request_count: window_max_request_count
        } = state

        reply =
          case :ets.lookup(table, delimiter_key) do
            [] ->
              new_window(table, delimiter_key)
              true

            [{delimiter_key, window_start, _}] when window_start + window_size_ms > now() ->
              new_window(table, delimiter_key)
              true

            [{_, _, request_count} = row] when request_count <= window_max_request_count ->
              update_table_row(table, {delimiter_key, now(), 0, request_count})
              true

            _ ->
              false
          end

        {:reply, reply, state}
      end

      defp new_window(table, delimiter_key) do
        ets_row = {delimiter_key, now(), 1}
        :ets.insert(table, ets_row)
      end

      def update_table_row(
            table,
            {delimiter_key, _window_start, _current_count, _window_max_request_count} = row
          ) do
        :ets.insert(table, row)
        [row] = :ets.lookup(table, delimiter_key)
        row
      end

      defp now, do: System.system_time(:millisecond)
    end
  end
end
