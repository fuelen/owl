defmodule Owl.System do
  @moduledoc """
  An alternative to some `System` functions.
  """
  require Logger

  @secret_placeholder "********"

  @doc """
  A wrapper around `System.cmd/3` which additionally logs executed `command` and `args`.

  If URL is found in logged message, then password in it is masked with asterisks.
  Additionally, it is possible to explicitly mark a whole argument as secret.

  ## Examples

      > Owl.System.cmd("echo", ["test"])
      # 10:25:34.252 [debug] $ echo test
      {"test\\n", 0}

      > Owl.System.cmd("echo", ["hello", secret: "world"])
      # 10:25:40.516 [debug] $ echo hello ********
      {"hello world\\n", 0}

      > Owl.System.cmd("psql", ["postgresql://postgres:postgres@127.0.0.1:5432", "-tAc", "SELECT 1;"])
      # 10:25:50.947 [debug] $ psql postgresql://postgres:#{@secret_placeholder}@127.0.0.1:5432 -tAc 'SELECT 1;'
      {"1\\n", 0}

  """
  @spec cmd(binary(), [binary() | {:secret, binary()}], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(command, args, opts \\ []) when is_binary(command) and is_list(args) do
    log_shell_command(command, args)

    args =
      Enum.map(
        args,
        fn
          {:secret, arg} when is_binary(arg) -> arg
          arg when is_binary(arg) -> arg
        end
      )

    System.cmd(command, args, opts)
  end

  @doc """
  A wrapper around `System.shell/2` which additionally logs executed `command`.

  Similarly to `cmd/3`, it automatically hides password in found URLs.

  ## Examples

      > Owl.System.shell("echo hello world")
      # 22:36:01.440 [debug] $ echo hello world
      {"hello world\\n", 0}

      > Owl.System.shell("echo postgresql://postgres:postgres@127.0.0.1:5432")
      # 22:36:51.797 [debug] $ echo postgresql://postgres:********@127.0.0.1:5432
      {"postgresql://postgres:postgres@127.0.0.1:5432\\n", 0}
  """
  @spec shell(
          binary(),
          keyword()
        ) :: {Collectable.t(), exit_status :: non_neg_integer()}
  def shell(command, opts \\ []) when is_binary(command) do
    log_shell_command(command)
    System.shell(command, opts)
  end

  defp log_shell_command(command) do
    command = sanitize_passwords_in_urls(command)

    Logger.debug("$ #{command}")
  end

  defp log_shell_command(command, args) do
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
                if String.contains?(arg, [" ", ";"]) do
                  "'" <> String.replace(arg, "'", "'\\''") <> "'"
                else
                  arg
                end
            end)

          "#{command} #{args}"
      end

    log_shell_command(command)
  end

  defp sanitize_passwords_in_urls(text) do
    Regex.replace(~r/\w+:\/\/[^ ]+/, text, fn value ->
      uri = URI.parse(value)

      case uri.userinfo do
        nil ->
          value

        userinfo ->
          [username, _password] = String.split(userinfo, ":")
          to_string(%{uri | userinfo: "#{username}:#{@secret_placeholder}"})
      end
    end)
  end
end
