defmodule RateLimiter do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      case Keyword.get(opts, :algorithm) do
        :sliding_window ->
          use RateLimiter.Algorithm.SlidingWindow

        :fixed_window ->
          use RateLimiter.Algorithm.FixedWindow

        :none ->
          use RateLimiter.Algorithm.None
      end

      def ready?(delimiter_key, opts \\ []) when is_list(opts) do
        GenServer.call(__MODULE__, {:ready?, delimiter_key, opts})
      end

      def reset(key) do
        GenServer.cast(__MODULE__, {:reset, key})
      end

      def reset_all() do
        GenServer.cast(__MODULE__, :reset)
      end
    end
  end
end
