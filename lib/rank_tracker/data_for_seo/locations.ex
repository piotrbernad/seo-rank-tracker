defmodule RankTracker.DataForSeo.Locations do
  @locations %{
    2616 => %{name: "Poland", language: "pl", country_iso: "PL"},
    2826 => %{name: "United Kingdom", language: "en", country_iso: "GB"},
    2276 => %{name: "Germany", language: "de", country_iso: "DE"},
    2250 => %{name: "France", language: "fr", country_iso: "FR"},
    2724 => %{name: "Spain", language: "es", country_iso: "ES"},
    2380 => %{name: "Italy", language: "it", country_iso: "IT"},
    2528 => %{name: "Netherlands", language: "nl", country_iso: "NL"},
    2056 => %{name: "Belgium", language: "nl", country_iso: "BE"},
    2040 => %{name: "Austria", language: "de", country_iso: "AT"},
    2756 => %{name: "Switzerland", language: "de", country_iso: "CH"},
    2620 => %{name: "Portugal", language: "pt", country_iso: "PT"},
    2752 => %{name: "Sweden", language: "sv", country_iso: "SE"},
    2578 => %{name: "Norway", language: "no", country_iso: "NO"},
    2208 => %{name: "Denmark", language: "da", country_iso: "DK"},
    2246 => %{name: "Finland", language: "fi", country_iso: "FI"},
    2372 => %{name: "Ireland", language: "en", country_iso: "IE"},
    2203 => %{name: "Czech Republic", language: "cs", country_iso: "CZ"},
    2642 => %{name: "Romania", language: "ro", country_iso: "RO"},
    2348 => %{name: "Hungary", language: "hu", country_iso: "HU"},
    2300 => %{name: "Greece", language: "el", country_iso: "GR"},
    2840 => %{name: "United States", language: "en", country_iso: "US"},
    2124 => %{name: "Canada", language: "en", country_iso: "CA"},
    2484 => %{name: "Mexico", language: "es", country_iso: "MX"},
    2076 => %{name: "Brazil", language: "pt", country_iso: "BR"},
    2032 => %{name: "Argentina", language: "es", country_iso: "AR"},
    2152 => %{name: "Chile", language: "es", country_iso: "CL"},
    2170 => %{name: "Colombia", language: "es", country_iso: "CO"},
    2036 => %{name: "Australia", language: "en", country_iso: "AU"},
    2554 => %{name: "New Zealand", language: "en", country_iso: "NZ"},
    2392 => %{name: "Japan", language: "ja", country_iso: "JP"},
    2410 => %{name: "South Korea", language: "ko", country_iso: "KR"},
    2702 => %{name: "Singapore", language: "en", country_iso: "SG"},
    2344 => %{name: "Hong Kong", language: "zh", country_iso: "HK"},
    2356 => %{name: "India", language: "en", country_iso: "IN"},
    2764 => %{name: "Thailand", language: "th", country_iso: "TH"},
    2458 => %{name: "Malaysia", language: "en", country_iso: "MY"},
    2608 => %{name: "Philippines", language: "en", country_iso: "PH"},
    2360 => %{name: "Indonesia", language: "id", country_iso: "ID"},
    2704 => %{name: "Vietnam", language: "vi", country_iso: "VN"},
    2784 => %{name: "United Arab Emirates", language: "ar", country_iso: "AE"},
    2682 => %{name: "Saudi Arabia", language: "ar", country_iso: "SA"},
    2376 => %{name: "Israel", language: "he", country_iso: "IL"},
    2792 => %{name: "Turkey", language: "tr", country_iso: "TR"},
    2710 => %{name: "South Africa", language: "en", country_iso: "ZA"}
  }

  def all, do: @locations

  def for_select do
    @locations
    |> Enum.map(fn {code, %{name: name}} -> {name, code} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  def valid_location_code?(code) when is_integer(code), do: Map.has_key?(@locations, code)
  def valid_location_code?(_), do: false

  def get_language_code(location_code) when is_integer(location_code) do
    case Map.get(@locations, location_code) do
      %{language: language} -> language
      nil -> "en"
    end
  end

  def get_language_code(_), do: "en"

  def get_country_name(location_code) when is_integer(location_code) do
    case Map.get(@locations, location_code) do
      %{name: name} -> name
      nil -> "Unknown"
    end
  end

  def get_country_name(_), do: "Unknown"

  def get_country_iso(location_code) when is_integer(location_code) do
    case Map.get(@locations, location_code) do
      %{country_iso: iso} -> iso
      nil -> nil
    end
  end

  def get_country_iso(_), do: nil

  def resolve_country(name_or_code) when is_binary(name_or_code) do
    case Integer.parse(name_or_code) do
      {code, ""} ->
        if valid_location_code?(code), do: {:ok, code}, else: {:error, :invalid_country}

      _ ->
        downcased = String.downcase(name_or_code)

        result =
          Enum.find(@locations, fn {_code, %{name: name}} ->
            String.downcase(name) == downcased
          end)

        case result do
          {code, _} -> {:ok, code}
          nil -> {:error, :invalid_country}
        end
    end
  end

  def resolve_country(code) when is_integer(code) do
    if valid_location_code?(code), do: {:ok, code}, else: {:error, :invalid_country}
  end

  def resolve_country(_), do: {:error, :invalid_country}
end
