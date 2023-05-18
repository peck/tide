defmodule Tide.Repo.Migrations.AddPredictionsTable do
  use Ecto.Migration

  def change do
    create table(:predictions) do
      add :station_id, :string, null: false
      add :timestamp, :utc_datetime, null: false
      add :type, :string, null: false
      add :volume, :decimal, null: false
    end

    create index(:predictions, :station_id)
    create index(:predictions, :timestamp)
  end
end
