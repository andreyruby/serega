# frozen_string_literal: true

require_relative "setup"

# The reports of each benchmark case, by format: :json reports return a JSON
# String, :hash reports return Hashes, with String or Symbol keys. Every report
# returns the data of the "plain ruby" report.
module BenchmarkCases
  class << self
    # One post with five attributes.
    def single
      # One serializer per gem. A serega serializer serializes many times, thus it
      # is prepared once. The others are classes: alba, panko_serializer and
      # active_model_serializers make a new instance per object, blueprinter and
      # oj_serializers serialize with class methods.
      serega_serializer = SeregaPostSerializer.new
      alba_serializer = AlbaPostResource
      blueprinter_serializer = PostBlueprint
      panko_serializer = PankoPostSerializer # its instances are single-use
      ams_serializer = AmsPostSerializer
      oj_serializer = OjPostSerializer

      {
        json: {
          "plain ruby" => -> { JSON.generate(PlainRuby.post(POST)) },
          "serega" => -> { JSON.generate(serega_serializer.to_h(POST, many: false)) },
          "alba" => -> { alba_serializer.new(POST).serialize },
          "blueprinter" => -> { blueprinter_serializer.render(POST) },
          "panko_serializer" => -> { panko_serializer.new.serialize_to_json(POST) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POST, serializer: ams_serializer).to_json },
          "oj_serializers" => -> { oj_serializer.one_as_json(POST).to_json }
        },
        hash: {
          "plain ruby" => -> { PlainRuby.post(POST) },
          "serega" => -> { serega_serializer.to_h(POST, many: false) },
          "alba" => -> { alba_serializer.new(POST).serializable_hash },
          "blueprinter" => -> { blueprinter_serializer.render_as_hash(POST) },
          "panko_serializer" => -> { panko_serializer.new.serialize(POST) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POST, serializer: ams_serializer).serializable_hash },
          "oj_serializers" => -> { oj_serializer.one_as_hash(POST) }
        }
      }
    end

    # 100 posts with five attributes.
    def collection
      # One serializer per gem. serega serializers and panko_serializer array
      # serializers serialize many times, thus they are prepared once. The others
      # are classes: alba and active_model_serializers make a new instance per
      # collection, blueprinter and oj_serializers serialize with class methods.
      serega_serializer = SeregaPostSerializer.new
      alba_serializer = AlbaPostResource
      blueprinter_serializer = PostBlueprint
      panko_serializer = Panko::ArraySerializer.new([], each_serializer: PankoPostSerializer)
      ams_serializer = AmsPostSerializer
      oj_serializer = OjPostSerializer

      {
        json: {
          "plain ruby" => -> { JSON.generate(POSTS.map { |post| PlainRuby.post(post) }) },
          "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS, many: true)) },
          "alba" => -> { alba_serializer.new(POSTS).serialize },
          "blueprinter" => -> { blueprinter_serializer.render(POSTS) },
          "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).to_json },
          "oj_serializers" => -> { oj_serializer.many_as_json(POSTS).to_json }
        },
        hash: {
          "plain ruby" => -> { POSTS.map { |post| PlainRuby.post(post) } },
          "serega" => -> { serega_serializer.to_h(POSTS, many: true) },
          "alba" => -> { alba_serializer.new(POSTS).serializable_hash },
          "blueprinter" => -> { blueprinter_serializer.render_as_hash(POSTS) },
          "panko_serializer" => -> { panko_serializer.serialize(POSTS) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).serializable_hash },
          "oj_serializers" => -> { oj_serializer.many_as_hash(POSTS) }
        }
      }
    end

    # 100 posts with their author and 10 comments each.
    def relations
      # One serializer per gem. serega serializers and panko_serializer array
      # serializers serialize many times, thus they are prepared once. The others
      # are classes: alba and active_model_serializers make a new instance per
      # collection, blueprinter and oj_serializers serialize with class methods.
      serega_serializer = SeregaPostWithRelationsSerializer.new
      alba_serializer = AlbaPostWithRelationsResource
      blueprinter_serializer = PostBlueprint
      panko_serializer = Panko::ArraySerializer.new([], each_serializer: PankoPostWithRelationsSerializer)
      ams_serializer = AmsPostWithRelationsSerializer
      oj_serializer = OjPostWithRelationsSerializer

      {
        json: {
          "plain ruby" => -> { JSON.generate(POSTS.map { |post| PlainRuby.post_with_relations(post) }) },
          "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS, many: true)) },
          "alba" => -> { alba_serializer.new(POSTS).serialize },
          "blueprinter" => -> { blueprinter_serializer.render(POSTS, view: :with_relations) },
          "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).to_json },
          "oj_serializers" => -> { oj_serializer.many_as_json(POSTS).to_json }
        },
        hash: {
          "plain ruby" => -> { POSTS.map { |post| PlainRuby.post_with_relations(post) } },
          "serega" => -> { serega_serializer.to_h(POSTS, many: true) },
          "alba" => -> { alba_serializer.new(POSTS).serializable_hash },
          "blueprinter" => -> { blueprinter_serializer.render_as_hash(POSTS, view: :with_relations) },
          "panko_serializer" => -> { panko_serializer.serialize(POSTS) },
          "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).serializable_hash },
          "oj_serializers" => -> { oj_serializer.many_as_hash(POSTS) }
        }
      }
    end

    # 100 posts with relations, keeping the post id and title, the author name and
    # the comment bodies. alba, blueprinter and oj_serializers have no runtime
    # field selection.
    def only
      plain_ruby = lambda do |post|
        comments = post.comments.map { |comment| {body: comment.body} }
        {id: post.id, title: post.title, author: {name: post.author.name}, comments:}
      end

      # One serializer per gem. serega serializers and panko_serializer array
      # serializers serialize many times, thus they are prepared once with the
      # field selection. active_model_serializers makes a new instance per
      # collection, thus it gets the field selection in each call.
      serega_serializer = SeregaPostWithRelationsSerializer.new(only: [:id, :title, {author: :name, comments: :body}])
      panko_serializer = Panko::ArraySerializer.new(
        [], each_serializer: PankoPostWithRelationsSerializer,
        only: {instance: [:id, :title, :author, :comments], author: [:name], comments: [:body]}
      )
      ams_serializer = AmsPostWithRelationsSerializer
      ams_fields = [:id, :title, :author, :comments, {user: [:name], comment: [:body]}]

      {
        json: {
          "plain ruby" => -> { JSON.generate(POSTS.map(&plain_ruby)) },
          "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS, many: true)) },
          "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) },
          "active_model_serializers" => lambda {
            ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer, fields: ams_fields).to_json
          }
        },
        hash: {
          "plain ruby" => -> { POSTS.map(&plain_ruby) },
          "serega" => -> { serega_serializer.to_h(POSTS, many: true) },
          "panko_serializer" => -> { panko_serializer.serialize(POSTS) },
          "active_model_serializers" => lambda {
            ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer, fields: ams_fields).serializable_hash
          }
        }
      }
    end

    # 100 posts with relations, without the post body and the comment creation
    # times. Only serega and panko_serializer have runtime `except`.
    def except
      plain_ruby = lambda do |post|
        comments = post.comments.map { |comment| {id: comment.id, body: comment.body} }
        author = PlainRuby.user(post.author)
        {id: post.id, title: post.title, author_id: post.author_id, created_at: post.created_at.iso8601(3), author:, comments:}
      end

      # One serializer per gem. serega serializers and panko_serializer array
      # serializers serialize many times, thus they are prepared once with the
      # field selection.
      serega_serializer = SeregaPostWithRelationsSerializer.new(except: [:body, {comments: :created_at}])
      panko_serializer = Panko::ArraySerializer.new([], each_serializer: PankoPostWithRelationsSerializer, except: {instance: [:body], comments: [:created_at]})

      {
        json: {
          "plain ruby" => -> { JSON.generate(POSTS.map(&plain_ruby)) },
          "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS, many: true)) },
          "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) }
        },
        hash: {
          "plain ruby" => -> { POSTS.map(&plain_ruby) },
          "serega" => -> { serega_serializer.to_h(POSTS, many: true) },
          "panko_serializer" => -> { panko_serializer.serialize(POSTS) }
        }
      }
    end

    # Raises when a report returns other data than the "plain ruby" report.
    def check(format, reports)
      parse = ->(result) { JSON.parse((format == :json) ? result : JSON.generate(result)) }
      expected = parse.call(reports.fetch("plain ruby").call)

      reports.each do |report, block|
        result = block.call
        raise "#{report}: returns #{result.class}, not a #{format} result" unless result.is_a?((format == :json) ? String : Enumerable)

        path = first_difference(expected, parse.call(result))
        raise "#{report}: output differs from plain ruby at #{path}" if path
      end
    end

    private

    # Returns the path of the first value that differs, like `$[0].comments[1].body`.
    def first_difference(expected, actual, path = "$")
      case expected
      when Hash
        return path unless actual.is_a?(Hash) && actual.keys.sort == expected.keys.sort
        expected.each_key.lazy.filter_map { |key| first_difference(expected[key], actual[key], "#{path}.#{key}") }.first
      when Array
        return path unless actual.is_a?(Array) && actual.size == expected.size
        expected.each_index.lazy.filter_map { |index| first_difference(expected[index], actual[index], "#{path}[#{index}]") }.first
      else
        path unless expected == actual
      end
    end
  end
end
