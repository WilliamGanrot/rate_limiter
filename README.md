# RateLimiter

## Usage

```elixir
defmodule MyApp.MyRateLimiter do
  use RateLimiter, algorithm: :sliding_window
end
```


```elixir
defmodule MyApp.CallbackSender do

  def make_callback(agent_id, http_request) do
    case MyApp.MyRateLimiter.ready?(agent_id) do
      true ->
        # make http request
      false ->
        # take action on unready request
        # for example put on queue och block
    end
  end

end
```



## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rate_limiter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rate_limiter, "~> 0.1.0"}
  ]
end
```



Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/rate_limiter>.

