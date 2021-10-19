defmodule Owl.Data.Tag do
  defstruct sequences: [], data: []

  @doc false
  def new(data, sequences) do
    %__MODULE__{
      sequences: List.wrap(sequences),
      data: data
    }
  end
end
