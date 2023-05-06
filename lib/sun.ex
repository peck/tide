defmodule Tide.Sun do
 @moduledoc """
  A module to calculate sunrise and sunset times for given latitude, longitude, and date.
  """
  import Timex

  def date_to_julian_day_number(date) do
    {year, month, day} = Date.to_erl(date)

    a = div((14 - month), 12)
    y = year + 4800 - a
    m = month + 12 * a - 3

    jdn = day + div((153 * m + 2), 5) + 365 * y + div(y, 4) - div(y, 100) + div(y, 400) - 32045

    jdn + 0.5
  end

  @doc """
  Returns sunrise and sunset times as a tuple for the given latitude, longitude, and date.
  """
  def get_sunrise_sunset(latitude, longitude, date) do
    jd = date_to_julian_day_number(date)

    # Calculate time of solar noon
    n_star = jd - 2451550.1 - longitude / 360
    n = round(n_star)

    # Calculate mean anomaly
    m = rem(trunc(357.5291 + 0.98560028 * n), 360)

    # Calculate true anomaly
    c = 1.9148 * :math.sin(deg2rad(m)) + 0.02 * :math.sin(deg2rad(2 * m))
    v = m + c

    # Calculate ecliptic longitude
    epsilon = 23.439 - 0.0000004 * (n - 1)
    lamda = rem(trunc(v + 102.9372), 360)

    # Calculate solar declination
    delta = :math.asin(:math.sin(deg2rad(epsilon)) * :math.sin(deg2rad(lamda)))

    # Calculate solar noon
    j_transit = 2451550.1 + n + 0.0053 * :math.sin(deg2rad(m)) - 0.0069 * :math.sin(deg2rad(2 * lamda))

    # Calculate solar hour angle
    w_0 = :math.acos((-0.01448524) / (:math.cos(latitude * :math.pi / 180) * :math.cos(delta)))

dbg()
    # Calculate sunrise and sunset times
    j_sunrise = j_transit - w_0 / (2 * :math.pi)
    j_sunset = j_transit + w_0 / (2 * :math.pi)

    {j_sunrise, j_sunset}
  end

  def deg2rad(deg) do
    deg * :math.pi / 180
  end
end
