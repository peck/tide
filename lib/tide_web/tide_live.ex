defmodule TideWeb.TideLive do
    use Phoenix.LiveView
    use TideWeb, :html
    def mount(params = %{"station_id" => station_id}, _session, socket) do
      params = set_default_params(params, %{
            "date" => "today"
                                  })
        station = Tide.Repo.get_by(Tide.Station, id: station_id)
        date = case Map.get(params, "date") do
          "today" ->
                   DateTime.now!(station.time_zone_name) |> DateTime.to_date
          isodate ->
                   {:ok, date} = Date.from_iso8601(isodate)
                   date
        end
        {:ok, %{predictions: predictions, station: station, events: events}} = Tide.get_tide_by_station(station, date)

        #warm cache
        Task.start(fn ->
          next_date = Date.add(date, -1)
          Tide.get_tide_by_station(station, next_date)
          prev_date = Date.add(date, +1)
          Tide.get_tide_by_station(station, prev_date)
        end)

        socket =
          socket
          |> assign(:predictions, predictions)
          |> assign(:station, station)
          |> assign(:current_time, date)
          |> assign(:sunrise_time, events[:sunrise])
          |> assign(:sunset_time, events[:sunset])
          |> assign(:moonrise_time, events[:moonrise])
          |> assign(:moonset_time, events[:moonset])
          |> assign(:location, nil)

        {:ok, socket}
    end

  defp set_default_params(params, defaults) do
    Enum.reduce(defaults, params, fn {key, default_value}, acc ->
      Map.put_new(acc, key, default_value)
    end)
  end

    def handle_params(params = %{"station_id" => station_id}, _session, socket) do
      params = set_default_params(params, %{
            "date" => "today"
                                  })

        station = Tide.Repo.get_by(Tide.Station, id: station_id)
        date = case Map.get(params, "date") do
          "today" ->
                   DateTime.now!(station.time_zone_name) |> DateTime.to_date
          isodate ->
                   {:ok, date} = Date.from_iso8601(isodate)
                   date
        end
        {:ok, %{predictions: predictions, station: station, events: events}} = Tide.get_tide_by_station(station, date)

        #warm cache
        Task.start(fn ->
          next_date = Date.add(date, -1)
          Tide.get_tide_by_station(station, next_date)
          prev_date = Date.add(date, +1)
          Tide.get_tide_by_station(station, prev_date)
        end)

        socket =
          socket
          |> assign(:predictions, predictions)
          |> assign(:station, station)
          |> assign(:current_time, date)
          |> assign(:sunrise_time, events[:sunrise])
          |> assign(:sunset_time, events[:sunset])
          |> assign(:moonrise_time, events[:moonrise])
          |> assign(:moonset_time, events[:moonset])
          |> assign(:moonphase, events[:moonphase])
          |> assign(:location, nil)

        {:noreply, socket}
    end

    def render(assigns) do
        ~H"""
        <div class="container mx-auto px-1 lg:px-0 flex justify-center min-h-screen dark:bg-slate-800 dark:text-white bg-white text-slate-900 py-5">
        <div class="max-w-screen-lg w-full lg:w-1/4 text-center flex flex-col">
        <div class="flex-grow">
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
        <div class="text-sm whitespace-nowrap">&lt; <%= Date.add(@current_time, -1) |> Calendar.strftime("%B %-d")%></div>
        </.link>
        </div>

        <div class="col-span-2">
        <div class="text-sm font-semibold whitespace-nowrap"><%= Calendar.strftime(@current_time, "%A, %B %-d")%></div>
        </div>
        <div class="col-span-1">

        <.link phx-click="inc_date">
        <div class="text-sm whitespace-nowrap"><%= Date.add(@current_time, +1) |> Calendar.strftime("%B %-d")%> &gt;</div>
        </.link>
        </div>
        </div>

        <%= for {prediction, index} <- Stream.with_index(@predictions) do %>
        <%= if index != 0 do %>
        <span class="text-xs">then</span>
        <% end %>
        <p class="text-lg"><%= if Map.get(prediction, "type") == "H", do: "↑", else: "↓" %> <%= Calendar.strftime(prediction["t"], "%-I:%M%P") |> String.trim_trailing("m") %> </p>
        <% end %>
        <hr class="my-5"/>
        <div class="grid grid-cols-2 gap-4">
        <div>
        <div class="whitespace-nowrap">
        Sunrise: <%= Calendar.strftime(@sunrise_time, "%-I:%M%P") |> String.trim_trailing("m") %>
        </div>
        <div class="whitespace-nowrap">
        Sunset: <%= Calendar.strftime(@sunset_time, "%-I:%M%P") |> String.trim_trailing("m") %>
        </div>
        </div>
        <div>
        <%= if @moonset_time != nil do %>
        <div class="whitespace-nowrap">
        Moonset: <%= Calendar.strftime(@moonset_time, "%-I:%M%P") |> String.trim_trailing("m") %>
        </div>
        <% end %>

        <%= if @moonrise_time != nil do %>
        <div class="whitespace-nowrap">
        Moonrise: <%= Calendar.strftime(@moonrise_time, "%-I:%M%P") |> String.trim_trailing("m") %>
        </div>
        <% end %>

        </div>
        </div>

        <hr class="my-5"/>
        <p class="text-sm">
        <%= String.split(@station.name) |> Enum.map(&String.capitalize/1) |> Enum.join(" ") %>
        </p>
        <p class="text-sm">
        <%= decimal_degrees_to_dms(@station.latitude, :latitude) %>, <%= decimal_degrees_to_dms(@station.longitude, :longitude) %>
        </p>

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

    def handle_event("location", _params = %{"latitude" => latitude, "longitude" => longitude}, socket) do
        {:ok, station} = Tide.get_nearest_station(latitude, longitude)

        socket =
          socket
          |> push_patch(to: ~p"/#{station.id}/#{Date.to_iso8601(socket.assigns.current_time)}")

        {:noreply, socket}
    end

    def handle_event("dec_date", _params , socket) do
        new_date = socket.assigns.current_time |> Date.add(-1)

        socket =
          socket
          |> assign(:current_time, new_date)
          |> push_patch(to: ~p"/#{socket.assigns.station.id}/#{Date.to_iso8601(new_date)}")

        {:noreply, socket}
    end

    def handle_event("inc_date", _params , socket) do
        new_date = socket.assigns.current_time |> Date.add(+1)

        socket =
          socket
          |> assign(:current_time, new_date)
          |> push_patch(to: ~p"/#{socket.assigns.station.id}/#{Date.to_iso8601(new_date)}")

        {:noreply, socket}
    end
end