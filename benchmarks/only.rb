# frozen_string_literal: true

# 100 posts with relations, keeping the post id and title, the author name and
# the comment bodies. alba, blueprinter and oj_serializers have no runtime
# field selection.

require_relative "support"

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

benchmark(
  "only", :json,
  "plain ruby" => -> { JSON.generate(POSTS.map(&plain_ruby)) },
  "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS)) },
  "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) },
  "active_model_serializers" => lambda {
    ActiveModelSerializers::SerializableResource.new(POSTS, each_serializer: ams_serializer, fields: ams_fields).to_json
  }
)

benchmark(
  "only", :hash,
  "plain ruby" => -> { POSTS.map(&plain_ruby) },
  "serega" => -> { serega_serializer.to_h(POSTS) },
  "panko_serializer" => -> { panko_serializer.serialize(POSTS) },
  "active_model_serializers" => lambda {
    ActiveModelSerializers::SerializableResource.new(POSTS, each_serializer: ams_serializer, fields: ams_fields).serializable_hash
  }
)
