module Remarkable # :nodoc:
  module ActiveRecord # :nodoc:
    module Matchers # :nodoc:

      class AssociationMatcher < Remarkable::Matcher::Base
        def initialize(macro, *associations)
          @options = associations.extract_options!
          @macro = macro
          @associations = associations
        end

        def through(through)
          @options[:through] = through
          self
        end

        def dependent(dependent)
          @options[:dependent] = dependent
          self
        end

        def matches?(subject)
          @subject = subject
          
          assert_matcher_for(@associations) do |association|
            association_correct?(association)
          end
        end

        def failure_message
          "Expected #{expectation} (#{@missing})"
        end

        def negative_failure_message
          "Did not expect #{expectation}"
        end

        def description
          description = "#{macro_description} #{@associations.to_sentence}"
          description += " through #{@options[:through]}" if @options[:through]
          description += " dependent => #{@options[:dependent]}" if @options[:dependent]
          description
        end

        protected

        def association_correct?(association)
          @name = association
          
          association_exists? && 
          macro_correct? && 
          foreign_key_exists? && 
          through_association_valid? && 
          dependent_correct? &&
          join_table_exists?
        end

        def association_exists?
          if reflection.nil?
            @missing = "no association called #{@name}"
            false
          else
            true
          end
        end

        def macro_correct?
          if reflection.macro == @macro
            true
          else
            @missing = "actual association type was #{reflection.macro}"
            false
          end
        end

        def foreign_key_exists?
          !(belongs_foreign_key_missing? || has_foreign_key_missing?)
        end

        def belongs_foreign_key_missing?
          @macro == :belongs_to && !class_has_foreign_key?(model_class)
        end

        def has_foreign_key_missing?
          [:has_many, :has_one].include?(@macro) &&
          !through? &&
          !class_has_foreign_key?(associated_class)
        end

        def through_association_valid?
          @options[:through].nil? || (through_association_exists? && through_association_correct?)
        end

        def through_association_exists?
          if through_reflection.nil?
            @missing = "#{model_name} does not have any relationship to #{@options[:through]}"
            false
          else
            true
          end
        end

        def through_association_correct?
          if @options[:through] == reflection.options[:through]
            @missing = "Expected #{model_name} to have #{@name} through #{@options[:through]}, " <<
            " but got it through #{reflection.options[:through]}"
            true
          else
            false
          end
        end

        def dependent_correct?
          if @options[:dependent].nil? || @options[:dependent].to_s == reflection.options[:dependent].to_s
            true
          else
            @missing = "#{@name} should have #{@options[:dependent]} dependency"
            false
          end
        end

        def join_table_exists?
          if @macro != :has_and_belongs_to_many || 
            ::ActiveRecord::Base.connection.tables.include?(join_table.to_s)
            true
          else
            @missing = "join table #{join_table} doesn't exist"
            false
          end
        end

        def class_has_foreign_key?(klass)
          if klass.column_names.include?(foreign_key.to_s)
            true
          else
            @missing = "#{klass} does not have a #{foreign_key} foreign key."
            false
          end
        end

        def join_table
          reflection.options[:join_table]
        end

        def associated_class
          reflection.klass
        end

        def foreign_key
          reflection.primary_key_name
        end

        def through?
          reflection.options[:through]
        end

        def reflection
          model_class.reflect_on_association(@name)
        end

        def through_reflection
          model_class.reflect_on_association(@options[:through])
        end

        def expectation
          "#{model_name} to have a #{@macro} association called #{@name}"
        end

        def macro_description
          case @macro.to_s
          when 'belongs_to' then 'belong to'
          when 'has_many'   then 'have many'
          when 'has_one'    then 'have one'
          when 'has_and_belongs_to_many' then
            'have and belong to many'
          end
        end
      end

      def belong_to(*associations)
        AssociationMatcher.new(:belongs_to, *associations)
      end

      def have_many(*associations)
        AssociationMatcher.new(:has_many, *associations)
      end

      def have_one(*associations)
        AssociationMatcher.new(:has_one, *associations)
      end

      def have_and_belong_to_many(*associations)
        AssociationMatcher.new(:has_and_belongs_to_many, *associations)
      end

    end
  end
end
