defmodule SlidingWindow do
  @doc false
  use GenServer

  # Client

  def start_link(_opts) do
    args = %{
      window_size_ms: 10 * 1000,
      window_max_request_count: 5,
      clean_up_interval: 210 * 1000
    }

    GenServer.start(__MODULE__, args, name: __MODULE__)
  end

  def request(delimiter_key, request) do
    GenServer.call(__MODULE__, {:request, delimiter_key, request})
  end

  # Server

  @impl true
  def init(args) do
    %{clean_up_interval: clean_up_interval} = args
    Process.send_after(self(), :clean_up, clean_up_interval)

    table = :ets.new(:sliding_window_reqistry, [:set, :protected])
    state = args |> Map.put(:sliding_window_reqistry, table)
    {:ok, state}
  end

  @impl true
  def handle_call({:request, delimiter_key, _request}, _from, state) do
    %{
      sliding_window_reqistry: table,
      window_max_request_count: window_max_request_count
    } = state

    IO.inspect(estimated_count(delimiter_key, state))

    reply =
      case :ets.lookup(table, delimiter_key) do
        [] ->
          ets_row = {delimiter_key, now(), 1, window_max_request_count}
          :ets.insert(table, ets_row)
          :ok

        [{_, window_start, request_count, prev_window_req_count}]
        when request_count <= window_max_request_count ->
          # IO.inspect(request_count * ((window_size_ms - )))

          ets_row = {delimiter_key, window_start, request_count + 1, prev_window_req_count}
          :ets.insert(table, ets_row)
          :ok

        _ ->
          {:error, :window_max_request_count_reached}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:clean_up, state) do
    %{
      sliding_window_reqistry: table,
      clean_up_interval: clean_up_interval
    } = state

    :ets.delete_all_objects(table)
    Process.send_after(self(), :clean_up, clean_up_interval)

    {:noreply, state}
  end

  def window_start(timestamp, window_size) do
    timestamp - rem(timestamp, window_size)
  end

  def estimated_count(delimiter_key, state) do
    %{
      sliding_window_reqistry: table,
      window_size_ms: window_size_ms,
      window_max_request_count: window_max_request_count
    } = state

    request_time = System.system_time(:millisecond)

    estimated_count =
      case :ets.lookup(table, delimiter_key) do
        [{_key, window_start, request_count, previous_window_request_count}] ->
          time_into_current_window = request_time - window_start

          previous_window_request_count *
            ((window_size_ms - time_into_current_window) / window_size_ms / 1000) +
            request_count

        _ ->
          window_max_request_count
      end

    estimated_count
  end

  defp now, do: System.system_time(:millisecond)
end
