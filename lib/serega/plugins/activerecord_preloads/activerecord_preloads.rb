# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :activerecord_preloads` loads every `:preload` of the serialized
    # fields once, with `ActiveRecord::Associations::Preloader`
    #
    # ```ruby
    # class AppSerializer < Serega
    #   plugin :activerecord_preloads
    #   config.auto_preload = true
    # end
    # ```
    #
    # See [ActiveRecord preloads](https://github.com/andreyruby/serega/blob/master/docs/preloads.md#activerecord).
    module ActiverecordPreloads
      # Adds the plugin to the serializer
      def self.apply(serializer_class, **opts) # :nodoc:
        unless opts.empty?
          raise SeregaError, "Plugin :activerecord_preloads does not accept the #{opts.keys.first.inspect} option. No options are allowed"
        end

        require_relative "lib/preloader"

        serializer_class.preload_with do |objects, preloads|
          Preloader.preload(objects, preloads)
        end
      end
    end
  end
end
