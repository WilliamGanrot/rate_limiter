defmodule SlidingWindowTest do
  def make_x_request(x) do
    for _ <- 0..x do
      SlidingWindow.request("key", "")
    end
    |> IO.inspect()
    |> Enum.filter(fn r -> r == :ok end)
    |> length()
    |> IO.inspect(label: "success count")
  end
end

defmodule SlidingWindow do
  @doc false
  use GenServer

  # Client

  def start_link(_opts) do
    args = %{
      window_size_ms: 6 * 1000,
      window_max_request_count: 12
    }

    GenServer.start(__MODULE__, args, name: __MODULE__)
  end

  def request(delimiter_key, request) do
    GenServer.call(__MODULE__, {:request, delimiter_key, request})
  end

  # Server

  @impl true
  def init(args) do
    table = :ets.new(:sliding_window_reqistry, [:set, :protected])
    state = args |> Map.put(:sliding_window_reqistry, table)
    {:ok, state}
  end

  @impl true
  def handle_call({:request, delimiter_key, _request}, _from, state) do
    %{
      sliding_window_reqistry: table,
      window_size_ms: window_size_ms,
      window_max_request_count: window_max_request_count
    } = state

    reply =
      case :ets.lookup(table, delimiter_key) do
        [] ->
          ets_row = {delimiter_key, now(), 1, window_max_request_count}
          :ets.insert(table, ets_row)
          :ok

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
            estimated_count(window_size_ms, window_start, request_count, prev_window_req_count)

          if estimated_count <= window_max_request_count do
            ets_row = {delimiter_key, window_start, request_count + 1, prev_window_req_count}
            :ets.insert(table, ets_row)
            :ok
          else
            {:error, :count_surpassed_estimated_count}
          end
      end

    {:reply, reply, state}
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
