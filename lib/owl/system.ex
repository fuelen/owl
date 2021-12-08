defmodule Owl.System do
  @moduledoc """
  An alternative to some `System` functions.
  """
  require Logger

  @doc """
  A wrapper around `System.cmd/3` which additionally logs executed `command` and `args`.

  If URL is found in logged message, then password in it is masked with asterisks.

  ## Examples

      > Owl.System.cmd("echo", ["test"])
      # 10:25:34.252 [debug] $ echo test
      {"test\\n", 0}

      > Owl.System.cmd("psql", ["postgresql://postgres:postgres@127.0.0.1:5432", "-tAc", "SELECT 1;"])
      # 10:25:50.947 [debug] $ psql postgresql://postgres:********@127.0.0.1:5432 -tAc 'SELECT 1;'
      {"1\\n", 0}

  """
  @spec cmd(binary(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(command, args, opts \\ []) do
    log_shell_command(command, args)
    System.cmd(command, args, opts)
  end

  defp log_shell_command(command, args) do
    command =
      case args do
        [] ->
          command

        args ->
          args =
            Enum.map_join(args, " ", fn arg ->
              if String.contains?(arg, [" ", ";"]) do
                "'" <> String.replace(arg, "'", "'\\''") <> "'"
              else
                arg
              end
            end)

          "#{command} #{args}"
      end

    command = sanitize_passwords_in_urls(command)

    Logger.debug("$ #{command}")
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
