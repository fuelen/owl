defmodule Owl.TagTest do
  use ExUnit.Case, async: true

  test "inspect protocol" do
    assert inspect(Owl.Data.tag("test", [:green])) == ~s|Owl.Data.tag("test", :green)|

    assert inspect(Owl.Data.tag("test", [:green, :blue_background])) ==
             ~s|Owl.Data.tag("test", [:green, :blue_background])|

    assert inspect(Owl.Data.tag("test", IO.ANSI.color(1))) ==
             ~s|Owl.Data.tag("test", IO.ANSI.color(1))|

    assert inspect(Owl.Data.tag("test", IO.ANSI.color_background(200))) ==
             ~s|Owl.Data.tag("test", IO.ANSI.color_background(200))|

    assert inspect(Owl.Data.tag("test", Owl.TrueColor.color(200, 100, 50))) ==
             ~s|Owl.Data.tag("test", Owl.TrueColor.color(200,100,50))|

    assert inspect(Owl.Data.tag("test", Owl.TrueColor.color_background(200, 100, 50))) ==
             ~s|Owl.Data.tag("test", Owl.TrueColor.color_background(200,100,50))|

    assert inspect(Owl.Data.tag("test", IO.ANSI.red())) == ~S|Owl.Data.tag("test", "\e[31m")|
  end
end
