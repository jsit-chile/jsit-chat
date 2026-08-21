require 'administrate/field/base'

# Renders, as a button on the accounts index, whether the JSIT bot answers every
# conversation of the account unless it is paused.
class BotDefaultField < Administrate::Field::Base
  def enabled?
    data == true
  end

  def to_s
    enabled? ? 'AUTO' : 'MANUAL'
  end
end
