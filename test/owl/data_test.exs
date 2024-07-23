defmodule Owl.DataTest do
  use ExUnit.Case, async: true
  doctest Owl.Data
  import Owl.Data.TestHelpers

  test inspect(&Owl.Data.length/2) do
    assert Owl.Data.length(Owl.Data.tag("one", :green)) == 3
    assert Owl.Data.length(Owl.Data.tag(["one", "two"], :green)) == 6

    assert Owl.Data.length([
             "one",
             ["two", "three"],
             Owl.Data.tag(["four", "five"], :green),
             "six"
           ]) == 22
  end

  test inspect(&Owl.Data.add_prefix/2) do
    data =
      Owl.Data.tag(
        [
          "hi",
          "a\nand new",
          " line ",
          Owl.Data.tag(" hey\n aloha", :red),
          "!!"
        ],
        :green
      )

    assert data |> Owl.Data.add_prefix(Owl.Data.tag("PREFIX: ", :yellow)) == [
             [
               %Owl.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Tag{data: ["hi", "a"], sequences: [:green]}
             ],
             "\n",
             [
               %Owl.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Tag{
                 data: ["and new", " line ", %Owl.Tag{data: [" hey"], sequences: [:red]}],
                 sequences: [:green]
               }
             ],
             "\n",
             [
               %Owl.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Tag{
                 data: [%Owl.Tag{data: [" aloha"], sequences: [:red]}, "!!"],
                 sequences: [:green]
               }
             ]
           ]
  end

  describe inspect(&Owl.Data.split/2) do
    test "1" do
      assert Owl.Data.split(
               [
                 ["1", "2", "3", "4", ["5", "6"]],
                 "\n",
                 ["7", "8"],
                 "\n",
                 ["9", "10"]
               ],
               "\n"
             ) == [["1", "2", "3", "4", "5", "6"], ["7", "8"], ["9", "10"]]
    end

    test "2" do
      assert Owl.Data.split(Owl.Data.tag("first\nsecond\nthird", :green), "\n") ==
               [
                 %Owl.Tag{data: ["first"], sequences: [:green]},
                 %Owl.Tag{data: ["second"], sequences: [:green]},
                 %Owl.Tag{data: ["third"], sequences: [:green]}
               ]

      assert Owl.Data.split(Owl.Data.tag(["first", "\n", "second", "aloha"], :green), "\n") == [
               %Owl.Tag{data: ["first"], sequences: [:green]},
               %Owl.Tag{data: ["second", "aloha"], sequences: [:green]}
             ]
    end

    test "3" do
      assert Owl.Data.split(
               Owl.Data.tag(
                 [
                   "hi",
                   "a\nand new",
                   " line ",
                   Owl.Data.tag(" hey\n aloha", :red),
                   "!!"
                 ],
                 :green
               ),
               "\n"
             ) == [
               %Owl.Tag{data: ["hi", "a"], sequences: [:green]},
               %Owl.Tag{
                 data: ["and new", " line ", Owl.Data.tag([" hey"], :red)],
                 sequences: [:green]
               },
               %Owl.Tag{data: [Owl.Data.tag([" aloha"], :red), "!!"], sequences: [:green]}
             ]
    end

    test "4" do
      assert Owl.Data.split(
               [
                 Owl.Data.tag(
                   [
                     Owl.Data.tag(["one two three"], :blue_background),
                     " four"
                   ],
                   :green
                 )
               ],
               " "
             )
             <~> [
               %Owl.Tag{data: ["one"], sequences: [:blue_background, :green]},
               %Owl.Tag{data: ["two"], sequences: [:blue_background, :green]},
               %Owl.Tag{data: ["three"], sequences: [:blue_background, :green]},
               %Owl.Tag{data: ["four"], sequences: [:green]}
             ]
    end

    test "5" do
      assert Owl.Data.split(
               [
                 "one ",
                 Owl.Data.tag(
                   [
                     "two three",
                     Owl.Data.tag(["four", Owl.Data.tag([" five six"], :red)], :yellow_background)
                   ],
                   :blue_background
                 ),
                 " seven eight",
                 Owl.Data.tag([" nine ten"], :blue_background)
               ],
               " "
             )
             <~> [
               "one",
               %Owl.Tag{data: ["two"], sequences: [:blue_background]},
               %Owl.Tag{
                 data: [
                   "three",
                   %Owl.Tag{
                     data: ["four"],
                     sequences: [:yellow_background]
                   }
                 ],
                 sequences: [:blue_background]
               },
               %Owl.Tag{data: ["five"], sequences: [:yellow_background, :red]},
               %Owl.Tag{data: ["six"], sequences: [:yellow_background, :red]},
               "seven",
               "eight",
               %Owl.Tag{data: ["nine"], sequences: [:blue_background]},
               %Owl.Tag{data: ["ten"], sequences: [:blue_background]}
             ]
    end

    test "6" do
      assert Owl.Data.split(
               %Owl.Tag{
                 data: [
                   "┌",
                   "──────────────────",
                   "┐",
                   "\n",
                   [
                     [
                       "│",
                       "  ",
                       %Owl.Tag{data: ["im doing great"], sequences: [:red]},
                       "  ",
                       "│"
                     ]
                   ],
                   "\n",
                   "└",
                   "──────────────────",
                   "┘"
                 ],
                 sequences: [:red, :black_background]
               },
               "\n"
             )
             <~> [
               %Owl.Tag{
                 data: ["┌", "──────────────────", "┐"],
                 sequences: [:black_background, :red]
               },
               %Owl.Tag{
                 data: [
                   "│",
                   "  ",
                   %Owl.Tag{data: ["im doing great"], sequences: [:red]},
                   "  ",
                   "│"
                 ],
                 sequences: [:black_background, :red]
               },
               %Owl.Tag{
                 data: ["└", "──────────────────", "┘"],
                 sequences: [:black_background, :red]
               }
             ]
    end

    test "7" do
      assert Owl.Data.split(
               [
                 Owl.Data.tag(["1\n", Owl.Data.tag(["2"], :red)], :cyan),
                 "\n---"
               ],
               "\n"
             ) == [
               Owl.Data.tag(["1"], :cyan),
               Owl.Data.tag(["2"], :red),
               "---"
             ]
    end

    test "8" do
      assert Owl.Data.split(["foo@", Owl.Data.tag("bar!", :red), Owl.Data.tag("baz?", :green)], [
               "@",
               "!",
               "?"
             ]) == ["foo", Owl.Data.tag(["bar"], :red), Owl.Data.tag(["baz"], :green), []]

      assert Owl.Data.split(
               ["@foo@", Owl.Data.tag("!bar!", :red), Owl.Data.tag("?baz?", :green)],
               ["@", "!", "?"]
             ) == [
               [],
               "foo",
               [],
               Owl.Data.tag(["bar"], :red),
               [],
               Owl.Data.tag(["baz"], :green),
               []
             ]
    end

    test "9" do
      assert Owl.Data.split(~c"hello", "e") == ["h", ["l", "l", "o"]]
    end
  end

  describe inspect(&Owl.Data.chunk_very/2) do
    test "1" do
      input = [
        "first second ",
        Owl.Data.tag(["third fourth", Owl.Data.tag(" fifth sixth", :blue)], :red)
      ]

      assert Owl.Data.chunk_every(input, 10) == [
               "first seco",
               ["nd ", Owl.Data.tag(["third f"], :red)],
               Owl.Data.tag(["ourth", Owl.Data.tag([" fift"], :blue)], :red),
               Owl.Data.tag(["h sixth"], :blue)
             ]

      # same length as in first element
      assert Owl.Data.chunk_every(input, 13) == [
               "first second ",
               Owl.Data.tag(["third fourth", Owl.Data.tag([" "], :blue)], :red),
               Owl.Data.tag(["fifth sixth"], :blue)
             ]
    end
  end

  test inspect(&Owl.Data.to_chardata/1) do
    assert Owl.Data.to_chardata(["1", "2", ["3", "4"], "5"]) == [
             [[[[[], "1"], "2"], "3"], "4"],
             "5"
           ]

    assert Owl.Data.to_chardata(Owl.Data.tag("Hello", :red)) == [
             [[[[] | "\e[31m"], "Hello"] | "\e[39m"] | "\e[0m"
           ]

    assert to_string(
             Owl.Data.to_chardata([
               Owl.Data.tag(
                 [
                   Owl.Data.tag("prefix: ", [:red_background, :yellow]),
                   "Hello",
                   Owl.Data.tag(" inner ", :yellow),
                   " world"
                 ],
                 :red
               ),
               Owl.Data.tag("!!!", :blue),
               "!!"
             ])
           ) in [
             "\e[31m\e[41m\e[33mprefix: \e[31m\e[49mHello\e[33m inner \e[31m world\e[39m\e[34m!!!\e[39m!!\e[0m",
             "\e[31m\e[33m\e[41mprefix: \e[49m\e[31mHello\e[33m inner \e[31m world\e[39m\e[34m!!!\e[39m!!\e[0m"
           ]

    assert Owl.Data.to_chardata([Owl.Data.tag("#", :red), Owl.Data.tag("#", :red)]) == [
             [[[[[[[] | "\e[31m"], "#"] | "\e[39m"] | "\e[31m"], "#"] | "\e[39m"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(
             Owl.Data.tag(["Hello ", Owl.Data.tag("world", :blink_off), "!"], :blink_slow)
           ) == [
             [[[[[[[[] | "\e[5m"], "Hello "] | "\e[25m"], "world"] | "\e[5m"], "!"] | "\e[25m"]
             | "\e[0m"
           ]

    assert Owl.Data.to_chardata(
             Owl.Data.tag(["Hello ", Owl.Data.tag("world", :blink_off), "!"], :blink_rapid)
           ) == [
             [[[[[[[[] | "\e[6m"], "Hello "] | "\e[25m"], "world"] | "\e[6m"], "!"] | "\e[25m"]
             | "\e[0m"
           ]

    assert Owl.Data.to_chardata(
             Owl.Data.tag(["Hello ", Owl.Data.tag("world", :normal), "!"], :faint)
           ) == [
             [[[[[[[[] | "\e[2m"], "Hello "] | "\e[22m"], "world"] | "\e[2m"], "!"] | "\e[22m"]
             | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :bright), "!"]) == [
             [[[[[[], "Hello "] | "\e[1m"], "world"] | "\e[22m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :inverse), "!"]) == [
             [[[[[[], "Hello "] | "\e[7m"], "world"] | "\e[27m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :underline), "!"]) == [
             [[[[[[], "Hello "] | "\e[4m"], "world"] | "\e[24m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(
             Owl.Data.tag(["Hello ", Owl.Data.tag("world", :not_italic), "!"], :italic)
           ) == [
             [[[[[[[[] | "\e[3m"], "Hello "] | "\e[23m"], "world"] | "\e[3m"], "!"] | "\e[23m"]
             | "\e[0m"
           ]

    assert Owl.Data.to_chardata(
             Owl.Data.tag(["Hello ", Owl.Data.tag("world", :not_overlined), "!"], :overlined)
           ) == [
             [[[[[[[[] | "\e[53m"], "Hello "] | "\e[55m"], "world"] | "\e[53m"], "!"] | "\e[55m"]
             | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :reverse), "!"]) == [
             [[[[[[], "Hello "] | "\e[7m"], "world"] | "\e[27m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :light_red), "!"]) == [
             [[[[[[], "Hello "] | "\e[91m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :light_red_background), "!"]) ==
             [[[[[[[], "Hello "] | "\e[101m"], "world"] | "\e[49m"], "!"] | "\e[0m"]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :default_color), "!"]) == [
             [[[[[[], "Hello "] | "\e[39m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", :default_background), "!"]) == [
             [[[[[[], "Hello "] | "\e[49m"], "world"] | "\e[49m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata(["Hello ", Owl.Data.tag("world", IO.ANSI.color(161)), "!"]) == [
             [[[[[[], "Hello "], "\e[38;5;161m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_chardata([
             "Hello ",
             Owl.Data.tag("world", IO.ANSI.color_background(161)),
             "!"
           ]) == [[[[[[[], "Hello "], "\e[48;5;161m"], "world"] | "\e[49m"], "!"] | "\e[0m"]

    assert Owl.Data.to_chardata([Owl.Data.tag([Owl.Data.tag("Hello ", :red), " world"], :red)]) ==
             [[[[[[[] | "\e[31m"] | "\e[31m"], "Hello "], " world"] | "\e[39m"] | "\e[0m"]
  end

  describe inspect(&Owl.Data.from_chardata/1) do
    test "converting to chardata and back" do
      assert to_from_chardata(Owl.Data.tag("Hello", :red)) ==
               Owl.Data.tag("Hello", :red)

      assert to_from_chardata(Owl.Data.tag(["Hello", ?!], :red)) ==
               Owl.Data.tag("Hello!", :red)

      assert to_from_chardata([Owl.Data.tag("Hello", :red), ?!]) ==
               [Owl.Data.tag("Hello", :red), "!"]

      assert to_from_chardata([Owl.Data.tag("Hello", :red), Owl.Data.tag("?!", :red)]) ==
               Owl.Data.tag(["Hello", "?!"], :red)

      assert to_from_chardata(["Hello ", Owl.Data.tag("world", :underline), "!"]) ==
               ["Hello ", Owl.Data.tag("world", :underline), "!"]

      assert to_from_chardata(["Hello ", Owl.Data.tag("world", [:red, :underline]), "!"])
             <~> ["Hello ", Owl.Data.tag("world", [:underline, :red]), "!"]

      assert to_from_chardata(
               Owl.Data.tag(["Hello, ", Owl.Data.tag("world", :underline), "!"], :red)
             )
             <~> [
               Owl.Data.tag("Hello, ", :red),
               Owl.Data.tag("world", [:underline, :red]),
               Owl.Data.tag("!", :red)
             ]

      assert to_from_chardata(["Hello ", Owl.Data.tag("world", IO.ANSI.color(161)), "!"]) ==
               ["Hello ", Owl.Data.tag("world", IO.ANSI.color(161)), "!"]

      assert to_from_chardata([
               "Hello ",
               Owl.Data.tag("world", IO.ANSI.color_background(161)),
               "!"
             ]) == ["Hello ", Owl.Data.tag("world", IO.ANSI.color_background(161)), "!"]

      assert to_from_chardata([
               Owl.Data.tag(
                 [
                   Owl.Data.tag("prefix: ", [:red_background, :yellow]),
                   "Hello",
                   Owl.Data.tag(" inner ", :yellow),
                   " world"
                 ],
                 :red
               ),
               Owl.Data.tag("!!!", :blue),
               "!!"
             ])
             <~> [
               Owl.Data.tag("prefix: ", [:red_background, :yellow]),
               Owl.Data.tag("Hello", :red),
               Owl.Data.tag(" inner ", :yellow),
               Owl.Data.tag(" world", :red),
               Owl.Data.tag("!!!", :blue),
               "!!"
             ]

      assert to_from_chardata([
               Owl.Data.tag("#", Owl.TrueColor.color(253, 151, 31)),
               Owl.Data.tag(" ", Owl.TrueColor.color(253, 151, 31)),
               Owl.Data.tag("Owl", Owl.TrueColor.color(253, 151, 31)),
               "\n",
               Owl.Data.tag("[", Owl.TrueColor.color(255, 255, 255)),
               Owl.Data.tag("![", Owl.TrueColor.color(255, 255, 255)),
               Owl.Data.tag("CI Status", Owl.TrueColor.color(255, 255, 255)),
               Owl.Data.tag("]", Owl.TrueColor.color(255, 255, 255))
             ]) == [
               Owl.Data.tag(["#", " ", "Owl"], Owl.TrueColor.color(253, 151, 31)),
               "\n",
               Owl.Data.tag(["[", "![", "CI Status", "]"], Owl.TrueColor.color(255, 255, 255))
             ]
    end

    test "converts chardata highlighted using Inspect.Algebra" do
      chardata =
        [foo: 1, bar: "two"]
        |> Inspect.Algebra.to_doc(Inspect.Opts.new(syntax_colors: IO.ANSI.syntax_colors()))
        |> Inspect.Algebra.format(:infinity)

      assert Owl.Data.from_chardata(chardata) == [
               "[",
               Owl.Data.tag("foo:", :cyan),
               " ",
               Owl.Data.tag("1", :yellow),
               ",",
               " ",
               Owl.Data.tag("bar:", :cyan),
               " ",
               Owl.Data.tag("\"two\"", :green),
               "]"
             ]
    end

    test "converts chardata fragments" do
      assert [:red, "Hello"] |> IO.ANSI.format_fragment() |> Owl.Data.from_chardata() ==
               Owl.Data.tag("Hello", :red)

      assert [:red, "Hello ", [:yellow, "world"]]
             |> IO.ANSI.format_fragment()
             |> Owl.Data.from_chardata() == [
               Owl.Data.tag("Hello ", :red),
               Owl.Data.tag("world", :yellow)
             ]
    end

    test "converts from charlists" do
      assert Owl.Data.from_chardata(["\e[31m", ~c"Hello"]) == Owl.Data.tag("Hello", :red)
    end

    test "convert data concatenated with escape sequences" do
      assert Owl.Data.from_chardata(["\e[31mHello\e[0m"]) == Owl.Data.tag("Hello", :red)
    end

    test "split multiple attributes" do
      assert Owl.Data.from_chardata("\e[31;42mHello\e[0m")
             <~> Owl.Data.tag("Hello", [:red, :green_background])

      assert Owl.Data.from_chardata("\e[4;38;2;166;226;46;48;2;33;39;112mHello\e[0m")
             <~> Owl.Data.tag("Hello", [
               :underline,
               Owl.TrueColor.color(166, 226, 46),
               Owl.TrueColor.color_background(33, 39, 112)
             ])
    end

    test "don't treat incompleted sequence as valid" do
      assert Owl.Data.from_chardata("\e[31iHello") == "\e[31iHello"
      assert Owl.Data.from_chardata("\e[31Hello") == "\e[31Hello"

      # letter is not a valid code
      assert Owl.Data.from_chardata("\e[31;X;45mHello\e[0m") == "\e[31;X;45mHello"
    end

    test "ignore unsupported display attributes" do
      # 74 is a valid code according to wiki, but rarely supported
      # https://en.wikipedia.org/wiki/ANSI_escape_code
      # and we don't support it as well
      assert Owl.Data.from_chardata("\e[31;74;45mHello\e[0m")
             <~> Owl.Data.tag("Hello", [:magenta_background, :red])
    end

    test "no content" do
      assert Owl.Data.from_chardata("") == []
      assert Owl.Data.from_chardata("\e[31m") == []
    end

    defp to_from_chardata(tagged) do
      tagged |> Owl.Data.to_chardata() |> Owl.Data.from_chardata()
    end
  end

  test inspect(&Owl.Data.slice/3) do
    assert Owl.Data.slice("hello world", 0, 5) == "hello"
    assert Owl.Data.slice("hello world", 6, 5) == "world"
    assert Owl.Data.slice("hello world", 6, 10) == "world"
    assert Owl.Data.slice(["hello", " world"], 6, 5) == "world"
    assert Owl.Data.slice(["hello", " world"], 3, 5) == ["lo", " wo"]
    assert Owl.Data.slice(["", [], "hello world"], 0, 5) == "hello"

    assert Owl.Data.slice([[], "", ["hel", ["lo", [" wo", ["rld"]]]]], 2, 7) == [
             "l",
             "lo",
             " wo",
             "r"
           ]

    assert Owl.Data.slice(Owl.Data.tag(["hello", Owl.Data.tag([" world"], :green)], :red), 3, 5) ==
             Owl.Data.tag(["lo", Owl.Data.tag([" wo"], :green)], :red)

    assert Owl.Data.slice([Owl.Data.tag("??", :red), Owl.Data.tag("!!!", :green)], 2, 1) ==
             Owl.Data.tag(["!"], :green)

    assert Owl.Data.slice(
             [
               Owl.Data.tag([], :green),
               Owl.Data.tag(Owl.Data.tag([], :blue), :cyan),
               Owl.Data.tag("??", :red),
               Owl.Data.tag("!!!", :green)
             ],
             2,
             1
           ) == Owl.Data.tag(["!"], :green)

    assert Owl.Data.slice(Owl.Data.tag(["hello", Owl.Data.tag([" world"], :green)], :red), 30, 5) ==
             []
  end
end
