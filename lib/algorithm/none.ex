defmodule RateLimiter.Algorithm.None do
  @doc false
  defmacro __using__(_) do
    quote do
      use GenServer

      # Client

      def start_link(_opts \\ []) do
        GenServer.start(__MODULE__, %{}, name: __MODULE__)
      end

      def ready?(delimiter_key) do
        GenServer.call(__MODULE__, {:ready?, delimiter_key})
      end

      # Server

      @impl true
      def init(_) do
        {:ok, %{}}
      end

      @impl true
      def handle_call({:ready?, delimiter_key}, _from, state) do
        {:reply, :ok, state}
      end
    end
  end
end
