# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Tide.Repo.insert!(%Tide.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

{:ok, _tz_world_pid} = TzWorld.Backend.EtsWithIndexCache.start_link()
Tide.populate_stations

#for station <- Tide.Repo.all(Tide.Station) do
#    if !File.exists?("priv/predictions/#{station.id}.json") do
#      {:ok, predictions} = Tide.tide_predictions(station.id, ~D[2023-01-01])
#      json_data = Jason.encode_to_iodata!(predictions)
#      File.write!("priv/predictions/#{station.id}.json", json_data)
#    end
#end

#for file_name <- File.ls!("priv/predictions/") do
#    [station_id, _extension] = String.split(file_name, ".")
#
#    changesets = File.read!("priv/predictions/#{file_name}")
#    |> Jason.decode!()
#    |> Enum.map(fn(x) ->
#
#      y = %{
#        "type" => x["type"],
#        "volume" => x["v"],
#        "timestamp" => x["t"],
#        "station_id" => station_id
#      }
#
#      %Tide.Prediction{}
#      |> Tide.Prediction.changeset(y)
#      end)
#
#    Tide.Repo.transaction(fn ->
#      Enum.each(changesets, fn cs -> Tide.Repo.insert(cs) end)
#    end)
#end
