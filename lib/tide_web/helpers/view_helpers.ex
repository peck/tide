defmodule TideWeb.Helpers.ViewHelpers do
    @miles_per_meter 0.000621371

  def meters_to_miles(meters) do
    # Convert meters to miles
    miles = @miles_per_meter * meters

    # Truncate to 1 decimal place
    truncated_miles = Float.round(miles, 1)

    truncated_miles
  end

  def decimal_degrees_to_dms(decimal_degrees, latitude_or_longitude) do
    degrees = Float.floor(decimal_degrees) |> trunc
    minutes_decimal = abs(decimal_degrees - degrees) * 60.0
    minutes = Float.floor(minutes_decimal) |> trunc
    seconds = (minutes_decimal - minutes) * 60.0

    suffix =
      case latitude_or_longitude do
        :latitude ->
          if degrees > 0, do: "N", else: "S"

        :longitude ->
          if degrees > 0, do: "E", else: "W"
      end

    # Format the output as a binary string
    "#{abs(degrees)}° #{minutes}' #{Float.round(seconds, 2)}\" #{suffix}"
  end
end
