class ApiRequestHistory

  def self.set_history_for_model model_name, args
    @@history ||= {}

    @@history[model_name] = {
      count: args[:count],
      totalcount: args[:totalcount]
    }
  end

  def self.get_history_for_model model_name
    @@history[model_name]
  end
end