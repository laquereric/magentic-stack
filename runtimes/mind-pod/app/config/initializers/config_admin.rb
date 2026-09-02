# frozen_string_literal: true

# ROLE=config fails closed at boot when the vault URL / caller token are
# missing, and when SECRET_KEY_BASE is the pod default. Other roles skip.
Rails.application.config.after_initialize do
  ConfigAdmin::Boot.abort_if_config!(Rails.application.config.x.role)
end
