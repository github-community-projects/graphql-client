require "active_support/dependencies"
require "active_support/inflector"
require "graphql/client/erubis"

module GraphQL
  class Client
    module ViewModule
      attr_accessor :client

      # Public: Eager load module and all subdependencies.
      #
      # Use in production when cache_classes is true.
      #
      # Traverses all app/views/**/*.erb and loads all static constants defined in
      # ERB files.
      #
      # Examples
      #
      #   Views.eager_load!
      #
      # Returns nothing.
      def eager_load!
        return unless File.directory?(path)

        Dir.entries(path).each do |entry|
          next if entry == "." || entry == ".."
          name = entry.sub(/(\.\w+)+$/, "").camelize.to_sym
          if ViewModule.valid_constant_name?(name) && loadable_const_defined?(name)
            mod = const_get(name, false)
            mod.eager_load!
          end
        end

        nil
      end

      # Internal: Check if name is a valid Ruby constant identifier.
      #
      # name - String or Symbol constant name
      #
      # Examples
      #
      #   valid_constant_name?("Foo") #=> true
      #   valid_constant_name?("404") #=> false
      #
      # Returns true if name is a valid constant, otherwise false if name would
      # result in a "NameError: wrong constant name".
      def self.valid_constant_name?(name)
        name.to_s =~ /^[A-Z][a-zA-Z0-9_]*$/
      end

      # Public: Override constant defined to check if constant name matches a
      # view directory or template namespace.
      #
      # name - String or Symbol constant name
      # inherit - If the lookup will also search the ancestors (default: true)
      #
      # Returns true if definition is found, otherwise false.
      # def const_defined?(name, inherit = true)
      #   if super(name.to_sym, inherit)
      #     true
      #   elsif const_path(name)
      #     true
      #   else
      #     false
      #   end
      # end

      def loadable_const_defined?(name)
        if const_defined?(name.to_sym, false)
          true
        elsif const_path(name)
          true
        else
          false
        end
      end

      # Public: Source location that defined the Module.
      #
      # Returns absolute String path under app/views.
      attr_accessor :path

      # Internal: Detect source location for constant name.
      #
      # name - String or Symbol constant name
      #
      # Examples
      #
      #   Views.const_path(:Users) #=> "app/views/users"
      #   Views::Users.const_path(:Show) #=> "app/views/users/show.html.erb"
      #   Views::Users.const_path(:Profile) #=> "app/views/users/_profile.html.erb"
      #
      # Returns String absolute path to file, otherwise nil.
      def const_path(name)
        pathname = ActiveSupport::Inflector.underscore(name.to_s)
        Dir[File.join(path, "{#{pathname},_#{pathname}}{/,.*}")].map { |fn| File.expand_path(fn) }.first
      end

      # Internal: Initialize new module for constant name and load ERB statics.
      #
      # path - String path of directory or erb file.
      #
      # Examples
      #
      #   load_module("app/views/users")
      #   load_module("app/views/users/show.html.erb")
      #
      # Returns new Module implementing Loadable concern.
      def load_module(path)
        mod = Module.new

        if File.extname(path) == ".erb"
          contents = File.read(path)
          query, lineno = GraphQL::Client::Erubis.extract_graphql_section(contents)
          mod = client.parse(query, path, lineno) if query
        end

        mod.extend(ViewModule)
        mod.client = client
        mod.path = path
        mod
      end

      # Public: Implement constant missing hook to autoload View ERB statics.
      #
      # name - String or Symbol constant name
      #
      # Returns module or raises NameError if missing.
      def const_missing(name)
        path = const_path(name)

        if path
          mod = load_module(path)
          const_set(name, mod)
          mod.unloadable
          mod
        else
          super
        end
      end
    end
  end
end
