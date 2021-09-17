defprotocol Printer.Connection.Protocol do
  @type t() :: any()

  @spec open(connection :: t()) :: {:ok, connection :: t()} | {:error, String.t()}
  def open(connection)

  @spec close(connection :: t()) :: :ok | {:error, String.t()}
  def close(connection)

  @spec send(connection :: t(), message :: String.t()) :: :ok | {:error, String.t()}
  def send(connection, message)

  @spec handle_response(connection :: t(), response :: any()) ::
          :ok
          | {:ok, result :: any()}
          | :closed
          | {:error, String.t()}
  def handle_response(connection, response)
end

defimpl Printer.Connection.Protocol, for: Any do
  def open(_connection), do: {:error, "Not a connection."}
  def close(_connection), do: {:error, "Not a connection."}
  def send(_connection, _message), do: {:error, "Not a connection."}
  def handle_response(_connection, _response), do: {:error, "Not a connection."}
end
