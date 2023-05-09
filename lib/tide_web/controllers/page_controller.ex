defmodule TideWeb.PageController do
  use TideWeb, :controller
  require Logger

  def home(conn, _params) do
    {:ok, geo_response} =
      conn.remote_ip
      |> :inet.ntoa
      |> to_string
      |> GeoIP.lookup()

    Logger.info(IO.inspect(geo_response, label: "GEO_RESPONSE"))

    [latitude, longitude] = geo_response[:loc] |> String.split(",")

    {:ok, station} = Tide.get_nearest_station(latitude, longitude)

    redirect(conn, to: ~p"/#{station.id}")
  end

  def stations(conn, _params = %{}) do
    {:ok, geo_response} =
      conn.remote_ip
      |> :inet.ntoa
      |> to_string
      |> GeoIP.lookup()

    [latitude, longitude] = geo_response[:loc] |> String.split(",")

    stations = Tide.Station.get_stations(%{latitude: latitude, longitude: longitude})

    conn
    |> assign(:stations, stations)
    |> render(:stations, layout: false)
  end

  defp set_default_params(params, defaults) do
    Enum.reduce(defaults, params, fn {key, default_value}, acc ->
      Map.put_new(acc, key, default_value)
    end)
  end

    defp ip_to_string(ip_tuple) when is_tuple(ip_tuple) do
    case tuple_size(ip_tuple) do
      4 ->
        # IPv4
        :inet.ntoa(ip_tuple) |> to_string()

      8 ->
        # IPv6
        :inet.ntop(:inet6, ip_tuple) |> to_string()

      _ ->
        raise ArgumentError, message: "Invalid IP tuple"
    end
  end
end
