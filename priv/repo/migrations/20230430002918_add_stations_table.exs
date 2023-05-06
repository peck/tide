defmodule Tide.Repo.Migrations.AddStationsTable do
  use Ecto.Migration
  def change do
    create table(:stations, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :latitude, :float
      add :longitude, :float
      add :time_zone_correction, :integer
      add :time_zone_name, :string
      add :slug, :string
    end

    index(:stations, :id)
  end
end
