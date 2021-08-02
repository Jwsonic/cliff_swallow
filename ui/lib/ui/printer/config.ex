defprotocol Ui.Printer.Config do
  @type t() :: any()

  @spec connect(config :: t()) :: {:ok, config :: t()} | {:error, String.t()}
  def connect(config)

  @spec disconnect(config :: t()) :: :ok
  def disconnect(config)
end
