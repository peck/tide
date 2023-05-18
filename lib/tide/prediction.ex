defmodule Tide.Prediction do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :string, autogenerate: false}


  schema "predictions" do
    belongs_to :station, Tide.Station, type: :string
    field :timestamp, :utc_datetime
    field :volume, :float
    field :type, :string
  end

  def changeset(prediction, attrs) do
    prediction
    |> cast(attrs, [:timestamp, :volume, :type, :station_id])
    |> validate_required([:timestamp, :volume, :type, :station_id])
    |> validate_inclusion(:type, ["H", "L"])
    |> assoc_constraint(:station)
  end

  def get_predictions(station = %Tide.Station{}, date = %Date{}) do
    {:ok, offset} = offset_for_date(date, station.time_zone_name)
    sql = """
    SELECT *
    FROM (
    -- All predictions for the desired day
    SELECT 
    p.type,
    p.volume,
    p.station_id,
    p.timestamp
    FROM 
    predictions p
    JOIN 
    stations s ON p.station_id = s.id
    WHERE 
    DATE(DATETIME(p.timestamp, '#{offset} hour')) = $1
    AND s.id = $2

    UNION ALL

    -- Last prediction from the previous day
    SELECT 
    p.type,
    p.volume,
    p.station_id,
    p.timestamp
    FROM 
    (
    SELECT 
    p.type,
    p.volume,
    p.station_id,
    p.timestamp
    FROM 
    predictions p
    JOIN 
    stations s ON p.station_id = s.id
    WHERE 
    DATE(DATETIME(p.timestamp, '#{offset} hours')) = DATE($1, '-1 day')
    AND s.id = $2
    ORDER BY 
    p.timestamp DESC
    LIMIT 1
    ) p

    UNION ALL

    -- First prediction from the next day
    SELECT 
    p.type,
    p.volume,
    p.station_id,
    p.timestamp
    FROM 
    (
    SELECT 
    p.type,
    p.volume,
    p.station_id,
    p.timestamp
    FROM 
    predictions p
    JOIN 
    stations s ON p.station_id = s.id
    WHERE 
    DATE(DATETIME(p.timestamp, '#{offset} hours')) = DATE($1, '+1 day')
    AND s.id = $2
    ORDER BY 
    p.timestamp ASC
    LIMIT 1
    ) p
    ) t
    ORDER BY t.timestamp;
    """

    {:ok, result} =Tide.Repo.query(sql, [date, station.id])
    Enum.map(result.rows, &Tide.Repo.load(Tide.Prediction, {result.columns, &1}))
  end

  def offset_for_date(date, timezone) do
    {:ok, naive_datetime} = NaiveDateTime.new(date, ~T[00:00:00])
    DateTime.from_naive(naive_datetime, timezone)
    |> case do
         {:ok, datetime} -> {:ok, (datetime.utc_offset + datetime.std_offset)/3600}
         {:error, _} -> {:error, "Invalid timezone or date"}
       end
  end
end
