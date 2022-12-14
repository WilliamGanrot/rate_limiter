defmodule RateLimiter.Algorithm.None do
  @doc false
  defmacro __using__(_) do
    quote do
      use GenServer

      # Client

      def start_link(_opts \\ []) do
        GenServer.start(__MODULE__, %{}, name: __MODULE__)
      end

      # Server

      @impl true
      def init(_) do
        {:ok, %{}}
      end

      @impl true
      def handle_call({:ready?, _delimiter_key, _opts}, _from, state) do
        {:reply, :ok, state}
      end

      @impl true
      def handle_cast(:reset_all, state) do
        {:noreply, state}
      end

      @impl true
      def handle_cast({:reset, _key}, state) do
        {:noreply, state}
      end
    end
  end
end
