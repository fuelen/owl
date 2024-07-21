defmodule Owl.Tag do
  @moduledoc """
  A tag struct.

  Use `Owl.Data.tag/2` to build a tag.

  Tag is a container for data and ANSI sequences associated with it.
  It allows having local binding for styles in console, similar to tags in HTML.

  Let's say you have a string that should be written to stdout in red color.
  This can be easily done by using a naive approach:

      substring = "world"
      IO.puts([IO.ANSI.red(), "Hello \#{substring}!!"])

  It works well for easy cases. If you want to make `substring` in another color you can try this:

      substring = [IO.ANSI.green(), "world"]
      IO.puts([IO.ANSI.red(), "Hello \#{substring}!!"])

  but you'll notice, that the text after `substring` is green too. In order make `"!!"` part red again, you have
  to write color explicitly:

      IO.puts([IO.ANSI.red(), "Hello \#{substring}\#{IO.ANSI.red()}!!"])

  if substring changes background color, you have to return to the previous one too:

      substring = [IO.ANSI.green(), IO.ANSI.red_background() "world"]
      IO.puts([IO.ANSI.red(), "Hello \#{substring}\#{[IO.ANSI.red(), IO.ANSI.default_background()]}!!"])

  Such code is very hard to maintain.
  This is how the issue can be addressed with `Owl.Data.tag/2`:

      substring = Owl.Data.tag("world", :green)
      Owl.IO.puts(Owl.Data.tag(["Hello ", substring, "!!"], :red))

      substring = Owl.Data.tag("world", [:green, :red_background])
      Owl.IO.puts(Owl.Data.tag(["Hello ", substring, "!!"], :red))
  """

  @type t(data) :: %__MODULE__{sequences: [Owl.Data.sequence()], data: data}
  defstruct sequences: [], data: []

  @deprecated "Use `Owl.Data.tag/2` instead"
  @doc "Use `Owl.Data.tag/2` instead"
  def new(data, sequences), do: Owl.Data.tag(data, sequences)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Owl.Tag{data: data, sequences: sequences}, opts) do
      concat(["Owl.Data.tag(", to_doc(data, opts), ", ", inspect_sequences(sequences, opts), ")"])
    end

    defp inspect_sequences([sequence], opts), do: inspect_sequence(sequence, opts)

    defp inspect_sequences(sequences, opts) when is_list(sequences) do
      open = color("[", :list, opts)
      sep = color(",", :list, opts)
      close = color("]", :list, opts)
      container_doc(open, sequences, close, opts, &inspect_sequences/2, separator: sep)
    end

    defp inspect_sequences(sequence, opts), do: inspect_sequence(sequence, opts)

    defp inspect_sequence("\e[38;5;" <> rest, opts) do
      {number, "m"} = Integer.parse(rest)
      concat(["IO.ANSI.color(", to_doc(number, opts), ")"])
    end

    defp inspect_sequence("\e[48;5;" <> rest, opts) do
      {number, "m"} = Integer.parse(rest)
      concat(["IO.ANSI.color_background(", to_doc(number, opts), ")"])
    end

    defp inspect_sequence("\e[38;2;" <> rest, opts) do
      [r, g, b] = String.split(rest, ";")
      {r, ""} = Integer.parse(r)
      {g, ""} = Integer.parse(g)
      {b, "m"} = Integer.parse(b)

      concat([
        "Owl.TrueColor.color(",
        to_doc(r, opts),
        ",",
        to_doc(g, opts),
        ",",
        to_doc(b, opts),
        ")"
      ])
    end

    defp inspect_sequence("\e[48;2;" <> rest, opts) do
      [r, g, b] = String.split(rest, ";")
      {r, ""} = Integer.parse(r)
      {g, ""} = Integer.parse(g)
      {b, "m"} = Integer.parse(b)

      concat([
        "Owl.TrueColor.color_background(",
        to_doc(r, opts),
        ",",
        to_doc(g, opts),
        ",",
        to_doc(b, opts),
        ")"
      ])
    end

    defp inspect_sequence(sequence, opts) do
      to_doc(sequence, opts)
    end
  end
end
