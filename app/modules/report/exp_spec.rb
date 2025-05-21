# frozen_string_literal: true

describe 'testing' do
  it 'does something' do
    structure = Report::Exp.pipeline_definition
    expect(structure).to be_a(Hash)
    debugger
    Report::Exp.create_collection_from_pipeline(structure)
  end
end
