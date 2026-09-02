require "json"
require "net/http"
require "uri"

module Eink
  class GoogleClient
    class ConfigurationError < StandardError; end

    TOKEN_URI = URI("https://oauth2.googleapis.com/token")
    CALENDAR_API = "https://www.googleapis.com/calendar/v3"
    DOCS_API = "https://docs.googleapis.com/v1"
    DRIVE_API = "https://www.googleapis.com/drive/v3"

    def configured?
      %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN].all? { |key| ENV[key].present? }
    end

    def calendars
      get("#{CALENDAR_API}/users/me/calendarList").fetch("items", []).map do |calendar|
        { id: calendar.fetch("id"), name: calendar.fetch("summary") }
      end
    end

    def events(calendar_ids:, starts_at:, ends_at:)
      calendar_ids.flat_map do |calendar_id|
        query = URI.encode_www_form(
          timeMin: starts_at.iso8601,
          timeMax: ends_at.iso8601,
          singleEvents: true,
          orderBy: "startTime",
          maxResults: 25
        )
        get("#{CALENDAR_API}/calendars/#{URI.encode_uri_component(calendar_id)}/events?#{query}")
          .fetch("items", [])
          .map { |event| normalize_event(event) }
      end.sort_by { |event| event.fetch(:starts_at) }
    end

    def documents
      query = URI.encode_www_form(
        q: "mimeType='application/vnd.google-apps.document' and trashed=false",
        fields: "files(id,name)",
        orderBy: "modifiedTime desc",
        pageSize: 100
      )
      get("#{DRIVE_API}/files?#{query}").fetch("files", []).map do |document|
        { id: document.fetch("id"), name: document.fetch("name") }
      end
    end

    def document_text(document_id)
      document = get("#{DOCS_API}/documents/#{URI.encode_uri_component(document_id)}")

      document.dig("body", "content").to_a.filter_map do |element|
        text = element.dig("paragraph", "elements").to_a.filter_map { |run| run.dig("textRun", "content") }.join
        text.strip.presence
      end.join("\n")
    end

    private

    def get(url)
      ensure_configured!
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      parse_response(Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) })
    end

    def access_token
      Rails.cache.fetch("eink-google-access-token", expires_in: 50.minutes) do
        refresh_access_token.fetch("access_token")
      end
    end

    def refresh_access_token
      request = Net::HTTP::Post.new(TOKEN_URI)
      request.set_form_data(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        refresh_token: ENV.fetch("GOOGLE_REFRESH_TOKEN"),
        grant_type: "refresh_token"
      )

      parse_response(Net::HTTP.start(TOKEN_URI.host, TOKEN_URI.port, use_ssl: true) { |http| http.request(request) })
    end

    def parse_response(response)
      payload = JSON.parse(response.body)
      return payload if response.is_a?(Net::HTTPSuccess)

      raise "Google API request failed (#{response.code}): #{payload["error_description"] || payload["error"]}"
    end

    def ensure_configured!
      return if configured?

      raise ConfigurationError, "Google credentials are missing from .env"
    end

    def normalize_event(event)
      start_value = event.fetch("start").values_at("dateTime", "date").compact.first
      end_value = event.fetch("end").values_at("dateTime", "date").compact.first

      {
        summary: event.fetch("summary", "Untitled event"),
        starts_at: Time.zone.parse(start_value),
        ends_at: Time.zone.parse(end_value),
        all_day: event.fetch("start").key?("date")
      }
    end
  end
end
