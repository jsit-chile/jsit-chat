require 'administrate/field/base'

# Renders the JSIT AI functions flag as an on/off button on the accounts index.
class AiFunctionsField < Administrate::Field::Base
  def enabled?
    data == true
  end

  def to_s
    enabled? ? 'ON' : 'OFF'
  end
end
