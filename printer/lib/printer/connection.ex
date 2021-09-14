defprotocol Printer.Connection do
  @type t() :: any()

  @spec connect(connection :: t()) :: {:ok, connection :: t()} | {:error, String.t()}
  def connect(connection)

  @spec disconnect(connection :: t()) :: :ok
  def disconnect(connection)

  @spec send(connection :: t(), command :: String.t()) :: :ok | {:error, String.t()}
  def send(connection, command)

  @spec update(connection :: t(), message :: any()) ::
          {:ok, connection :: t()} | {:error, String.t()}
  def update(connection, message)
end

defimpl Printer.Connection, for: Any do
  def connect(_connection), do: {:error, "Not a connection."}
  def disconnect(_connection), do: :ok
  def send(_connection, _message), do: {:error, "Not a connection."}
  def update(_connection, _message), do: {:error, "Not a connection."}
end