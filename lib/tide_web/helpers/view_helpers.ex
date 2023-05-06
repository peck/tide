defmodule TideWeb.Helpers.ViewHelpers do
    def decimal_degrees_to_dms(decimal_degrees) do
    degrees = Float.floor(decimal_degrees)
    minutes_decimal = abs(decimal_degrees - degrees) * 60.0
    minutes = Float.floor(minutes_decimal)
    seconds = (minutes_decimal - minutes) * 60.0

    # Format the output as a binary string
    "#{degrees}°#{minutes}'#{Float.round(seconds, 2)}\""
  end
end
