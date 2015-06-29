require 'spec_helper'

describe BawWorkers::Analysis::Payload do
  include_context 'shared_test_helpers'

  let(:payload) {
    BawWorkers::Analysis::Payload.new(BawWorkers::Config.logger_worker)
  }



end