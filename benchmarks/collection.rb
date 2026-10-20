# frozen_string_literal: true

# 100 posts with five attributes.

require_relative "support"

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

benchmark(
  "collection", :json,
  "plain ruby" => -> { JSON.generate(POSTS.map { |post| PlainRuby.post(post) }) },
  "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS, many: true)) },
  "alba" => -> { alba_serializer.new(POSTS).serialize },
  "blueprinter" => -> { blueprinter_serializer.render(POSTS) },
  "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) },
  "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).to_json },
  "oj_serializers" => -> { oj_serializer.many_as_json(POSTS).to_json }
)

benchmark(
  "collection", :hash,
  "plain ruby" => -> { POSTS.map { |post| PlainRuby.post(post) } },
  "serega" => -> { serega_serializer.to_h(POSTS, many: true) },
  "alba" => -> { alba_serializer.new(POSTS).serializable_hash },
  "blueprinter" => -> { blueprinter_serializer.render_as_hash(POSTS) },
  "panko_serializer" => -> { panko_serializer.serialize(POSTS) },
  "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POSTS, serializer: ActiveModel::Serializer::CollectionSerializer, each_serializer: ams_serializer).serializable_hash },
  "oj_serializers" => -> { oj_serializer.many_as_hash(POSTS) }
)
