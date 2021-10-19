defmodule Owl do
  def input(type, opts \\ []) do
    value =
      case String.trim(IO.gets(Keyword.fetch!(opts, :prompt) <> "\n")) do
        "" -> nil
        string -> string
      end

    cond do
      not Keyword.get(opts, :allow_blank, false) and is_nil(value) ->
        puts(Owl.Data.tag(:red, "Cannot be blank"))
        input(type, opts)

      true ->
        value
    end
  end

  def cmd(command, args, opts \\ []) do
    log_shell_command(command, args)
    System.cmd(command, args, opts)
  end

  def log_shell_command(command, args) do
    command =
      case args do
        [] -> command
        args -> "#{command} #{Enum.join(args, " ")}"
      end

    command = sanitize_passwords_in_urls(command)

    puts(Owl.Data.tag(:light_black, "$ #{command}"))
  end

  def puts(content) do
    content
    |> Owl.Data.to_iodata()
    |> IO.puts()
  end

  defp sanitize_passwords_in_urls(text) do
    Regex.replace(~r/\w+:\/\/[^ ]+/, text, fn value ->
      uri = URI.parse(value)

      case uri.userinfo do
        nil ->
          value

        userinfo ->
          [username, _password] = String.split(userinfo, ":")
          to_string(%{uri | userinfo: username <> ":********"})
      end
    end)
  end
end
