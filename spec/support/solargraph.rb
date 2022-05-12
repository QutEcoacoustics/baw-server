# frozen_string_literal: true

require_relative 'request_spec_helpers'

# type hints for solargraph - imperfect but at least allows go to definition to work.
# The actual inclusion/extension happens in rails_helper with the RSpec
# `config.include` and `config.extend` helper methods which dynamically extend/include
# into each example group / example depending on RSpec metadata. That dynamic inclusion
# is the reason these type hints will produce false positives.
RSpec.describe '', skip: true do
  include MetadataState
  extend MetadataState::ExampleGroup

  extend ResqueHelpers::ExampleGroup
  include ResqueHelpers::Example

  extend RequestSpecHelpers::ExampleGroup
  include RequestSpecHelpers::Example

  extend MailerHelpers::ExampleGroup
  include MailerHelpers::Example

  extend ApiSpecHelpers::ExampleGroup

  extend PermissionsHelpers::ExampleGroup
  extend CapabilitiesHelper::ExampleGroup

  include FactoryBotHelpers::Example

  extend Creation::ExampleGroup
  include Creation::Example

  extend CitizenScienceCreation::ExampleGroup

  include AudioHelper::Example
  include TempFileHelpers::Example
end

RSpec.shared_examples 'nothing' do
  extend ResqueHelpers::ExampleGroup
  include ResqueHelpers::Example

  extend RequestSpecHelpers::ExampleGroup
  include RequestSpecHelpers::Example
end

raise 'This file should never actually be required. It exists only to provide type hints to solargraph'
