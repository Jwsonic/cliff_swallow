defmodule Printer.Server.Wait do
  @moduledoc """
  Logic around which commands a printer should wait for, and how long.
  """

  defstruct [
    :command,
    :context,
    :reference,
    :response_matcher,
    :timeout
  ]

  alias __MODULE__

  @type t() :: %Wait{}

  defp ok_response_matcher(_context, "ok"), do: :done
  defp ok_response_matcher(context, _response), do: {:wait, context}

  defp m109_response_matcher(nil, "ok") do
    {:wait, false}
  end

  defp m109_response_matcher(false, "T:" <> _rest) do
    {:wait, true}
  end

  defp m109_response_matcher(true, "ok") do
    :done
  end

  @spec build(command :: String.t()) :: t()

  def build("M109" <> _rest = command) do
    %Wait{
      command: command,
      context: nil,
      response_matcher: &m109_response_matcher/2,
      timeout: 1_000 * 60 * 5
    }
  end

  def build(command) do
    %Wait{
      command: command,
      context: nil,
      response_matcher: &ok_response_matcher/2,
      timeout: 500
    }
  end

  @spec check(wait :: t(), response :: String.t()) :: {:wait, t()} | :done
  def check(%Wait{context: context, response_matcher: response_matcher} = wait, response) do
    with {:wait, context} <- apply(response_matcher, [context, response]) do
      {:wait, %{wait | context: context}}
    end
  end

  @spec schedule_timeout(wait :: t()) :: reference()
  def schedule_timeout(%Wait{timeout: timeout}) do
    reference = make_ref()

    Process.send_after(self(), {:send_timeout, reference}, timeout)

    reference
  end
end