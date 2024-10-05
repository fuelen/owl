# Owl
[![CI Status](https://github.com/fuelen/owl/actions/workflows/ci.yml/badge.svg)](https://github.com/fuelen/owl/actions)
[![Hex.pm](https://img.shields.io/hexpm/v/owl.svg)](https://hex.pm/packages/owl)
[![Coverage Status](https://coveralls.io/repos/github/fuelen/owl/badge.svg?branch=main)](https://coveralls.io/github/fuelen/owl?branch=main)
```
   ,_,
  {o,o}
  /)  )
---"-"--
```
Owl is a toolkit for writing command-line user interfaces in Elixir.

It provides a convenient interface for

* colorizing text using tags
* input control with validations and casting to various data types
* select/multiselect controls, inspired by AUR package managers
* tables
* editing text in `ELIXIR_EDITOR`
* wrapping multiline colorized data into ASCII boxes
* printing palette colors
* progress bars and spinners, multiple bars/spinners at the same time are supported as well
* live-updating of multiline blocks
* working with virtual device which partially implements
[The Erlang I/O Protocol](https://www.erlang.org/doc/apps/stdlib/io_protocol.html) and doesn't conflict with live blocks.

## Demo
[![asciicast](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2.svg)](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2)

The code can be found  in [examples](https://github.com/fuelen/owl/tree/main/examples) directory.

## Installation

The package can be installed by adding `owl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:owl, "~> 0.12"},
    # ucwidth is an optional dependency, uncomment it for multibyte characters support (emoji, etc)
    # {:ucwidth, "~> 0.2"}
  ]
end
```
Documentation can be found at [https://hexdocs.pm/owl](https://hexdocs.pm/owl).
