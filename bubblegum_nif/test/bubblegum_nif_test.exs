defmodule BubblegumNifTest do
  use ExUnit.Case
  doctest BubblegumNif

  test "greets the world" do
    assert BubblegumNif.hello() == :world
  end
end
