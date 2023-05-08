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

{:ok, tz_world_pid} = TzWorld.Backend.EtsWithIndexCache.start_link()
Tide.populate_stations
