defmodule Owl.System.Helpers do
  @moduledoc false
  require Logger

  @secret_placeholder "********"

  def log_shell_command(command) do
    command = sanitize_passwords_in_urls(command)

    Logger.debug("$ #{command}")
  end

  def log_shell_command(command, args) do
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
