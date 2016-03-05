class Model
  def self.name
    ''
  end

  def self.base_path
    "/#{$authenticator.version}/#{$practiceid}/#{self.name}"
  end
end