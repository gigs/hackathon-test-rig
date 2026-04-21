defmodule HackathonTestRig.Geocoding do
  @moduledoc """
  Lookup table mapping known test rig location strings to `{latitude, longitude}`
  tuples. Returns `nil` for unknown locations so callers can filter them out.
  """

  @coordinates %{
    "London, UK" => {51.5074, -0.1278},
    "Dublin, IE" => {53.3498, -6.2603},
    "Berlin, DE" => {52.5200, 13.4050},
    "Stockholm, SE" => {59.3293, 18.0686},
    "New York, US" => {40.7128, -74.0060},
    "San Francisco, US" => {37.7749, -122.4194},
    "Tokyo, JP" => {35.6762, 139.6503},
    "Sydney, AU" => {-33.8688, 151.2093},
    "Singapore, SG" => {1.3521, 103.8198},
    "São Paulo, BR" => {-23.5505, -46.6333},
    "Cape Town, ZA" => {-33.9249, 18.4241},
    "Mumbai, IN" => {19.0760, 72.8777},
    "Toronto, CA" => {43.6532, -79.3832},
    "Paris, FR" => {48.8566, 2.3522},
    "Amsterdam, NL" => {52.3676, 4.9041}
  }

  @spec coordinates(String.t() | nil) :: {float(), float()} | nil
  def coordinates(nil), do: nil
  def coordinates(location), do: Map.get(@coordinates, location)
end
