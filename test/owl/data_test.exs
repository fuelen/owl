defmodule Owl.DataTest do
  use ExUnit.Case

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
               %Owl.Data.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Data.Tag{data: ["hi", "a"], sequences: [:green]}
             ],
             "\n",
             [
               %Owl.Data.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Data.Tag{
                 data: ["and new", " line ", %Owl.Data.Tag{data: [" hey"], sequences: [:red]}],
                 sequences: [:green]
               }
             ],
             "\n",
             [
               %Owl.Data.Tag{data: "PREFIX: ", sequences: [:yellow]},
               %Owl.Data.Tag{
                 data: [%Owl.Data.Tag{data: [" aloha"], sequences: [:red]}, "!!"],
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
                 %Owl.Data.Tag{data: ["first"], sequences: [:green]},
                 %Owl.Data.Tag{data: ["second"], sequences: [:green]},
                 %Owl.Data.Tag{data: ["third"], sequences: [:green]}
               ]

      assert Owl.Data.split(Owl.Data.tag(["first", "\n", "second", "aloha"], :green), "\n") == [
               %Owl.Data.Tag{data: ["first"], sequences: [:green]},
               %Owl.Data.Tag{data: ["second", "aloha"], sequences: [:green]}
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
               %Owl.Data.Tag{data: ["hi", "a"], sequences: [:green]},
               %Owl.Data.Tag{
                 data: ["and new", " line ", Owl.Data.tag([" hey"], :red)],
                 sequences: [:green]
               },
               %Owl.Data.Tag{data: [Owl.Data.tag([" aloha"], :red), "!!"], sequences: [:green]}
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
               %Owl.Data.Tag{data: ["one"], sequences: [:blue_background, :green]},
               %Owl.Data.Tag{data: ["two"], sequences: [:blue_background, :green]},
               %Owl.Data.Tag{data: ["three"], sequences: [:blue_background, :green]},
               %Owl.Data.Tag{data: ["four"], sequences: [:green]}
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
                 %Owl.Data.Tag{data: ["two"], sequences: [:blue_background]},
                 %Owl.Data.Tag{
                   data: [
                     "three",
                     %Owl.Data.Tag{
                       data: ["four"],
                       sequences: [:yellow_background]
                     }
                   ],
                   sequences: [:blue_background]
                 },
                 %Owl.Data.Tag{data: ["five"], sequences: [:yellow_background, :red]},
                 %Owl.Data.Tag{data: ["six"], sequences: [:yellow_background, :red]},
                 "seven",
                 "eight",
                 %Owl.Data.Tag{data: ["nine"], sequences: [:blue_background]},
                 %Owl.Data.Tag{data: ["ten"], sequences: [:blue_background]}
               ]
    end

    test "6" do
      assert Owl.Data.split(
               %Owl.Data.Tag{
                 data: [
                   "┌",
                   "──────────────────",
                   "┐",
                   "\n",
                   [
                     [
                       "│",
                       "  ",
                       %Owl.Data.Tag{data: ["im doing great"], sequences: [:red]},
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
               %Owl.Data.Tag{
                 data: ["┌", "──────────────────", "┐"],
                 sequences: [:black_background, :red]
               },
               %Owl.Data.Tag{
                 data: [
                   "│",
                   "  ",
                   %Owl.Data.Tag{data: ["im doing great"], sequences: [:red]},
                   "  ",
                   "│"
                 ],
                 sequences: [:black_background, :red]
               },
               %Owl.Data.Tag{
                 data: ["└", "──────────────────", "┘"],
                 sequences: [:black_background, :red]
               }
             ]
    end
  end
end
