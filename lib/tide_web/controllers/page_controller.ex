defmodule TideWeb.PageController do
  use TideWeb, :controller
  require Logger

  def home(conn, _params) do
    {:ok, geo_response} =
      conn.remote_ip
      |> :inet.ntoa
      |> to_string
      |> GeoIP.lookup()

    [latitude, longitude] = case geo_response[:loc] do
                              nil ->
                                [39.8282, -98.5795]
                              _ ->
                                geo_response[:loc] |> String.split(",")
                            end

    {:ok, station} = Tide.get_nearest_station(latitude, longitude)

    redirect(conn, to: ~p"/#{station.id}")
  end

  def stations(conn, _params = %{}) do
    {:ok, geo_response} =
      conn.remote_ip
      |> :inet.ntoa
      |> to_string
      |> GeoIP.lookup()

    [latitude, longitude] = case geo_response[:loc] do
                              nil ->
                                [39.8282, -98.5795]
                              _ ->
                                geo_response[:loc] |> String.split(",")
                            end

    {:ok, stations} = Tide.Station.get_stations_by_distance(latitude, longitude)

    conn
    |> assign(:stations, stations)
    |> render(:stations, layout: false)
  end

  defp set_default_params(params, defaults) do
    Enum.reduce(defaults, params, fn {key, default_value}, acc ->
      Map.put_new(acc, key, default_value)
    end)
  end

end
