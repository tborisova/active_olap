module ActiveRecord::OLAP
  class QueryResult
    
    attr_accessor :klass
    attr_accessor :dimensions
    attr_accessor :result
    
    def initialize(klass, dimensions, query_result = nil)
      @klass      = klass
      @dimensions = dimensions

      unless query_result.nil?
        @result = []        
        populate_result_with(query_result)
        traverse_result_for_nils(@result)
      end
    end
    
    def depth
      @dimensions.length
    end
    
    def inspect
      @result.inspect
    end
    
    def transposed_result
      raise "Can only transpose a result with two dimensions" unless depth == 2
      @result.transpose
    end
    
    def [](*args)
      result = @result.clone
      args.each_with_index do |cat_label, index|
        cat_index = @dimensions[index].category_index(cat_label)
        puts "Index for #{cat_label.inspect}: #{cat_index.inspect}"
        return nil if cat_index.nil?
        result = result[cat_index]
      end
      
      if result.kind_of?(Array)
        # build a new query_result object if not enoug dimensions were provided
        puts "Building less dimensions: " + @dimensions[args.length...@dimensions.length].inspect
        result_object = QueryResult.new(@klass, @dimensions[args.length...@dimensions.length])
        result_object.result = result
        return result_object
      else
        return result
      end
    end
    
    def each(&block)
      @dimensions.first.categories.length.times do |i|
        puts "Current category: " + @dimensions.first.categories[i].label.inspect
        yield(@dimensions.first.categories[i], self[@dimensions.first.categories[i].label])
      end
    end
    
    protected

    def result=(array)
      @result = array
    end

    def populate_result_with(query_result)
      query_result.each do |row|
        
        result = @result
        values = row.attributes_before_type_cast
        discard_data = false
        
        puts "\n\nLoading results from row..."
        puts values.inspect
        
        (@dimensions.length - 1).times do |dim_index|
          
          category_name = values.delete("dimension_#{dim_index}")
          if @dimensions[dim_index].is_field_dimension?
            # this field contains the value of the category_field, which should be used as category
            # this might be the first time this category is seen, so register it in the dimension
            category_index = @dimensions[dim_index].register_category(category_name)
            puts "Got new cat index: " + category_index.inspect
            
          elsif category_name.nil?
            # this is a record for rows that did not fall in any of the categories of a dimension
            # therefore, this data can be discarded. This should not happen if an "other"-field is present!
            discard_data = true
            break 
            
          else
            # get the index of the category, which should exist
            category_index = @dimensions[dim_index].category_index(category_name.to_sym)
            puts "Using cat index: " + category_index.inspect
          end 
          
          puts "Dimension #{dim_index}, category #{category_name.inspect} (#{category_index})"
          
          # switch the result to the next dimension
          result[category_index] = [] if result[category_index].nil? # add a new dimension if needed
          result = result[category_index] # set the result to the next dimension for the next iteration
        end
        
        unless discard_data
          dim = @dimensions.last # only the last dimension is remaining
          if dim.is_field_dimension?
            # the last dimension is a field category.
            # every category is represented as a single row, with only one count per row
            dimension_field_value = values["dimension_#{@dimensions.length - 1}"]
            index = dim.register_category(dimension_field_value)
            puts "Categogory index for #{dimension_field_value.inspect}: #{index.inspect}"
            result[index] = values['the_olap_count_field'].to_i
            puts " -> storing value: " + values['the_olap_count_field']
          else
            # the last dimension is a normal category, using SUMs.
            # every category will have its number on this row
            result = [] if result.nil?
            values.each do |key, value| 
              result[dim.category_index(key.to_sym)] = value.to_i 
              puts " -> storing value: " + value
            end
          end
        end
      end
    end
    
    def traverse_result_for_nils(result, depth = 0)
      dim = @dimensions[depth]
      if dim == @dimensions.last
        # set all categories to 0 if no value is set
        dim.categories.length.times do |i|
          result[i] = 0 if result[i].nil?
        end
      else
        # if no value set, create an empty array and iterate to the next dimension
        # so all values will be set to 0
        dim.categories.length.times do |i|
          result[i] = [] if result[i].nil?
          traverse_result_for_nils(result[i], depth + 1)
        end        
      end
    end
  end
end