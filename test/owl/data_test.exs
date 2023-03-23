defmodule Owl.DataTest do
  use ExUnit.Case, async: true
  doctest Owl.Data

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
             ) == [
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
             ) ==
               [
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
             ) == [
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
      assert Owl.Data.split('hello', "e") == ["h", ["l", "l", "o"]]
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

  test inspect(&Owl.Data.to_ansidata/1) do
    assert Owl.Data.to_ansidata(["1", "2", ["3", "4"], "5"]) == [
             [[[[[], "1"], "2"], "3"], "4"],
             "5"
           ]

    assert Owl.Data.to_ansidata(Owl.Data.tag("Hello", :red)) == [
             [[[[] | "\e[31m"], "Hello"] | "\e[39m"] | "\e[0m"
           ]

    assert to_string(
             Owl.Data.to_ansidata([
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
           ) ==
             "\e[31m\e[41m\e[33mprefix: \e[31m\e[49mHello\e[33m inner \e[31m world\e[39m\e[34m!!!\e[39m!!\e[0m"

    assert Owl.Data.to_ansidata([Owl.Data.tag("#", :red), Owl.Data.tag("#", :red)]) == [
             [[[[[[[] | "\e[31m"], "#"] | "\e[39m"] | "\e[31m"], "#"] | "\e[39m"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :blink_slow), "!"]) == [
             [[[[[[], "Hello "] | "\e[5m"], "world"] | "\e[25m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :blink_rapid), "!"]) == [
             [[[[[[], "Hello "] | "\e[6m"], "world"] | "\e[25m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :faint), "!"]) == [
             [[[[[[], "Hello "] | "\e[2m"], "world"] | "\e[22m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :bright), "!"]) == [
             [[[[[[], "Hello "] | "\e[1m"], "world"] | "\e[22m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :inverse), "!"]) == [
             [[[[[[], "Hello "] | "\e[7m"], "world"] | "\e[27m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :underline), "!"]) == [
             [[[[[[], "Hello "] | "\e[4m"], "world"] | "\e[24m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :italic), "!"]) == [
             [[[[[[], "Hello "] | "\e[3m"], "world"] | "\e[23m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :overlined), "!"]) == [
             [[[[[[], "Hello "] | "\e[53m"], "world"] | "\e[55m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :reverse), "!"]) == [
             [[[[[[], "Hello "] | "\e[7m"], "world"] | "\e[27m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :light_red), "!"]) == [
             [[[[[[], "Hello "] | "\e[91m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :light_red_background), "!"]) ==
             [[[[[[[], "Hello "] | "\e[101m"], "world"] | "\e[49m"], "!"] | "\e[0m"]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :default_color), "!"]) == [
             [[[[[[], "Hello "] | "\e[39m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", :default_background), "!"]) == [
             [[[[[[], "Hello "] | "\e[49m"], "world"] | "\e[49m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata(["Hello ", Owl.Data.tag("world", IO.ANSI.color(161)), "!"]) == [
             [[[[[[], "Hello "], "\e[38;5;161m"], "world"] | "\e[39m"], "!"] | "\e[0m"
           ]

    assert Owl.Data.to_ansidata([
             "Hello ",
             Owl.Data.tag("world", IO.ANSI.color_background(161)),
             "!"
           ]) == [[[[[[[], "Hello "], "\e[48;5;161m"], "world"] | "\e[49m"], "!"] | "\e[0m"]

    assert Owl.Data.to_ansidata([Owl.Data.tag([Owl.Data.tag("Hello ", :red), " world"], :red)]) ==
             [[[[[[[] | "\e[31m"] | "\e[31m"], "Hello "], " world"] | "\e[39m"] | "\e[0m"]
  end

  describe inspect(&Owl.Data.from_ansidata/1) do
    test "converting to ansidata and back" do
      assert to_from_ansidata(Owl.Data.tag("Hello", :red)) ==
               Owl.Data.tag("Hello", :red)

      assert to_from_ansidata(["Hello ", Owl.Data.tag("world", :underline), "!"]) ==
               [["Hello ", Owl.Data.tag("world", :underline)], "!"]

      assert to_from_ansidata(["Hello ", Owl.Data.tag("world", [:red, :underline]), "!"]) ==
               [["Hello ", Owl.Data.tag("world", [:red, :underline])], "!"]

      assert to_from_ansidata(
               Owl.Data.tag(["Hello, ", Owl.Data.tag("world", :underline), "!"], :red)
             ) == [
               [Owl.Data.tag("Hello, ", :red), Owl.Data.tag("world", [:red, :underline])],
               Owl.Data.tag("!", :red)
             ]

      assert to_from_ansidata(["Hello ", Owl.Data.tag("world", IO.ANSI.color(161)), "!"]) ==
               [["Hello ", Owl.Data.tag("world", "\e[38;5;161m")], "!"]

      assert to_from_ansidata([
               "Hello ",
               Owl.Data.tag("world", IO.ANSI.color_background(161)),
               "!"
             ]) == [["Hello ", Owl.Data.tag("world", "\e[48;5;161m")], "!"]

      assert to_from_ansidata([
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
             ]) == [
               [
                 [
                   [
                     [
                       Owl.Data.tag("prefix: ", [:red_background, :yellow]),
                       Owl.Data.tag("Hello", :red)
                     ],
                     Owl.Data.tag(" inner ", :yellow)
                   ],
                   Owl.Data.tag(" world", :red)
                 ],
                 Owl.Data.tag("!!!", :blue)
               ],
               "!!"
             ]
    end

    test "converts ansidata highlighted using Inspect.Algebra" do
      ansidata =
        %{foo: 1, bar: "two"}
        |> Inspect.Algebra.to_doc(Inspect.Opts.new(syntax_colors: IO.ANSI.syntax_colors()))
        |> Inspect.Algebra.format(:infinity)

      assert Owl.Data.from_ansidata(ansidata) == [
               "%{",
               [
                 "",
                 [
                   Owl.Data.tag("bar:", :cyan),
                   [
                     " ",
                     [
                       Owl.Data.tag(~S("two"), :green),
                       [
                         ",",
                         [
                           " ",
                           [
                             Owl.Data.tag("foo:", :cyan),
                             [" ", [Owl.Data.tag("1", :yellow), ["", "}"]]]
                           ]
                         ]
                       ]
                     ]
                   ]
                 ]
               ]
             ]
    end

    test "converts ansidata fragments" do
      assert [:red, "Hello"] |> IO.ANSI.format_fragment() |> Owl.Data.from_ansidata() ==
               Owl.Data.tag("Hello", :red)

      assert [:red, "Hello ", [:yellow, "world"]]
             |> IO.ANSI.format_fragment()
             |> Owl.Data.from_ansidata() == [
               Owl.Data.tag("Hello ", :red),
               Owl.Data.tag("world", :yellow)
             ]
    end

    test "does not convert data concatenated with escape sequences" do
      assert Owl.Data.from_ansidata(["\e[31mHello\e[0m"]) == "\e[31mHello\e[0m"
    end

    defp to_from_ansidata(tagged) do
      tagged |> Owl.Data.to_ansidata() |> Owl.Data.from_ansidata()
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
