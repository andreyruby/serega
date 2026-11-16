# frozen_string_literal: true

# Table of contents generation and link checking for the documentation files.
module DocsTasks
  # Guides index, which is a list of links itself
  GUIDES_INDEX = "docs/README.md"

  # Sections a guide needs for a table of contents
  TOC_MIN_SECTIONS = 2

  # Files checked for broken links
  LINK_FILES = (%w[README.md CHEATSHEET.md CHANGELOG.md RELEASE.md] + Dir["docs/*.md"].sort).freeze

  # Files whose examples name people
  NAME_FILES = (%w[README.md CHEATSHEET.md] + Dir["docs/*.md", "lib/**/*.rb", "spec/**/*.rb"].sort).freeze

  # Examples name people from Despicable Me (Felonious Gru, Lucy, Margo, ...);
  # these Breaking Bad and Batman names were replaced
  REPLACED_NAMES = /\b(?:walter|jesse|skyler|heisenberg|pinkman|bruce|wayne|batman|alfred|pennyworth|selina|gotham)\b/i

  TOC_HEADING = "## Table of Contents"
  TOC_START = "<!-- toc -->"
  TOC_END = "<!-- tocstop -->"

  class << self
    # Files with a generated table of contents: the cheatsheet, and every guide
    # with at least TOC_MIN_SECTIONS sections
    #
    # @return [Hash{String => Integer}] Files with the deepest heading level included
    def toc_files
      guides = (Dir["docs/*.md"].sort - [GUIDES_INDEX]).select do |file|
        headings(File.read(file)).count { |level, _title| level == 2 } >= TOC_MIN_SECTIONS
      end

      {"CHEATSHEET.md" => 2}.merge(guides.to_h { |file| [file, 3] })
    end

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
    # @return [Array<String>] Anchors of all headings
    def defined_anchors(text)
      seen = {}
      headings(text).map { |_level, title| anchor(title, seen) }
    end

    # @param file [String] Markdown file path
    # @return [Array<String>] Links to missing files and anchors that no heading defines
    def broken_links(file)
      text = File.read(file)
      inline = text.scan(/\]\(([^)\s]+)\)/).flatten
      reference = text.scan(/^\[[^\]]+\]:\s*(\S+)/).flatten

      (inline + reference).uniq.reject { |link| link.match?(/\A\w+:/) || link_valid?(file, link) }
    end

    # @param file [String] Markdown file path
    # @param link [String] Relative link, with an optional anchor
    # @return [Boolean] Whether the linked file and anchor exist
    def link_valid?(file, link)
      path, anchor = link.split("#", 2)
      target = path.empty? ? file : File.join(File.dirname(file), path)
      return false unless File.exist?(target)
      return true if anchor.nil? || !target.end_with?(".md")

      defined_anchors(File.read(target)).include?(anchor)
    end
  end
end

namespace :docs do
  desc "Write the table of contents into the documentation files"
  task :toc do
    DocsTasks.toc_files.each do |file, max_level|
      text = File.read(file)
      toc = DocsTasks.build_toc(text, max_level)
      File.write(file, DocsTasks.replace_toc(text, toc))
      puts "#{file}: table of contents written"
    end
  end

  desc "Check the table of contents is current, all links resolve and examples name Despicable Me people"
  task :check do
    errors = []

    DocsTasks.toc_files.each do |file, max_level|
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
      DocsTasks.broken_links(file).each do |link|
        errors << "#{file}: link #{link} matches no file or heading"
      end
    end

    DocsTasks::NAME_FILES.each do |file|
      File.foreach(file).with_index(1) do |line, number|
        name = line[DocsTasks::REPLACED_NAMES]
        errors << "#{file}:#{number}: #{name} — name people from Despicable Me, such as Felonious Gru or Lucy" if name
      end
    end

    raise "\n#{errors.join("\n")}" unless errors.empty?

    puts "Documentation tables of contents, links and example names are valid"
  end
end

require "rdoc/task"

# `rake rdoc` writes the documentation site to doc/: the README, the guides and
# the API. `rake rdoc:coverage` fails on undocumented public code.
RDoc::Task.new do |rdoc|
  gemspec = Gem::Specification.load("serega.gemspec")
  rdoc.rdoc_dir = "doc"
  rdoc.options.concat(gemspec.rdoc_options)
  rdoc.rdoc_files.include(*gemspec.extra_rdoc_files, "CHEATSHEET.md", "docs/*.md", "lib/**/*.rb")
end
