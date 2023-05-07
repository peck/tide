defmodule TideWeb.Helpers.ViewHelpers do
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
