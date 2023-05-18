defmodule Tide.Repo.Migrations.AddStationsTable do
  use Ecto.Migration

  def change do
    create table(:stations, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :name, :string, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :time_zone_correction, :integer, null: false
      add :time_zone_name, :string, null: false
    end

    create index(:stations, :id)
  end
end
