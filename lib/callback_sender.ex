defmodule CallbackSender do
  use RateLimiter, algorithm: :sliding_window
end
