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

    defp inspect_sequences([sequence], opts), do: to_doc(sequence, opts)
    defp inspect_sequences(sequences, opts), do: to_doc(sequences, opts)
  end
end
