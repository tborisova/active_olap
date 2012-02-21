module ActiveOLAP
  module Utils
    # Merges conditions so that the result is a valid +condition+
    def merge_conditions(*conditions)
      segments = []

      conditions.each do |condition|
        unless condition.blank?   
          sql = self.send(:sanitize_sql, condition)
          segments << sql unless sql.blank?
        end
      end

      "(#{segments.join(') AND (')})" unless segments.empty?
    end
  end
end