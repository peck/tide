defmodule TideWeb.TideLive do
  use Phoenix.LiveView
  use TideWeb, :html

  @placeholder_time "00:00a"

  def mount(params = %{"station_id" => station_id}, _session, socket) do
    params =
      set_default_params(params, %{
        "date" => "today"
      })

    station = Tide.Repo.get_by(Tide.Station, id: station_id)

    date =
      case Map.get(params, "date") do
        "today" ->
          DateTime.now!(station.time_zone_name) |> DateTime.to_date()

        isodate ->
          {:ok, date} = Date.from_iso8601(isodate)
          date
      end

    # {:ok, %{predictions: predictions, station: station, events: events}} =

    Task.async(fn -> Tide.get_tide_by_station(station, date) end)

    # warm cache, should just be astronomy but its fine for now until I break that out
    #Task.start(fn ->
    #  next_date = Date.add(date, -1)
    #  Tide.get_tide_by_station(station, next_date)
    #  prev_date = Date.add(date, +1)
    #  Tide.get_tide_by_station(station, prev_date)
    #end)
    #
    # {todays_predictions, _not_todays_predictions} = Enum.split_with(predictions, fn(prediction) -> DateTime.to_date(prediction.timestamp) == date end)

    # {[yesterday_prediction | todays_predictions], tomorrow_prediction} = Enum.sort(predictions, &(DateTime.compare(&1.timestamp, &2.timestamp) != :gt)) |> Enum.split(-1);

    socket =
      socket
      |> assign(:predictions, [])
      |> assign(:station, station)
      |> assign(:current_time, date)
      |> assign(:sunrise_time_str, @placeholder_time)
      |> assign(:sunset_time_str, @placeholder_time)
      |> assign(:moonrise_time_str, @placeholder_time)
      |> assign(:moonset_time_str, @placeholder_time)
      |> assign(:page_title, station.name)
      |> assign(:location, nil)

    {:ok, socket}
  end

  defp set_default_params(params, defaults) do
    Enum.reduce(defaults, params, fn {key, default_value}, acc ->
      Map.put_new(acc, key, default_value)
    end)
  end

  def handle_params(params = %{"station_id" => station_id}, _session, socket) do
    params =
      set_default_params(params, %{
        "date" => "today"
      })

    station = Tide.Repo.get_by(Tide.Station, id: station_id)

    date =
      case Map.get(params, "date") do
        "today" ->
          DateTime.now!(station.time_zone_name) |> DateTime.to_date()

        isodate ->
          {:ok, date} = Date.from_iso8601(isodate)
          date
      end

    # {:ok, %{predictions: predictions, station: station, events: events}} =
    #  Tide.get_tide_by_station(station, date)

    # warm cache
    #Task.start(fn ->
    #  next_date = Date.add(date, -1)
    #  Tide.get_tide_by_station(station, next_date)
    #  prev_date = Date.add(date, +1)
    #  Tide.get_tide_by_station(station, prev_date)
    #end)

    # {todays_predictions, _not_todays_predictions} = Enum.split_with(predictions, fn(prediction) -> DateTime.to_date(prediction.timestamp) == date end)

    # {[yesterday_prediction | todays_predictions], tomorrow_prediction} = Enum.sort(predictions, &(DateTime.compare(&1.timestamp, &2.timestamp) != :gt)) |> Enum.split(-1);
    #
    #Calendar.strftime(@sunrise_time, "%-I:%M%P") |> String.trim_trailing("m")
    Task.async(fn -> Tide.get_tide_by_station(station, date) end)

    socket =
      socket
      |> assign(:predictions, [])
      |> assign(:station, station)
      |> assign(:current_time, date)
      |> assign(:sunrise_time_str, @placeholder_time)
      |> assign(:sunset_time_str, @placeholder_time)
      |> assign(:moonrise_time_str, @placeholder_time)
      |> assign(:moonset_time_str, @placeholder_time)
      |> assign(:page_title, station.name)
      |> assign(:location, nil)

    {:noreply, socket}
  end

  def not_render(assigns) do
    ~H"""
    <div class="container mx-auto px-1 lg:px-0 flex justify-center min-h-screen dark:bg-slate-900 dark:text-white bg-white text-slate-900 py-5">
      <div class="max-w-screen-lg w-full lg:w-1/4 text-center flex flex-col">
        <div class="grow">
          <div class="grid grid-cols-2 my-5">
            <div class="text-left">
              <p class="text-base">plaintexttides.com</p>
            </div>
            <div class="text-right">
              <.link>
                <%= if !@location do %>
                  <button id="user-location" phx-hook="GeolocationHook">Locate Me</button>
                <% end %>
              </.link>
            </div>
          </div>
          <div class="grid grid-cols-4 my-5">
            <div class="col-span-1">
              <.link phx-click="dec_date">
                <div class="text-sm whitespace-nowrap">
                  &lt; <%= Date.add(@current_time, -1) |> Calendar.strftime("%B %-d") %>
                </div>
              </.link>
            </div>

            <div class="col-span-2">
              <div class="text-sm font-semibold whitespace-nowrap">
                <%= Calendar.strftime(@current_time, "%A, %B %-d") %>
              </div>
            </div>
            <div class="col-span-1">
              <.link phx-click="inc_date">
                <div class="text-sm whitespace-nowrap">
                  <%= Date.add(@current_time, +1) |> Calendar.strftime("%B %-d") %> &gt;
                </div>
              </.link>
            </div>
          </div>

          <div class="grid grid-cols-2">
            <div>
              <p class="text-left text-sm whitespace-pre-line"><%= String.split(@station.name) |> Enum.map(&String.capitalize/1) |> Enum.join(" ") |> String.replace(", ", ",\n") %></p>
            </div>
            <div class="text-sm text-right">
              <%= decimal_degrees_to_dms(@station.latitude, :latitude) %>
              <br />
              <%= decimal_degrees_to_dms(@station.longitude, :longitude) %>
            </div>
          </div>
          <hr class="w-40 mx-auto my-3" />

          <%= for {prediction, index} <- Stream.with_index(@predictions) do %>
            <%= if index != 0 do %>
              <span class="text-xs">then</span>
            <% end %>
            <p class="text-lg">
              <%= if Map.get(prediction, :type) == "H", do: "↑", else: "↓" %> <%= Calendar.strftime(
                prediction.timestamp,
                "%-I:%M%P"
              )
              |> String.trim_trailing("m") %>
            </p>
          <% end %>
          <hr class="w-40 mx-auto my-3" />
          <div class="grid grid-cols-2 gap-4">
            <div>
              <div class="whitespace-nowrap">
                Sunrise: <%= @sunrise_time_str %>
              </div>
              <div class="whitespace-nowrap">
                Sunset: <%= @sunset_time_str %>
              </div>
            </div>
            <div>
              <%= if @moonset_time_str != nil do %>
                <div class="whitespace-nowrap">
                  Moonset: <%= @moonset_time_str %>
                </div>
              <% end %>

              <%= if @moonrise_time_str != nil do %>
                <div class="whitespace-nowrap">
                  Moonrise: <%= @moonrise_time_str %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        <div class="footer">
          <p class="text-sm">
            <.link href={~p"/stations"}>
              Tide Stations
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event(
        "location",
        _params = %{"latitude" => latitude, "longitude" => longitude},
        socket
      ) do
    {:ok, station} = Tide.get_nearest_station(latitude, longitude)

    socket =
      socket
      |> push_patch(to: ~p"/stations/#{station.id}")

    {:noreply, socket}
  end

  def handle_event("dec_date", _params, socket) do
    new_date = socket.assigns.current_time |> Date.add(-1)

    socket =
      socket
      |> assign(:current_time, new_date)
      |> push_patch(to: ~p"/stations/#{socket.assigns.station.id}/#{Date.to_iso8601(new_date)}")

    {:noreply, socket}
  end

  def handle_event("inc_date", _params, socket) do
    new_date = socket.assigns.current_time |> Date.add(+1)

    socket =
      socket
      |> assign(:current_time, new_date)
      |> push_patch(to: ~p"/stations/#{socket.assigns.station.id}/#{Date.to_iso8601(new_date)}")

    {:noreply, socket}
  end

def handle_info({ref, {:ok, %{predictions: predictions, station: _station, events: events}}}, socket) do
  Process.demonitor(ref, [:flush])
  {todays_predictions, _not_todays_predictions} = Enum.split_with(predictions, fn(prediction) -> DateTime.to_date(prediction.timestamp) == socket.assigns.current_time end)

    socket =
      socket
      |> assign(:predictions, todays_predictions)
      |> assign(:sunrise_time_str, events[:sunrise] |> Calendar.strftime("%-I:%M%P") |> String.trim_trailing("m"))
      |> assign(:sunset_time_str, events[:sunset] |> Calendar.strftime("%-I:%M%P") |> String.trim_trailing("m"))

    socket = if events[:moonrise] do
      assign(socket, :moonrise_time_str, events[:moonrise] |> Calendar.strftime("%-I:%M%P") |> String.trim_trailing("m"))
    else
      socket
    end

    socket = if events[:moonset] do
      assign(socket, :moonset_time_str, events[:moonset] |> Calendar.strftime("%-I:%M%P") |> String.trim_trailing("m"))
    else
      socket
    end


  {:noreply, socket}
end

end
