# frozen_string_literal: true

# Notes of a GitHub Release, made from the section of the version in CHANGELOG.md
module ReleaseTasks
  REPOSITORY = "https://github.com/andreyruby/serega"

  # A fenced code block, kept whole, or a line break between two lines of
  # text where the second line starts no list item, heading or code block
  UNWRAP = /(^ *```.*?^ *```$)|(?<=\S)\n(?!- |#| *```)[ \t]*(?=\S)/m

  class << self
    # Notes of the release of a version: its CHANGELOG section with joined
    # lines, links at the tag of the version, and a link that compares the
    # tag with the tag of the previous version
    def notes(version, changelog, tags)
      tag = "v#{version}"
      body = absolute_links(unwrap(section(version, changelog)), tag)
      previous = previous_tag(version, tags)
      previous ? "#{body}\n\n**Full Changelog**: #{REPOSITORY}/compare/#{previous}...#{tag}\n" : "#{body}\n"
    end

    private

    # The text under the `## [version]` heading, up to the next version heading
    def section(version, changelog)
      match = changelog.match(/^## \[#{Regexp.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\z)/m)
      raise "CHANGELOG.md has no section for #{version}" unless match

      match[1].strip
    end

    # Joins the wrapped lines of paragraphs and list items, since release
    # notes show each line break. Code blocks stay as they are.
    def unwrap(text)
      text.gsub(UNWRAP) { $1 || " " }
    end

    # Makes relative links point to the files at the tag
    def absolute_links(text, tag)
      text.gsub(/\]\((?!\w+:|#)([^)]+)\)/) { "](#{REPOSITORY}/blob/#{tag}/#{$1})" }
    end

    # The tag of the highest version lower than the given version
    def previous_tag(version, tags)
      current = Gem::Version.new(version)
      previous = tags.grep(/\Av\d+(\.\d+)*\z/)
        .map { |tag| Gem::Version.new(tag.delete_prefix("v")) }
        .select { |tag_version| tag_version < current }.max
      "v#{previous}" if previous
    end
  end
end

namespace :release do
  desc "Print the GitHub Release notes of the version in VERSION, or of release:notes[version]"
  task :notes, [:version] do |_task, args|
    version = args[:version] || File.read("VERSION").strip
    tags = `git tag`.split
    print ReleaseTasks.notes(version, File.read("CHANGELOG.md"), tags)
  end
end
