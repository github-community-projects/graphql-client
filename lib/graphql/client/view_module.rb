# frozen_string_literal: true
require "active_support/dependencies"
require "active_support/inflector"
require "graphql/client/erubis_enhancer"

module GraphQL
  class Client
    # Allows a magic namespace to map to app/views/**/*.erb files to retrieve
    # statically defined GraphQL definitions.
    #
    #   # app/views/users/show.html.erb
    #   <%grapql
    #     fragment UserFragment on User { }
    #   %>
    #
    #   # Loads graphql section from app/views/users/show.html.erb
    #   Views::Users::Show::UserFragment
    #
    module ViewModule
      attr_accessor :client

      # Public: Extract GraphQL section from ERB template.
      #
      # src - String ERB text
      #
      # Returns String GraphQL query and line number or nil or no section was
      # defined.
      def self.extract_graphql_section(src)
        query_string = src.scan(/<%graphql([^%]+)%>/).flatten.first
        return nil unless query_string
        [query_string, Regexp.last_match.pre_match.count("\n") + 1]
      end

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

      # Public: Directory to retrieve nested GraphQL definitions from.
      #
      # Returns absolute String path under app/views.
      attr_accessor :path

      # Internal: Initialize new module for constant name and load ERB statics.
      #
      # name - String or Symbol constant name.
      #
      # Examples
      #
      #   Views::Users.load_module(:Profile)
      #   Views::Users::Profile.load_module(:Show)
      #
      # Returns new Module implementing Loadable concern.
      def load_module(name)
        pathname = ActiveSupport::Inflector.underscore(name.to_s)
        path = Dir[File.join(self.path, "{#{pathname},_#{pathname}}{.*}")].map { |fn| File.expand_path(fn) }.first

        return if !path || File.extname(path) != ".erb"

        contents = File.read(path)
        query, lineno = ViewModule.extract_graphql_section(contents)
        return unless query

        mod = client.parse(query, path, lineno)
        mod.extend(ViewModule)
        mod.path = File.join(self.path, pathname)
        mod.client = client
        mod
      end

      def placeholder_module(name)
        dirname = File.join(path, ActiveSupport::Inflector.underscore(name.to_s))
        return nil unless Dir.exist?(dirname)

        Module.new.tap do |mod|
          mod.extend(ViewModule)
          mod.path = dirname
          mod.client = client
        end
      end

      # Public: Implement constant missing hook to autoload View ERB statics.
      #
      # name - String or Symbol constant name
      #
      # Returns module or raises NameError if missing.
      def const_missing(name)
        placeholder = placeholder_module(name)
        const_set(name, placeholder) if placeholder

        mod = load_module(name)
        return placeholder || super unless mod

        remove_const(name) if placeholder
        const_set(name, mod)
        mod.unloadable
        mod
      end
    end
  end
end
