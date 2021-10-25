defmodule Owl.IO do
  @moduledoc "A set of functions for handling IO with support of `t:Owl.Data.t/0`"

  @doc false
  # WIP
  def input(type, opts \\ []) do
    value =
      case String.trim(IO.gets(Keyword.fetch!(opts, :prompt) <> "\n")) do
        "" -> nil
        string -> string
      end

    cond do
      not Keyword.get(opts, :allow_blank, false) and is_nil(value) ->
        Owl.IO.puts(Owl.Tag.new("Cannot be blank", :red))
        input(type, opts)

      true ->
        value
    end
  end

  @doc "Wrapper around `IO.puts/2` that accepts `t:Owl.Data.t/0`"
  @spec puts(Owl.Data.t()) :: :ok
  def puts(device \\ :stdio, data) do
    data = Owl.Data.to_ansidata(data)

    IO.puts(device, data)
  end
end
