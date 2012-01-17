require 'active_support/concern'

module Delocalize
  module Delocalizable
    extend ActiveSupport::Concern

    included do
      class_attribute :delocalizable_fields
      class_attribute :delocalize_conversions
    end

    module ClassMethods
      def delocalize(conversions = {})
        self.delocalize_conversions ||= {}
        self.delocalizable_fields ||= []

        conversions.each do |field, type|
          delocalizable_fields << field.to_sym unless delocalizable_fields.include?(field.to_sym)
          delocalize_conversions[field.to_sym] = type.to_sym
          define_delocalize_attr_writer field.to_sym
        end
      end

      def delocalizing?
        delocalizable_fields.any?
      end

      def delocalizes?(field)
        delocalizing? && (delocalizable_fields || []).include?(field.to_sym)
      end

      def delocalizes_type_for(field)
        delocalize_conversions[field.to_sym]
      end

    private

      def define_delocalize_attr_writer(field)
        writer_method = "#{field}="

        class_eval <<-ruby, __FILE__, __LINE__ + 1
          if method_defined?(:#{writer_method})
            remove_method(:#{writer_method})
          end

          def #{writer_method}(value)
            if I18n.delocalization_enabled? && delocalizes?(:#{field})
              type = delocalizes_type_for(:#{field})

              case type
              when :number then value = LocalizedNumericParser.parse(value)
              when :date, :time then value = LocalizedDateTimeParser.parse(value, type.to_s.classify.constantize)
              end
            end

            write_attribute(:#{field}, value)
          end
        ruby
      end

    end

    # The instance methods are just here for convenience. They all delegate to their class.
    module InstanceMethods
      def delocalizing?
        self.class.delocalizing?
      end

      def delocalizes?(field)
        self.class.delocalizes?(field)
      end

      def delocalizes_type_for(field)
        self.class.delocalizes_type_for(field)
      end
    end
  end
end