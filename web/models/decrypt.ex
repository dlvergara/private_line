defmodule PrivateLine.Decrypt do
  @private_key "-----BEGIN RSA PRIVATE KEY-----\nMIIEogIBAAKCAQEArhPHlBcTCeVckL4cn/khF6o/Rpik1oA68L2j1zFhxTlkMa0P\nr/zl0+V5CqreuJ6RHd4d6kZGUv9pCt4Wz5ZKhIIpRjwPM5Sap3eTOMUoOWeZYF5q\ngZQ/hTkskVoFIv4AAl4Bx1DkdfUY7zcB3Tjt1cXzJMdom6AxP/i/t6/wbk2/tQ1i\nFqLbbpEI+E4d+jxKrvWBg5dAtEmco6IlLUDocAs95A6hEaFGb8X8XV9a6yPlqQnQ\n/x312oYw7PCiMm+4TjTIogYXJMAhUwUNOjks3X4aw6EoyxzKCyi/TRK52Iugq++4\nrneUOpFtSPs0YeJvY8sda6RGxsmzcytBvc8o6wIDAQABAoIBACvJc+lPSI2zsO4D\ntCWVP/q460Oxv7zo8mp9+Ul29XXrssVAF/MXtSPw09qYEn/z+uK9bV7xoFzePCjs\npmY/Eq10JDezgctitOgtDs434Z9W7OCtvzKq/LNhJ1HEiAg+RfhSdzYQpfb52PTL\nLF/eIw0jxr5YnnqO9/R0eJ0W126XG6RNbE6YfA0azfuKC35PQKlI8X8OehkmAasA\nTPvhrRPFM/pD3OS0PLxKvS8aXNLV/SNI6kqg9dB1SVMbJfSQ72fqH6CLKZoM23Ip\nhparhYd+IF7qJcYbygfG0sNgG+ou9gNc7rmcWpCVC3lv5nL5NhxdQlW+DsTuUy7+\n0lkeWYkCgYEA303qKjxVIWynn2oy+avcSY29h1/fBngqUUpKzNw+RVlNKYk2VD1O\nfINSDybLZIFQCxMxxa97+a+juwKvV9I8G80Fs5Z3oReXcZs0mCZ/J3dDEexOMjT3\n8ZdiIm4bv19ryLiUve0AROmDOcztDN+2Oy6pAMAPY/9m7KIWfAVo8X0CgYEAx5Cx\nYREv8mqI4YtfWIqGGSExmRTjvPNVvighIe4cExwsY0hqBjl6oUp1rI1A/aWeP0nT\ny7XTs+80PblcjxjklVUah1COaYwKnTD5XYQgM1moQQZ+czR0wclIQh1k97xGXl3v\nAM2/nIN8LbNBit3g1s47Bo55QFfGiO1389PgEIcCgYAWvKc4L7Z3VcnniHeyRlaC\nwsTmkNNzpC6i4k6ld1N72jDqJsd6Yleog/KKCmgxTp1o00aBG3IjJUgllYtnBMgM\nCJ8o/wwlQfKwpZ4AVAMkcJdKruXzZMNOPRzH5rA6lyuxX2H9yLD7U0+CRiRo6Cp0\n8jZRFj068Fl5hLOHY0GhPQKBgA53l9RQmag6PugS4XuatzP1KxJM6GGXRlz9rcE2\n8MQV48XixwTif9hXfIZgyxhYPEucP4ViDhHaQnBDEsmw5UlKHR04IsrWAyL4HOvB\nm0/9rOvh26LgZ6JwxBM+7EXlWTiYGK53O+/NvF/XweWeRiFsW+0SwQmAE31zsaF0\nd6bbAoGAeODAQgwxJ/btRj5Pmo9dn6ounjntSTD/+jw84BHXv5EkgMyi7ePZwiCw\n9FxuZOXEMDYPsikNqP7qX4C7lPg8NOMX5egFQxV10zdPDSSqnLu8oWkqvMzK2oKb\nc3d8nDLAqEGaq0+oSBESDMZGoOiUS09Q8yEz2SI6t/uN9nP9Y9M=\n-----END RSA PRIVATE KEY-----\n"

  def decrypt_and_merge(%{"stone" => stone} = params) when is_list(stone) do
    stone
    |> decrypt_stone_pieces
    |> concat_stone_pieces
    |> Poison.decode
    |> merge_stone_with_destination_format(params)
  end

  def decrypt_and_merge(%{"stone" => stone} = params) do
    stone
    |> decrypt_stone
    |> Poison.decode
    |> merge_stone_with_destination_format(params)
  end

  # private

  defp decrypt_stone_pieces(stone_list) when is_list(stone_list) do
    stone_list
    |> Enum.map(fn(stone_piece) -> Task.async(__MODULE__, :decrypt_stone, [stone_piece]) end)
    |> Enum.map(fn(stone_piece) -> Task.await(stone_piece) end)
  end

  defp concat_stone_pieces(stone_list) do
    stone_list
    |> Enum.join(" ")
  end

  def decrypt_stone(stone) do
    {:ok, decrypted_stone} = RsaEx.decrypt(stone, @private_key)
    decrypted_stone
  end

  defp merge_stone_with_destination_format({:error, _}, _) do
    :bad_stone
  end

  defp merge_stone_with_destination_format({:ok, decrypted_stone}, %{"destination_format" => destination_format, "destination_variables" => destination_variables}) do
    {error?, destination_response} = Enum.reduce(destination_variables, {false, destination_format}, fn(var, {error?, destination_format}) ->
      case Map.fetch(decrypted_stone, var) do
        {:ok, res} ->
          {error?, String.replace(destination_format, "{{{#{var}}}}", res)}
        :error ->
          {true, destination_format}
      end
    end)
    case error? do
      true -> :error
      false -> {:ok, destination_response}
    end
  end
end
