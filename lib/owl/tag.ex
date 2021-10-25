defmodule Owl.Tag do
  @moduledoc """
  A tag struct

  Tag is a container for data and ANSI sequences associated with it.
  It allows having local binding for styles in console, similar to tags in HTML.

  Let's say you have a string that should written to stdout in red color.
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
  This is how the issue can be addressed with `Owl.Tag`:

      substring = Owl.Tag.new("world", :green)
      Owl.IO.puts(Owl.Tag.new(["Hello ", substring, "!!"], :red))

      substring = Owl.Tag.new("world", [:green, :red_background])
      Owl.IO.puts(Owl.Tag.new(["Hello ", substring, "!!"], :red))
  """

  @typedoc """
  ANSI escape sequence.

  An atom like `:green`, `:red_background`, `:light_cyan`, `light_red_background`.

  A binary like `"\e[38;5;33m"` (which is `IO.ANSI.color(33)` or `IO.ANSI.color(0, 2, 5)`).

  Currently, only colors are supported. Read about all available values in doc for `IO.ANSI` or `Owl.Palette`.
  """
  @type sequence :: atom() | binary()
  @type t(data) :: %__MODULE__{sequences: [sequence()], data: data}
  defstruct sequences: [], data: []

  @doc """
  Builds a tag.

  ## Examples

      Owl.Tag.new(["hello ", Owl.Tag.new("world", :green), "!!!"], :red)

      Owl.Tag.new("hello world", [:green, :red_background])
  """
  @spec new(data, sequence() | [sequence()]) :: t(data) when data: Owl.Data.t()
  def new(data, sequences) do
    %__MODULE__{
      sequences: List.wrap(sequences),
      data: data
    }
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Owl.Tag{data: data, sequences: sequences}, opts) do
      concat(["#Owl.Tag", to_doc(sequences, opts), "<", to_doc(data, opts), ">"])
    end
  end
end
