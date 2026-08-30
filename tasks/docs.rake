# frozen_string_literal: true

# Table of contents generation and link checking for the documentation files.
module DocsTasks
  # Files with a generated table of contents, and the deepest heading level included
  TOC_FILES = {"README.md" => 3, "CHEATSHEET.md" => 2}.freeze

  # Files checked for broken anchor links
  LINK_FILES = %w[README.md CHEATSHEET.md CHANGELOG.md RELEASE.md].freeze

  TOC_HEADING = "## Table of Contents"
  TOC_START = "<!-- toc -->"
  TOC_END = "<!-- tocstop -->"

  class << self
    # Headings outside fenced code blocks
    #
    # @param text [String] File contents
    # @return [Array<Array(Integer, String)>] Heading levels with their titles
    def headings(text)
      fenced = false
      text.lines.filter_map do |line|
        fenced = !fenced if line.start_with?("```")
        next if fenced

        match = line.match(/^(\#{1,6})\s+(.+?)\s*$/)
        next unless match

        [match[1].size, match[2]]
      end
    end

    # GitHub anchor for a heading title. Repeated titles get a numeric suffix.
    #
    # @param title [String] Heading title
    # @param seen [Hash] Anchors already generated for the same file
    # @return [String] Anchor without the leading "#"
    def anchor(title, seen)
      base = title.downcase.gsub(/[^\w\s-]/, "").gsub(/\s/, "-")
      count = seen[base]
      seen[base] = count ? count + 1 : 0
      count ? "#{base}-#{count + 1}" : base
    end

    # @param text [String] File contents
    # @param max_level [Integer] Deepest heading level to include
    # @return [String] Table of contents list
    def build_toc(text, max_level)
      seen = {}
      lines = headings(text).filter_map do |level, title|
        slug = anchor(title, seen)
        next if level == 1
        next if title == TOC_HEADING.delete_prefix("## ")
        next if level > max_level

        "#{" " * 3 * (level - 2)}- [#{title}](##{slug})"
      end

      lines.join("\n")
    end

    # @return [Regexp] Table of contents block, including empty ones
    def toc_regexp
      /^#{Regexp.escape(TOC_START)}\n(.*?)#{Regexp.escape(TOC_END)}$/mo
    end

    # @param text [String] File contents
    # @return [String, nil] Table of contents currently present in the file
    def current_toc(text)
      match = text.match(toc_regexp)
      match && match[1].strip
    end

    # Replaces the table of contents between the marker comments
    #
    # @param text [String] File contents
    # @param toc [String] Table of contents list
    # @return [String] Updated file contents
    #
    # @raise [RuntimeError] When the marker comments are missing
    def replace_toc(text, toc)
      raise "missing #{TOC_START} / #{TOC_END} markers" unless text.match?(toc_regexp)

      text.sub(toc_regexp, "#{TOC_START}\n\n#{toc}\n\n#{TOC_END}")
    end

    # @param text [String] File contents
    # @return [Array<String>] Anchors that no heading defines
    def broken_anchors(text)
      seen = {}
      defined_anchors = headings(text).map { |_level, title| anchor(title, seen) }

      inline = text.scan(/\]\((#[\w-]+)\)/).flatten
      reference = text.scan(/^\[[^\]]+\]:\s*(#[\w-]+)/).flatten

      (inline + reference).uniq.reject { |link| defined_anchors.include?(link.delete_prefix("#")) }
    end
  end
end

namespace :docs do
  desc "Write the table of contents into the documentation files"
  task :toc do
    DocsTasks::TOC_FILES.each do |file, max_level|
      text = File.read(file)
      toc = DocsTasks.build_toc(text, max_level)
      File.write(file, DocsTasks.replace_toc(text, toc))
      puts "#{file}: table of contents written"
    end
  end

  desc "Check the table of contents is current and all anchor links resolve"
  task :check do
    errors = []

    DocsTasks::TOC_FILES.each do |file, max_level|
      text = File.read(file)
      current = DocsTasks.current_toc(text)
      if current.nil?
        errors << "#{file}: no table of contents found between #{DocsTasks::TOC_START} and #{DocsTasks::TOC_END}"
        next
      end

      expected = DocsTasks.build_toc(text, max_level)
      next if current == expected.strip

      missing = expected.lines.map(&:chomp) - current.lines.map(&:chomp)
      extra = current.lines.map(&:chomp) - expected.lines.map(&:chomp)
      errors << "#{file}: table of contents is out of date, run `bundle exec rake docs:toc`"
      missing.each { |line| errors << "  missing: #{line.strip}" }
      extra.each { |line| errors << "  extra:   #{line.strip}" }
    end

    DocsTasks::LINK_FILES.each do |file|
      DocsTasks.broken_anchors(File.read(file)).each do |link|
        errors << "#{file}: link #{link} matches no heading"
      end
    end

    raise "\n#{errors.join("\n")}" unless errors.empty?

    puts "Documentation tables of contents and anchor links are valid"
  end
end
