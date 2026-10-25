# frozen_string_literal: true

# Draws assets/benchmarks.svg from the JSON table of README.md: the speed of
# each serializer in each case as a share of the hand-written Hash. Serega is
# blue, the other serializers are gray. benchmarks/full.rb redraws it after it
# updates the tables; `ruby benchmarks/chart.rb` redraws it alone.

module BenchmarkChart
  README = File.expand_path("../README.md", __dir__)
  SVG = File.expand_path("../assets/benchmarks.svg", __dir__)

  # Label of the row every share is measured against
  BASE_ROW = "hand-written Hash"
  # Label of the highlighted row
  HIGHLIGHT_ROW = "Serega"

  WIDTH = 840
  LABEL_WIDTH = 196
  COLUMN_WIDTH = 124
  # Bar length of 100%
  SCALE = 72.0
  TOP = 92
  ROW_HEIGHT = 26
  BAR_HEIGHT = 12
  RADIUS = 4
  FONT = "system-ui, -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"

  STYLE = <<~CSS
    text { font-family: #{FONT}; fill: #52514e; }
    .title { font-size: 15px; font-weight: 600; fill: #0b0b0b; }
    .case { font-size: 12px; font-weight: 600; fill: #0b0b0b; }
    .row { font-size: 13px; }
    .row.highlight { font-weight: 700; fill: #0b0b0b; }
    .value { font-size: 12px; font-weight: 600; fill: #0b0b0b; }
    .muted { font-size: 11px; fill: #6e6d68; }
    .bar { fill: #96948d; }
    .bar.highlight { fill: #2a78d6; }
    .axis { stroke: #c3c2b7; stroke-width: 1; }
    .grid { stroke: #d8d7d0; stroke-width: 1; }
    @media (prefers-color-scheme: dark) {
      text { fill: #c3c2b7; }
      .title, .case, .row.highlight, .value { fill: #f0efec; }
      .muted { fill: #9a9890; }
      .bar { fill: #6b6a64; }
      .bar.highlight { fill: #3987e5; }
      .axis { stroke: #4a4a46; }
      .grid { stroke: #30302d; }
    }
  CSS

  class << self
    # Writes the chart of the README.md JSON table
    #
    # @return [void]
    def call
      cases, rows = table(File.read(README))
      File.write(SVG, svg(cases, rows))
      puts "Updated #{SVG}"
    end

    private

    # Case names and rows of the JSON table. A row holds the label and the
    # serializations per second of each case, nil for a case the serializer
    # does not run.
    def table(text)
      lines = text[/<!-- benchmarks:json -->\n(.*?)<!-- benchmarks:json:end -->/m, 1].lines
      header, _separator, *body = lines.map { |line| line.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip) }
      cases = header.drop(1).map { |name| name.delete("`") }
      rows = body.map do |label, *values|
        [label.delete("*"), values.map { |value| (value == "—") ? nil : value.delete(",").to_i }]
      end
      [cases, rows]
    end

    def svg(cases, rows)
      base = rows.to_h.fetch(BASE_ROW)
      shares = rows.reject { |label, _| label == BASE_ROW }.map do |label, values|
        [label, values.each_with_index.map { |value, index| value && (100.0 * value / base[index]).round }]
      end
      height = TOP + (shares.size * ROW_HEIGHT) + 34

      elements = [title]
      cases.each_with_index { |name, index| elements.concat(column(name, index, shares)) }
      shares.each_with_index { |(label, _), index| elements << row_label(label, index) }

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{height}" viewBox="0 0 #{WIDTH} #{height}" role="img" aria-labelledby="title desc">
        <title id="title">JSON serializations per second, as a share of a hand-written Hash</title>
        <desc id="desc">#{description(cases, shares)}</desc>
        <style>
        #{STYLE.chomp}
        </style>
        #{elements.join("\n")}
        </svg>
      SVG
    end

    def title
      %(<text class="title" x="16" y="26">JSON serializations per second, as a share of a hand-written Hash</text>)
    end

    # Case name, 0% axis, 100% gridline, bars and the value labels of the
    # highlighted row of one case
    def column(name, index, shares)
      x = LABEL_WIDTH + (index * COLUMN_WIDTH)
      bottom = TOP + (shares.size * ROW_HEIGHT)
      first_line, second_line = name.split(" with ")
      elements = [%(<text class="case" x="#{x}" y="58">#{escape(first_line)}</text>)]
      elements << %(<text class="case" x="#{x}" y="74">with #{escape(second_line)}</text>) if second_line
      elements << %(<line class="grid" x1="#{x + SCALE}" y1="#{TOP - 6}" x2="#{x + SCALE}" y2="#{bottom}"/>)
      elements << %(<line class="axis" x1="#{x}" y1="#{TOP - 6}" x2="#{x}" y2="#{bottom}"/>)
      elements << %(<text class="muted" x="#{x + SCALE}" y="#{bottom + 16}" text-anchor="middle">100%</text>)

      shares.each_with_index do |(label, values), row|
        elements.concat(bar(x, TOP + (row * ROW_HEIGHT), values[index], label == HIGHLIGHT_ROW))
      end
      elements
    end

    # Bar with a rounded end, square at the axis. A case the serializer does
    # not run gets a dash.
    def bar(x, row_top, share, highlight)
      center = row_top + (ROW_HEIGHT / 2)
      y = center - (BAR_HEIGHT / 2)
      return [%(<text class="muted" x="#{x + 6}" y="#{center + 4}">—</text>)] unless share

      length = [SCALE * share / 100, 1].max.round(1)
      css_class = highlight ? "bar highlight" : "bar"
      elements = [%(<path class="#{css_class}" d="#{bar_path(x, y, length)}"/>)]
      elements << %(<text class="value" x="#{x + length + 6}" y="#{center + 4}">#{share}%</text>) if highlight
      elements
    end

    def bar_path(x, y, length)
      return "M#{x},#{y}h#{length}v#{BAR_HEIGHT}h-#{length}z" if length <= RADIUS

      straight = (length - RADIUS).round(1)
      "M#{x},#{y}h#{straight}a#{RADIUS},#{RADIUS} 0 0 1 #{RADIUS},#{RADIUS}v#{BAR_HEIGHT - (2 * RADIUS)}" \
        "a#{RADIUS},#{RADIUS} 0 0 1 -#{RADIUS},#{RADIUS}h-#{straight}z"
    end

    def row_label(label, index)
      css_class = (label == HIGHLIGHT_ROW) ? "row highlight" : "row"
      y = TOP + (index * ROW_HEIGHT) + (ROW_HEIGHT / 2) + 4
      %(<text class="#{css_class}" x="16" y="#{y}">#{escape(label)}</text>)
    end

    # Text of the chart for screen readers: the share of each serializer in
    # each case
    def description(cases, shares)
      shares.map do |label, values|
        cells = cases.zip(values).map { |name, share| "#{name} #{share ? "#{share}%" : "not run"}" }
        "#{label}: #{cells.join(", ")}."
      end.join(" ")
    end

    def escape(text)
      text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end

BenchmarkChart.call if $PROGRAM_NAME == __FILE__
