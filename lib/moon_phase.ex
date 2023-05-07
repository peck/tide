defmodule MoonPhase do
  @phase_map %{
    "New Moon" => "🌑",
    "Waxing Crescent" => "🌒",
    "First Quarter" => "🌓",
    "Waxing Gibbous" => "🌔",
    "Full Moon" => "🌕",
    "Waning Gibbous" => "🌖",
    "Last Quarter" => "🌗",
    "Waning Crescent" => "🌘"
  }

  def get_phase_emoji(phase_name) do
    Map.get(@phase_map, phase_name, "Unknown")
  end
end
