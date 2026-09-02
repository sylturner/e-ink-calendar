require "json"
require "net/http"
require "uri"

module Eink
  class WeatherClient
    class ConfigurationError < StandardError; end

    def forecast(latitude:, longitude:)
      raise ConfigurationError, "Set WEATHER_LATITUDE and WEATHER_LONGITUDE in .env" if latitude.blank? || longitude.blank?

      query = URI.encode_www_form(
        latitude: latitude,
        longitude: longitude,
        current: "temperature_2m,weather_code",
        daily: "temperature_2m_max,temperature_2m_min",
        timezone: 'US/Eastern',
        temperature_unit: 'fahrenheit',
        forecast_days: 1
      )
      uri = URI("https://api.open-meteo.com/v1/forecast?#{query}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.get(uri) }
      payload = JSON.parse(response.body)
      raise "Weather request failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

      {
        temperature: payload.dig("current", "temperature_2m"),
        high: payload.dig("daily", "temperature_2m_max", 0),
        low: payload.dig("daily", "temperature_2m_min", 0),
        condition: condition_for(payload.dig("current", "weather_code")),
        unit: payload.dig("current_units", "temperature_2m") || "°"
      }
    end

    private

    def condition_for(code)
      {
        0 => "Clear", 1 => "Mostly clear", 2 => "Partly cloudy", 3 => "Overcast",
        45 => "Fog", 48 => "Fog", 51 => "Drizzle", 53 => "Drizzle", 55 => "Drizzle",
        61 => "Rain", 63 => "Rain", 65 => "Heavy rain", 71 => "Snow", 73 => "Snow",
        75 => "Heavy snow", 80 => "Showers", 81 => "Showers", 82 => "Heavy showers",
        95 => "Thunderstorm"
      }.fetch(code, "Weather")
    end
  end
end
