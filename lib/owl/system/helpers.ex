defmodule Owl.System.Helpers do
  @moduledoc false
  require Logger

  @secret_placeholder "********"

  def normalize_env_option(opts) do
    Keyword.update(opts, :env, [], &normalize_env/1)
  end

  def normalize_cmd_args(args) do
    Enum.map(
      args,
      fn
        {:secret, arg} when is_binary(arg) ->
          arg

        arg when is_binary(arg) ->
          arg

        parts when is_list(parts) ->
          Enum.map_join(parts, fn
            part when is_binary(part) -> part
            {:secret, part} when is_binary(part) -> part
          end)
      end
    )
  end

  def normalize_env(env) do
    Enum.map(
      env,
      fn
        {variable, {:secret, value}} -> {variable, value}
        item -> item
      end
    )
  end

  def log_shell(env, command) do
    log_command(env, command, :force)
  end

  def log_cmd(env, command, args) do
    command =
      case args do
        [] ->
          command

        args ->
          args =
            Enum.map_join(args, " ", fn
              {:secret, _arg} ->
                @secret_placeholder

              arg ->
                arg
                |> List.wrap()
                |> Enum.map_join(fn
                  {:secret, _arg} -> @secret_placeholder
                  arg -> arg
                end)
                |> maybe_quote_arg()
            end)

          "#{command} #{args}"
      end

    log_command(env, command, :auto)
  end

  defp log_command(env, command, shell) do
    command =
      if shell == :force or (shell == :auto and not Enum.empty?(env)) do
        wrap_command_to_shell(command)
      else
        command
      end

    command =
      command
      |> prepend_env(env)
      |> sanitize_passwords_in_urls()

    Logger.debug("$ #{command}")
  end

  defp wrap_command_to_shell(command) do
    case :os.type() do
      {:unix, _} ->
        command = command |> String.replace("\"", "\\\"") |> String.replace("$", "\\$")
        "sh -c \"#{command}\""

      {:win32, _osname} ->
        raise "windows is not supported yet"
    end
  end

  defp prepend_env(command, []), do: command

  defp prepend_env(command, env) do
    env =
      Enum.map_join(env, " ", fn
        {variable, {:secret, _value}} ->
          "#{variable}=#{@secret_placeholder}"

        {variable, nil} ->
          "#{variable}="

        {variable, value} ->
          "#{variable}=#{maybe_quote_arg(value)}"
      end)

    "#{env} #{command}"
  end

  defp maybe_quote_arg(arg) do
    if String.contains?(arg, [" ", ";", "$", "'"]) do
      "'" <> String.replace(arg, "'", "'\\''") <> "'"
    else
      arg
    end
  end

  defp sanitize_passwords_in_urls(text) do
    Regex.replace(~r/(\w+:\/\/[^:]+:)(.+?)@/, text, "\\1#{@secret_placeholder}@")
  end
end
