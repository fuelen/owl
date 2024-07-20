defmodule Owl.Data.TestHelpers do
  def left <~> right do
    order_sequences_in_tags(left) == order_sequences_in_tags(right)
  end

  def order_sequences_in_tags(%Owl.Tag{} = tag) do
    %{tag | sequences: Enum.sort(tag.sequences)}
  end

  def order_sequences_in_tags([head | rest]) do
    [order_sequences_in_tags(head) | order_sequences_in_tags(rest)]
  end

  def order_sequences_in_tags(value) do
    value
  end
end
