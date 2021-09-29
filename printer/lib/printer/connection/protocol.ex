defprotocol Printer.Connection.Protocol do
  @spec open(connection :: t()) :: {:ok, connection :: t()} | {:error, String.t()}
  def open(connection)

  @spec close(connection :: t()) :: :ok | {:error, String.t()}
  def close(connection)

  @spec send(connection :: t(), message :: String.t()) :: :ok | {:error, String.t()}
  def send(connection, message)

  @spec handle_message(connection :: t(), message :: any()) ::
          {:ok, connection :: t()}
          | {:ok, connection :: t(), response :: any()}
          | {:closed, reason :: String.t()}
          | {:error, error :: String.t(), connection :: t()}
  def handle_message(connection, response)
end

defimpl Printer.Connection.Protocol, for: Any do
  def open(_connection), do: {:error, "Not a connection."}
  def close(_connection), do: {:error, "Not a connection."}
  def send(_connection, _message), do: {:error, "Not a connection."}
  def handle_message(connection, _message), do: {:error, "Not a connection.", connection}
end
