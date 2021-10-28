defmodule Owl.IO do
  @moduledoc "A set of functions for handling IO with support of `t:Owl.Data.t/0`"

  @type select_opt :: {:label, Owl.Data.t()} | {:as, (any() -> Owl.Data.t())}

  @doc """
  Selects one of the suggested items.

  Returns `nil` if empty list is given.

  Returns value immediatelly if list contains only 1 element.

  ## Options

  * `:label` - a text label. Defaults to `nil` (no label).
  * `:as` - a function that renders given item. Defaults to `Function.identity/1`.

  ## Examples

      Owl.IO.select(["one", "two", "three"])
      #=> 1. one
      #=> 2. two
      #=> 3. three
      #=>
      #=> > 1
      "one"


      ~D[2001-01-01]
      |> Date.range(~D[2001-01-03])
      |> Enum.to_list()
      |> Owl.IO.select(as: &Date.to_iso8601/1, label: "Please select a date")
      #=> 1. 2001-01-01
      #=> 2. 2001-01-02
      #=> 3. 2001-01-03
      #=>
      #=> Please select a date
      #=> > 2
      ~D[2001-01-02]


      packages = [
        %{name: "elixir", description: "programming language"},
        %{name: "asdf", description: "version manager"},
        %{name: "neovim", description: "fork of vim"}
      ]
      Owl.IO.select(packages,
        as: fn %{name: name, description: description} ->
          [Owl.Tag.new(name, :cyan), "\\n  ", Owl.Tag.new(description, :light_black)]
        end
      )
      #=> 1. elixir
      #=>      programming language
      #=> 2. asdf
      #=>      version manager
      #=> 3. neovim
      #=>      fork of vim
      #=>
      #=> > 3
      %{description: "fork of vim", name: "neovim"}
  """
  @spec select([], [select_opt()]) :: nil
  @spec select([item], [select_opt()]) :: item when item: any()
  def select(list, opts \\ []) do
    label = Keyword.get(opts, :label)
    render_item = Keyword.get(opts, :as, &Function.identity/1)

    case list do
      [] ->
        nil

      [item] ->
        puts("Autoselect: #{render_item.(item)}")
        item

      list ->
        list
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} ->
          rendered_item = render_item.(item)

          [Owl.Tag.new(index, :blue), ". "]
          |> Owl.Box.new(border_style: :none, min_height: length(Owl.Data.lines(rendered_item)))
          |> Owl.Data.zip(rendered_item)
        end)
        |> Owl.Data.unlines()
        |> puts()

        IO.puts([])

        index = input(cast: {:integer, bounds: 1..length(list)}, label: label) - 1
        Enum.at(list, index)
    end
  end

  @doc """
  Opens `data` in editor for editing.

  Returns updated data when file is saved and editor is closed.
  Similarly to `IEx.Helpers.open/1`, this function uses `ELIXIR_EDITOR` environment variable.
  `__FILE__` notation is supported as well.

  ## Example

      # use neovim in alacritty terminal emulator as an editor
      $ export ELIXIR_EDITOR="alacritty -e nvim"

      # open editor from Elixir code
      Owl.IO.open_in_editor("hello\\nworld")
  """
  @spec open_in_editor(iodata()) :: String.t()
  def open_in_editor(data) do
    elixir_editor = System.fetch_env!("ELIXIR_EDITOR")
    dir = System.tmp_dir!()
    filename = "owl-#{random_string()}"
    tmp_file = Path.join(dir, filename)
    File.write!(tmp_file, data)

    elixir_editor =
      if String.contains?(elixir_editor, "__FILE__") do
        String.replace(elixir_editor, "__FILE__", tmp_file)
      else
        elixir_editor <> " " <> tmp_file
      end

    {_, 0} = System.shell(elixir_editor)
    File.read!(tmp_file)
  end

  defp random_string do
    length = 9

    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  @type confirm_opt :: {:message, Owl.Data.t()} | {:default, boolean()}

  @default_confirmation_message "Are you sure?"
  @doc """
  Asks user to type a confirmation.

  Valid inputs are `y`, `Y`, `n`, `N` and blank string. User will be asked to type a confirmation again on invalid input.

  ## Options

  * `:message` - typically a question about performing operation. Defaults to `#{inspect(@default_confirmation_message)}`.
  * `:default` - a value that is used when user responds with a blank string. Defaults to `false`.

  ## Examples

      Owl.IO.confirm()
      #=> Are you sure? [yN] n
      false

      Owl.IO.confirm(message: Owl.Tag.new("Really?", :red), default: true)
      #=> Really? [Yn]
      true
  """
  @spec confirm([confirm_opt()]) :: boolean()
  def confirm(opts \\ []) do
    message = Keyword.get(opts, :message, @default_confirmation_message)
    default = Keyword.get(opts, :default, false)

    choices =
      if default do
        "Yn"
      else
        "yN"
      end

    case gets(:string, [message, " [", choices, "]: "]) do
      nil ->
        default

      value when value in ["Y", "y"] ->
        true

      value when value in ["N", "n"] ->
        false

      _unknown ->
        report_error("unknown choice")
        confirm(opts)
    end
  end

  @type cast_input :: (String.t() -> {:ok, value :: any()} | {:error, reason :: String.Chars.t()})
  @type input_opt ::
          {:label, Owl.Data.t()} | {:cast, atom() | {atom(), Keyword.t()} | cast_input()}

  @doc """
  Reads a line from the `stdio` and casts a value to the given type.

  After reading a line from `stdio` it will be automatically trimmed with `String.trim/2`.
  The end value will be returned when user types a valid value. 

  ## Options

  * `:secret` - set to `true` if you want to make input invisible. Defaults to `false`.
  * `:label` - a text label. Defaults to `nil` (no label).
  * `:optional` - a boolean that sets whether value is optional. Defaults to `false`.
  * `:cast` - casts a value after reading it from `stdio`. Defaults to `:string`. Possible values:
    * an anonymous function with arity 1 that is described by `t:cast_input/0`
    * a pair with atom which references to built-in type and options:
      * `:string`, options:
        * no options
      * `:integer`, options:
        * `:bounds` - a range of valid values.
    * an atom which is simply an alias to `{atom(), []}`

  ## Examples

      Owl.IO.input()
      #=> > hello world
      "hello world"

      Owl.IO.input(secret: true)
      #=> >
      "password"

      Owl.IO.input(optional: true)
      #=> > 
      nil

      Owl.IO.input(label: "Your age", cast: {:integer, bounds: 18..100})
      #=> Your age
      #=> > 101
      #=> must be between 18..100
      #=> Your age
      #=> > 18
      18

      Owl.IO.input(label: "Birth date in ISO 8601 format:", cast: &Date.from_iso8601/1)
      #=> Birth date in ISO 8601 format:
      #=> > 1 January
      #=> invalid_format
      #=> Birth date in ISO 8601 format:
      #=> > 2021-01-01
      ~D[2021-01-01]
  """
  @spec input([input_opt()]) :: any()
  def input(opts \\ []) do
    cast =
      case Keyword.get(opts, :cast) || :string do
        type_name when is_atom(type_name) ->
          &cast_input(type_name, &1, [])

        {type_name, opts} when is_atom(type_name) and is_list(opts) ->
          &cast_input(type_name, &1, opts)

        callback when is_function(callback, 1) ->
          callback
      end

    label =
      case Keyword.get(opts, :label) do
        nil -> []
        value -> [value, "\n"]
      end

    secret = Keyword.get(opts, :secret, false)

    value = gets(secret, [label, Owl.Tag.new("> ", :blue)])

    [&validate_required(&1, opts), cast]
    |> Enum.reduce_while({:ok, value}, fn
      callback, {:ok, value} ->
        case callback.(value) do
          {:ok, value} -> {:cont, {:ok, value}}
          {:error, reason} -> {:halt, {:error, to_string(reason)}}
        end
    end)
    |> case do
      {:ok, value} ->
        value

      {:error, reason} ->
        report_error(reason)
        input(opts)
    end
  end

  # https://github.com/hexpm/hex/blob/1523f44e8966d77a2c71738629912ad59627b870/lib/mix/hex/utils.ex#L32-L58
  defp gets(true = _secret, prompt) do
    [last_row | rest] = prompt |> Owl.Data.lines() |> Enum.reverse()

    case rest do
      [] -> :noop
      rest -> puts(rest |> Enum.reverse() |> Owl.Data.unlines())
    end

    prompt = Owl.Data.to_ansidata(last_row)
    pid = spawn_link(fn -> loop_prompt(prompt) end)
    ref = make_ref()
    value = IO.gets(prompt)

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    normalize_gets_result(value)
  end

  defp gets(false = _secret, prompt) do
    prompt
    |> Owl.Data.to_ansidata()
    |> IO.gets()
    |> normalize_gets_result()
  end

  defp normalize_gets_result(value) do
    case String.trim(value) do
      "" -> nil
      string -> string
    end
  end

  defp loop_prompt(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, ["\e[2K\r", prompt])
        loop_prompt(prompt)
    end
  end

  defp report_error(text) do
    Owl.IO.puts(Owl.Tag.new(text, :red))
  end

  defp validate_required(value, opts) do
    optional? = Keyword.get(opts, :optional, false)

    if is_nil(value) and not optional? do
      {:error, "is required"}
    else
      {:ok, value}
    end
  end

  defp cast_input(:integer, binary, opts) do
    case Integer.parse(binary) do
      {number, ""} ->
        case opts[:bounds] do
          nil ->
            {:ok, number}

          bounds ->
            if number in bounds do
              {:ok, number}
            else
              {:error, "must be between #{inspect(bounds)}"}
            end
        end

      _ ->
        {:error, "not an integer"}
    end
  end

  defp cast_input(:string, binary, _opts), do: {:ok, binary}

  @doc """
  Wrapper around `IO.puts/2` that accepts `t:Owl.Data.t/0`

  ## Example

      Owl.IO.puts(["Hello ", Owl.Tag.new("world", :green)])
      #=> Hello world
  """
  @spec puts(Owl.Data.t()) :: :ok
  def puts(data) do
    data = Owl.Data.to_ansidata(data)

    IO.puts(data)
  end
end
