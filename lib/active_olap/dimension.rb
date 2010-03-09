class ActiveOLAP::Dimension
  
  def self.const_missing(const)
    ActiveOLAP.load_missing_constant(self, const)
  end
  
  attr_accessor :variable

  def self.create(type, variable, attributes = {})
    klass = self.const_get(type.to_s.camelize)
    dimension = klass.new(variable)
    dimension.attributes = attributes
    dimension
  end
  
  def attributes=(hash)
    hash.each { |key, value| send(:"#{key}=", value) }
  end

  def initialize(variable, attributes = {})
    @variable = variable
    self.attributes = attributes if attributes.kind_of?(Hash)
  end
  
  def has_overlap?
    false
  end
  
  def drilldown_value_expression(options = {}, variables = {})
    raise "Please implement the drilldown_value_expression method in the #{self.class.name} dimension subclass!"
  end
  
  def drilldown_filter_expression(options = {}, variables = {})
    nil
  end
  
  def filter_expression(options = {}, variables = {})
    raise "Please implement the filter_expression method in the #{self.class.name} dimension subclass!"
  end
end