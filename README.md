# Owl
```
   ,_,
  {o,o}
  /)  )
---"-"--
```
Owl is a toolkit for writing command-line user interfaces in Elixir.

It provides a convinient interface for

* colorizing text using tags
* input control with validations and casting to various data types
* select/multiselect controls, inspired by AUR package managers
* editing text in `ELIXIR_EDITOR`
* wrapping multiline colorized data into ASCII boxes
* printing palette colors
* progress bars, multiple bars at the same time are supported as well
* live-updating of multiline blocks
* working with virtual device which partially implements
[The Erlang I/O Protocol](https://www.erlang.org/doc/apps/stdlib/io_protocol.html) and doesn't conflict with live blocks.

## Demo
[![asciicast](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2.svg)](https://asciinema.org/a/vOL2PtAEWB88S9G93Iojwprj2)

## Installation

The package can be installed by adding `owl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:owl, "~> 0.1.0"}
  ]
end
```
Documentation can be found at [https://hexdocs.pm/owl](https://hexdocs.pm/owl).
