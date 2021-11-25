defmodule Owl.DataTest do
  use ExUnit.Case, async: true
  doctest Owl.Data

  test inspect(&Owl.Data.length/2) do
    assert Owl.Data.length(Owl.Tag.new("one", :green)) == 3
    assert Owl.Data.length(Owl.Tag.new(["one", "two"], :green)) == 6

    assert Owl.Data.length([
             "one",
             ["two", "three"],
             Owl.Tag.new(["four", "five"], :green),
             "six"
           ]) == 22
  end

  test inspect(&Owl.Data.add_prefix/2) do
    data =
      Owl.Tag.new(
        [
          "hi",
          "a\nand new",
          " line ",
          Owl.Tag.new(" hey\n aloha", :red),
          "!!"
        ],
        :green
      )

    assert data |> Owl.Data.add_prefix(Owl.Tag.new("PREFIX: ", :yellow)) == [
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
      assert Owl.Data.split(Owl.Tag.new("first\nsecond\nthird", :green), "\n") ==
               [
                 %Owl.Tag{data: ["first"], sequences: [:green]},
                 %Owl.Tag{data: ["second"], sequences: [:green]},
                 %Owl.Tag{data: ["third"], sequences: [:green]}
               ]

      assert Owl.Data.split(Owl.Tag.new(["first", "\n", "second", "aloha"], :green), "\n") == [
               %Owl.Tag{data: ["first"], sequences: [:green]},
               %Owl.Tag{data: ["second", "aloha"], sequences: [:green]}
             ]
    end

    test "3" do
      assert Owl.Data.split(
               Owl.Tag.new(
                 [
                   "hi",
                   "a\nand new",
                   " line ",
                   Owl.Tag.new(" hey\n aloha", :red),
                   "!!"
                 ],
                 :green
               ),
               "\n"
             ) == [
               %Owl.Tag{data: ["hi", "a"], sequences: [:green]},
               %Owl.Tag{
                 data: ["and new", " line ", Owl.Tag.new([" hey"], :red)],
                 sequences: [:green]
               },
               %Owl.Tag{data: [Owl.Tag.new([" aloha"], :red), "!!"], sequences: [:green]}
             ]
    end

    test "4" do
      assert Owl.Data.split(
               [
                 Owl.Tag.new(
                   [
                     Owl.Tag.new(["one two three"], :blue_background),
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
                 Owl.Tag.new(
                   [
                     "two three",
                     Owl.Tag.new(["four", Owl.Tag.new([" five six"], :red)], :yellow_background)
                   ],
                   :blue_background
                 ),
                 " seven eight",
                 Owl.Tag.new([" nine ten"], :blue_background)
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
                 Owl.Tag.new(["1\n", Owl.Tag.new(["2"], :red)], :cyan),
                 "\n---"
               ],
               "\n"
             ) == [
               Owl.Tag.new(["1"], :cyan),
               Owl.Tag.new(["2"], :red),
               "---"
             ]
    end
  end

  describe inspect(&Owl.Data.chunk_very/2) do
    test "1" do
      input = [
        "first second ",
        Owl.Tag.new(["third fourth", Owl.Tag.new(" fifth sixth", :blue)], :red)
      ]

      assert Owl.Data.chunk_every(input, 10) == [
               "first seco",
               ["nd ", Owl.Tag.new(["third f"], :red)],
               Owl.Tag.new(["ourth", Owl.Tag.new([" fift"], :blue)], :red),
               Owl.Tag.new(["h sixth"], :blue)
             ]

      # same length as in first element
      assert Owl.Data.chunk_every(input, 13) == [
               "first second ",
               Owl.Tag.new(["third fourth", Owl.Tag.new([" "], :blue)], :red),
               Owl.Tag.new(["fifth sixth"], :blue)
             ]
    end
  end
end
