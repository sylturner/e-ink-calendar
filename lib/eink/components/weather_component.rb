module Eink
  module Components
    class WeatherComponent < Component
      key "weather"
      label "Weather"
      minimum_size width: 2, height: 2
      refresh_every 30.minutes

      def panel
        forecast = WeatherClient.new.forecast(
          latitude: setting(:latitude, ENV["WEATHER_LATITUDE"]),
          longitude: setting(:longitude, ENV["WEATHER_LONGITUDE"])
        )
        unit = forecast.fetch(:unit)
        location = setting(:location, ENV.fetch("WEATHER_LOCATION", "WEATHER"))

        Panel.new(
          title: location.upcase,
          lines: [
            "#{forecast.fetch(:temperature).round}#{unit}  #{forecast.fetch(:condition)}",
            "HIGH #{forecast.fetch(:high).round}#{unit}  LOW #{forecast.fetch(:low).round}#{unit}"
          ],
          footer: Date.current.strftime("%A")
        )
      end
    end
  end
end
