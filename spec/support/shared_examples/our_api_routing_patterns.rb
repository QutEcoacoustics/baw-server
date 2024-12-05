# frozen_string_literal: true

# Example
#        it_behaves_like 'our api routing patterns', '/bookmarks', 'bookmarks', [:filterable, :capable, :invocable, :statistical]
RSpec.shared_examples 'our api routing patterns' do |path, controller, concerns, extra_options = {}, example_invocable = 'start'|
  raise 'unknown concerns' if (concerns - [:filterable, :capable, :invocable, :statistical, :archivable]).count > 0

  let(:filterable) { concerns.include?(:filterable) ? :to : :not_to }
  let(:capable) { concerns.include?(:capable) ? :to : :not_to }
  let(:invocable) { concerns.include?(:invocable) ? :to : :not_to }
  let(:statistical) { concerns.include?(:statistical) ? :to : :not_to }
  let(:archivable) { concerns.include?(:archivable) ? :to : :not_to }

  it {
    expect(get("#{path}/filter")).send(filterable, route_to(
      controller:, action: 'filter', format: 'json', **extra_options
    ))
  }

  it {
    expect(post("#{path}/filter")).send(filterable, route_to(
      controller:, action: 'filter', format: 'json', **extra_options
    ))
  }

  it {
    expect(get("#{path}/capabilities")).send(capable, route_to(
      controller:, action: 'capabilities', format: 'json', **extra_options
    ))
  }

  it {
    expect(get("#{path}/1/capabilities")).send(capable, route_to(
      controller:, action: 'capabilities', id: '1', format: 'json', **extra_options
    ))
  }

  it {
    expect(put("#{path}/1/#{example_invocable}")).send(invocable, route_to(
      controller:, action: 'invoke', id: '1', invoke_action: example_invocable, format: 'json', **extra_options
    ))
  }

  it do
    expect(post("#{path}/1/#{example_invocable}")).send(invocable, route_to(
      controller:, action: 'invoke', id: '1', invoke_action: example_invocable, format: 'json', **extra_options
    ))
  end

  it {
    expect(get("#{path}/stats")).send(statistical, route_to(
      controller:, action: 'stats', format: 'json', **extra_options
    ))
  }

  it {
    expect(post("#{path}/stats")).send(statistical, route_to(
      controller:, action: 'stats', format: 'json', **extra_options
    ))
  }

  it {
    expect(post("#{path}/1/destroy")).send(archivable, route_to(
      controller:, action: 'destroy_permanently', id: '1', format: 'json', **extra_options
    ))
  }

  it {
    expect(delete("#{path}/1/destroy")).send(archivable, route_to(
      controller:, action: 'destroy_permanently', id: '1', format: 'json', **extra_options
    ))
  }

  it {
    expect(post("#{path}/1/recover")).send(archivable, route_to(
      controller:, action: 'recover', id: '1', format: 'json', **extra_options
    ))
  }
end
