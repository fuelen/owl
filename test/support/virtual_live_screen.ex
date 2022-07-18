defmodule VirtualLiveScreen do
  defmodule Device do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, [])
    end

    @impl true
    def init(pid: pid) do
      {:ok, %{pid: pid}}
    end

    @impl true
    def handle_info({:io_request, from, reply_as, req}, state) do
      state = io_request(from, reply_as, req, state)
      {:noreply, state}
    end

    def handle_info(_message, state) do
      {:noreply, state}
    end

    defp io_request(from, reply_as, req, state) do
      {reply, state} = io_request(req, state)
      io_reply(from, reply_as, reply)
      state
    end

    defp io_request({:put_chars, chars} = _req, state) do
      put_chars(chars, state)
    end

    defp io_request({:put_chars, mod, fun, args}, state) do
      put_chars(apply(mod, fun, args), state)
    end

    defp io_request({:put_chars, _encoding, chars}, state) do
      put_chars(chars, state)
    end

    defp io_request({:put_chars, _encoding, mod, fun, args}, state) do
      put_chars(apply(mod, fun, args), state)
    end

    defp io_request({:get_chars, prompt, count}, state) when count >= 0 do
      io_request({:get_chars, :latin1, prompt, count}, state)
    end

    defp io_request({:get_chars, _encoding, _prompt, count}, state) when count >= 0 do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_line, _prompt}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_line, _encoding, _prompt}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_until, _prompt, _mod, _fun, _args}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_until, _encoding, _prompt, _mod, _fun, _args}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_password, _encoding}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:setopts, _opts}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request(:getopts, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_geometry, :columns}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:get_geometry, :rows}, state) do
      {{:error, :enotsup}, state}
    end

    defp io_request({:requests, reqs}, state) do
      io_requests(reqs, {:ok, state})
    end

    defp io_request(_, state) do
      {{:error, :request}, state}
    end

    ## put_chars

    defp put_chars(chars, state) do
      send(state.pid, {:live_screen_frame, to_string(chars)})
      {:ok, state}
    end

    ## io_requests

    defp io_requests([req | rest], {:ok, state}) do
      io_requests(rest, io_request(req, state))
    end

    defp io_requests(_, result) do
      result
    end

    # helpers
    defp io_reply(from, reply_as, reply) do
      send(from, {:io_reply, reply_as, reply})
    end
  end

  def capture_frames(callback, opts \\ []) when is_function(callback, 2) do
    device = ExUnit.Callbacks.start_supervised!({__MODULE__.Device, pid: self()})

    live_screen_pid =
      ExUnit.Callbacks.start_supervised!(
        {Owl.LiveScreen, Keyword.merge([terminal_width: 50, device: device], opts)}
      )

    callback.(live_screen_pid, fn -> GenServer.call(live_screen_pid, :render) end)

    Owl.LiveScreen.stop(live_screen_pid)
    GenServer.stop(device)
  end
end
