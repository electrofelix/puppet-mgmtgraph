module PuppetX
module CatalogTranslation
  class Type
    attr_reader :name

    @instances = {}

    def initialize(name,&block)
      @name = name
      @translations = {}
      @custom_title = false
      instance_eval(&block)
      self.class.register self
    end

    def translate!(resource)
      result = {}
      # temporarily set @resource to the parameter
      # for use by the blocks
      @resource = resource

      @translations.each do |attr,translation|
        title = translation[:alias] || attr

        if translation[:spawned]
          result[title] = translation[:block].call
          next
        end

        next if !resource.parameters[attr]

        result[title] = if translation.has_key?(:block)
          translation[:block].call(resource[attr])
        else
          resource[attr]
        end
      end
      @resource = nil
      result
    end

    def output
      @output || @name
    end

    def self.translation_for(type)
      unless @instances.has_key? :default_translation
        load_translator(:default_translation)
      end
      unless @instances.has_key? type
        load_translator(type)
      end
      @instances[type] || @instances[:default_translation]
    end

    def title(resource)
      if @custom_title
        @resource = resource
        result = @translations[:name][:block].call
        @resource = nil
        result
      else
        resource[:name]
      end
    end

    # For testing only: unloads all translators.
    def self.clear
      @instances = {}
      @translations = {}
    end

    private

    def self.register(instance)
      @instances[instance.name] = instance
    end

    def self.loader
      @loader ||= Puppet::Util::Autoload.new(self, "puppetx/catalog_translation/type")
    end

    def self.load_translator(type)
      loader.load(type)
    end

    # below are DSL methods

    def carry(*attributes,&block)
      attributes.each do |attribute|
        @translations[attribute] = { :title => attribute, }
        if block_given?
          @translations[attribute][:block] = block
        end
      end
    end

    def rename(attribute,newname,&block)
      if block_given?
        carry(attribute) { |x| block.call(x) }
      else
        carry attribute
      end
      @translations[attribute][:alias] = newname
    end

    def spawn(*attributes,&block)
      attributes.each do |attribute|
        carry(attribute) { yield }
        @translations[attribute][:spawned] = true
      end
    end

    def emit(output)
      raise "emit has been called twice for #{name}" if @output
      @output = output
    end

    def override_title
      @custom_title = true
    end

  end
end
end
