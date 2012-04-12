require "active_support/core_ext/class"
require "spira/association_reflection"

module Spira
  module Resource
    def type(uri = nil)
      if uri
        if @type
          raise ResourceDeclarationError, "Attempt to redeclare the type for the resource"
        else
          if uri.is_a?(RDF::URI)
            singleton_class.class_eval do
              define_method(:_type) { uri }
              private :_type
            end
            @type = uri
          else
            raise TypeError, "Type must be a RDF::URI"
          end
        end
      else
        respond_to?(:_type, true) ? _type : nil
      end
    end

    ##
    # Add a property to this class.  A property is an accessor field that
    # represents an RDF predicate.
    #
    # @example A simple string property
    #     property :name, :predicate => FOAF.name, :type => String
    # @example A property which defaults to {Spira::Types::Any}
    #     property :name, :predicate => FOAF.name
    # @example An integer property
    #     property :age,  :predicate => FOAF.age, :type => Integer
    # @param  [Symbol] name The name of this property
    # @param  [Hash{Symbol => Any}] opts property options
    # @option opts [RDF::URI]            :predicate The RDF predicate which will refer to this property
    # @option opts [Spira::Type, String] :type      (Spira::Types::Any) The
    # type for this property.  If a Spira::Type is given, that class will be
    # used to serialize and unserialize values.  If a String is given, it
    # should be the String form of a Spira::Base class name (Strings are
    # used to prevent issues with load order).
    # @see Spira::Types
    # @see Spira::Type
    # @return [Void]
    def property(name, opts = {})
      predicate = predicate_for(opts[:predicate], name)
      type = type_for(opts[:type])
      properties[name] = HashWithIndifferentAccess.new(:predicate => predicate, :type => type)

      define_method "#{name}=" do |arg|
        write_attribute name, arg
      end
      define_method name do
        read_attribute name
      end
    end

    ##
    # The plural form of `property`.  `Has_many` has the same options as
    # `property`, but instead of a single value, a Ruby Array of objects will
    # be created instead.
    #
    # has_many corresponds to an RDF subject with several triples of the same
    # predicate.  This corresponds to a Ruby Set, which will be returned when
    # the property is accessed.  Arrays will be accepted for new values, but
    # ordering and duplicate values will be lost on save.
    #
    # @see Spira::Base::DSL#property
    def has_many(name, opts = {})
      property(name, opts)

      reflections[name] = AssociationReflection.new(:has_many, name, opts)

      define_method "#{name.to_s.singularize}_ids" do
        send(name).map(&:id).compact
      end
      define_method "#{name.to_s.singularize}_ids=" do |ids|
        records = ids.map {|id| self.class.reflect_on_association(name).klass.unserialize(id) }.compact
        send "#{name}=", Set.new(records)
      end
    end


    private

    ##
    # Determine the predicate for a property based on the given predicate, name, and default vocabulary
    #
    # @param  [#to_s, #to_uri] predicate
    # @param  [Symbol] name
    # @return [RDF::URI]
    # @private
    def predicate_for(predicate, name)
      case
      when predicate.respond_to?(:to_uri) && predicate.to_uri.absolute?
        predicate
      when @default_vocabulary.nil?
        raise ResourceDeclarationError, "A :predicate option is required for types without a default vocabulary"
      else
        # FIXME: use rdf.rb smart separator after 0.3.0 release
        separator = @default_vocabulary.to_s[-1,1] =~ /(\/|#)/ ? '' : '/'
        RDF::URI.intern(@default_vocabulary.to_s + separator + name.to_s)
      end
    end

  end
end
