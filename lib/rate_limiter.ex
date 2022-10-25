# defmodule RateLimiter.Behavior do
#   @callback allowed_request(term()) :: term()
#   @callback disallowed_request(term()) :: term()
#   @optional_callbacks disallowed_request: 1
# end

defmodule RateLimiter do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      case Keyword.get(opts, :algorithm) do
        :sliding_window ->
          use RateLimiter.Algorithm.SlidingWindow

        :none ->
          use RateLimiter.Algorithm.None
      end
    end
  end
end
