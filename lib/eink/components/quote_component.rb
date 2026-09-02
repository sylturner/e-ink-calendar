module Eink
  module Components
    class QuoteComponent < Component
      key "quote"
      label "Quote of the day"
      minimum_size width: 2, height: 1
      refresh_every 1.day

      QUOTES = [
        [ "The future depends on what you do today.", "Mahatma Gandhi" ],
        [ "Well begun is half done.", "Aristotle" ],
        [ "Simplicity is the soul of efficiency.", "Austin Freeman" ],
        [ "Make each day your masterpiece.", "John Wooden" ],
        [ "The secret of getting ahead is getting started.", "Mark Twain" ]
      ].freeze

      def panel
        quote, author = QUOTES[Date.current.yday % QUOTES.length]
        Panel.new(title: "TODAY", lines: [ quote ], footer: author)
      end
    end
  end
end
