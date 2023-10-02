defmodule TideWeb.StationLive do
  use Phoenix.LiveView
  use TideWeb, :html
  require Logger

  def mount(_params = %{}, _session, socket) do
    peer_data = get_connect_info(socket, :peer_data)

    {:ok, geo_response} =
      peer_data.address
      |> :inet.ntoa()
      |> to_string
      |> GeoIP.lookup()

    [latitude, longitude] =
      case geo_response[:loc] do
        nil ->
          [32.178890, -80.743057]

        _ ->
          geo_response[:loc] |> String.split(",")
      end

    {:ok, stations} = Tide.Station.get_stations_by_distance(latitude, longitude, Application.fetch_env!(:tide, :stations_per_request), 0)

    socket =
      socket
      |> assign(:latitude, latitude)
      |> assign(:longitude, longitude)
      |> assign(:station_offset, Application.fetch_env!(:tide, :stations_per_request))
      |> assign(:stations, stations)

    {:ok, socket, temporary_assigns: [stations: []]}
  end

  def handle_event("load-more", _, socket) do

    {:ok, stations} = Tide.Station.get_stations_by_distance(socket.assigns.latitude, socket.assigns.longitude, Application.fetch_env!(:tide, :stations_per_request), socket.assigns.station_offset)

    socket =
      socket
      |> assign(:station_offset, socket.assigns.station_offset + Application.fetch_env!(:tide, :stations_per_request))
      |> assign(:stations, stations)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-1 lg:px-0 flex justify-center min-h-screen dark:bg-slate-800 dark:text-white bg-white text-slate-900 py-5">
      <div class="max-w-screen-lg w-full lg:w-1/4 text-center">
        <div class="grid grid-cols-2 my-5">
          <div class="text-left">
            <p class="text-base">plaintexttides.com</p>
          </div>
        </div>

        <div class="text-sm font-semibold whitespace-nowrap">Tide Prediction Stations</div>

        <%= for {station, index} <- Stream.with_index(@stations) do %>
          <%= if index != 0 do %>
            <hr class="w-40 mx-auto my-3" />
          <% end %>
          <.link href={~p"/stations/#{station.id}/today"}>
            <div class="grid grid-cols-2">
              <div>
                <p class="text-left text-sm whitespace-pre-line">
                  <%= String.split(station.name)
                  |> Enum.map(&String.capitalize/1)
                  |> Enum.join(" ")
                  |> String.replace(", ", ",\n") %>
                </p>
              </div>
              <div class="text-sm text-right">
                <%= decimal_degrees_to_dms(station.latitude, :latitude) %>
                <br />
                <%= decimal_degrees_to_dms(station.longitude, :longitude) %>
              </div>
            </div>
            <div class="text-sm text-center"><%= meters_to_miles(station.distance) %> miles away</div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
