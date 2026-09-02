module Eink
  module Components
    class GoogleDocComponent < Component
      key "google_doc"
      label "Google Doc"
      minimum_size width: 3, height: 3
      refresh_every 30.minutes

      def panel
        document_id = setting(:document_id, ENV["GOOGLE_DOC_ID"])
        raise GoogleClient::ConfigurationError, "Select a Google Doc in this component's settings" if document_id.blank?

        text = GoogleClient.new.document_text(document_id)
        lines = text.lines.map(&:strip).reject(&:blank?).first(24)
        lines = [ "This document is empty." ] if lines.empty?

        Panel.new(title: setting(:title, "NOTES"), lines: lines, footer: nil)
      end
    end
  end
end
