defmodule RateLimiter.Algorithm.SlidingWindow do
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
      def handle_call({:ready?, delimiter_key, opts}, _from, state) do
        %{
          ets_table: table,
          window_size_ms: window_size_ms,
          window_max_request_count: window_max_request_count
        } = state

        reply =
          case :ets.lookup(table, delimiter_key) do
            [] ->
              ets_row = {delimiter_key, now(), 1, window_max_request_count}
              :ets.insert(table, ets_row)
              true

            [{delimiter_key, window_start, request_count, prev_window_req_count}] ->
              passed_time = passed_time_since(window_start)

              {delimiter_key, window_start, request_count, prev_window_req_count} =
                cond do
                  # Entire window without any requests have passed
                  passed_time > window_size_ms + window_size_ms ->
                    update_table_row(table, {delimiter_key, now(), 0, 0})

                  passed_time > window_size_ms ->
                    update_table_row(table, {delimiter_key, now(), 0, request_count})

                  true ->
                    {delimiter_key, window_start, request_count, prev_window_req_count}
                end

              estimated_count =
                estimated_count(
                  window_size_ms,
                  window_start,
                  request_count,
                  prev_window_req_count
                )

              if estimated_count <= window_max_request_count do
                ets_row = {delimiter_key, window_start, request_count + 1, prev_window_req_count}
                :ets.insert(table, ets_row)
                true
              else
                false
              end
          end

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

      def update_table_row(
            table,
            {delimiter_key, _window_start, _current_count, _window_max_request_count} = row
          ) do
        :ets.insert(table, row)
        [row] = :ets.lookup(table, delimiter_key)
        row
      end

      def estimated_count(
            window_size_ms,
            window_start_time,
            current_request_count,
            previous_window_request_count
          ) do
        request_time = System.system_time(:millisecond)
        time_into_current_window = request_time - window_start_time
        window_percent_left = (window_size_ms - time_into_current_window) / window_size_ms
        previous_window_request_count * window_percent_left + current_request_count
      end

      defp now, do: System.system_time(:millisecond)
      defp passed_time_since(window_start), do: now() - window_start
    end
  end
end
