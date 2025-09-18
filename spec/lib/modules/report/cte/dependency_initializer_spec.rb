# frozen_string_literal: true

describe 'Report::Cte::DependencyInitializer' do
  class DummyNode < Report::Cte::Node
    attr_reader :important

    def initialize(important: false)
      @important = important
    end
  end

  let(:dependencies) { { instance: DummyNode.new, klass: DummyNode } }
  let(:attributes_to_cascade) { { important: true } }
  let(:initializer) { Report::Cte::DependencyInitializer.new(cascade_attributes: attributes_to_cascade) }

  it 'initializes class dependencies correctly' do
    expect(dependencies[:instance]).to be_a(DummyNode)
    expect(dependencies[:klass]).to be_a(Class)

    expect(initializer.call(dependencies)).to match(
      a_hash_including(
        instance: be_a(DummyNode),
        klass: be_a(DummyNode)
      )
    )
  end

  it 'cascades attributes to class dependencies' do
    expect(initializer.call(dependencies)).to match(
      a_hash_including(
        instance: have_attributes(important: false),
        klass: have_attributes(important: true)
      )
    )
  end

  it 'raises error for invalid dependency types' do
    dependencies = { invalid: 'not a node' }

    expect { initializer.call(dependencies) }.to raise_error(
      Report::Cte::DependencyInitializer::DependencyError,
      "Dependency must be a Node instance or subclass, got: #{dependencies[:invalid].class} (#{dependencies[:invalid].inspect})"
    )
  end
end
