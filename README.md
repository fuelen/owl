# Owl
[![CI Status](https://github.com/fuelen/owl/actions/workflows/ci.yml/badge.svg)](https://github.com/fuelen/owl/actions)
[![Hex.pm](https://img.shields.io/hexpm/v/owl.svg)](https://hex.pm/packages/owl)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/owl)](https://hex.pm/packages/owl)
[![Coverage Status](https://coveralls.io/repos/github/fuelen/owl/badge.svg?branch=main)](https://coveralls.io/github/fuelen/owl?branch=main)
```
   ,_,
  {o,o}
  /)  )
---"-"--
```
Owl is a toolkit for writing command-line user interfaces in Elixir.

It provides a convenient interface for:

* colorizing text using tags
* input controls with validation and casting to various data types
* select/multi-select controls, inspired by AUR package managers
* tables
* editing text in the `ELIXIR_EDITOR`
* wrapping multi-line, colorized data into ASCII boxes
* printing palette colors
* progress bars and spinners, with support for multiple bars/spinners simultaneously
* live updating of multi-line blocks
* capturing `:stdio` output and printing it above LiveScreen blocks
* working with a virtual device that partially implements
[The Erlang I/O Protocol](https://www.erlang.org/doc/apps/stdlib/io_protocol.html) and does not conflict with live blocks.
* running shell commands and daemons with secure logging and masked secrets
* rendering hyperlinks (OSC 8) in supported terminals
* true-color (24‑bit) ANSI sequences
* word wrapping and truncation utilities for colorized multi-line text

## Demo
[![asciicast](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2.svg)](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2)

The code can be found in the [examples](https://github.com/fuelen/owl/tree/main/examples) directory.

## Installation

The package can be installed by adding `owl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:owl, "~> 0.13"},
    # ucwidth is an optional dependency, uncomment it for multibyte characters support (emoji, etc)
    # {:ucwidth, "~> 0.2"}
  ]
end
```
Documentation can be found at [https://hexdocs.pm/owl](https://hexdocs.pm/owl).
