# frozen_string_literal: true

RSpec.shared_examples 'an archivable route' do |archivable_route_options|
  supports_additional_actions = archivable_route_options.fetch(:supports_additional_actions, true)
  let(:route) { instance_exec(&archivable_route_options[:route]) }
  let(:instance) { instance_exec(&archivable_route_options[:instance]) }
  let(:index_route) { route.gsub(%r{/\d+$}, '') }

  let(:archivable_route_options) { archivable_route_options }

  def assert_baseline
    return unless archivable_route_options[:baseline]

    instance_exec(&archivable_route_options[:baseline])
  end

  def assert_after_archive
    return unless archivable_route_options[:after_archive]

    instance_exec(&archivable_route_options[:after_archive])
  end

  def assert_after_delete
    return unless archivable_route_options[:after_delete]

    instance_exec(&archivable_route_options[:after_delete])
  end

  let(:archived_header) {
    'X-Archived-At'
  }

  let(:location_header) {
    'Location'
  }

  let(:archived_param) {
    '?with_archived'
  }

  disable_cookie_jar

  def assert_archived_header
    before_time = Time.zone.now.floor(0)

    yield

    expect(response.headers).to include(archived_header)
    archived_at = Time.zone.parse(response.headers[archived_header])

    # ideally we'd assert it's just greater but the test can complete
    # in less than a second and the header is only accurate to the second.
    # >= is good enough though because it still asserts the header is set
    # and not an old value.
    expect(archived_at).to be >= before_time
  end

  it 'checks our baselines is correct' do
    assert_baseline
  end

  it 'archives when we call delete' do
    assert_archived_header do
      delete route, **api_headers(admin_token)
    end

    expect_no_content

    expect(instance.reload).to be_discarded
    assert_after_archive
  end

  if supports_additional_actions
    [:post, :delete].each do |method|
      it "can hard delete an archived record via an action (with #{method})" do
        instance.discard!

        send(method, "#{route}/destroy", **api_headers(admin_token))

        expect_no_content
        expect(response.headers).not_to include archived_header
        expect(response.headers).not_to include location_header

        perform_purge_jobs

        expect { instance.reload }.to raise_error(ActiveRecord::RecordNotFound)

        assert_after_delete
      end

      it "can hard delete a normal record via an action (with #{method})" do
        expect(instance).not_to be_discarded

        send(method, "#{route}/destroy", **api_headers(admin_token))

        expect_no_content
        expect(response.headers).not_to include archived_header
        expect(response.headers).not_to include location_header

        perform_purge_jobs

        expect { instance.reload }.to raise_error(ActiveRecord::RecordNotFound)

        assert_after_delete
      end
    end
  else
    [:post, :delete].each do |method|
      if method == :post
        'Invalid action: unknown action: `destroy`'
      else
        'Could not find the requested page.'
      end => message

      it "does not support hard delete on an archived record via an action (with #{method})" do
        instance.discard!

        send(method, "#{route}/destroy", **api_headers(admin_token))

        expect_error(:not_found, message)
      end

      it "does not support hard delete on a normal record via an action (with #{method})" do
        expect(instance).not_to be_discarded

        send(method, "#{route}/destroy", **api_headers(admin_token))

        expect_error(:not_found, message)
      end
    end

  end

  if supports_additional_actions
    it 'can recover a archived instance via an action' do
      instance.discard!

      assert_after_archive

      post "#{route}/recover", **api_headers(admin_token)

      expect_success
      expect(response.headers[location_header]).to eq(route)

      expect(instance.reload).not_to be_discarded

      get route, **api_headers(admin_token)
      expect_success
      expect_id_matches(instance)

      assert_baseline
    end
  else
    it 'does not support recovery via an action' do
      instance.discard!

      post "#{route}/recover", **api_headers(admin_token)

      expect_error(
        :not_found,
        'Invalid action: unknown action: `recover`'
      )
    end
  end

  it 'when archived will respond with a gone response' do
    assert_archived_header do
      instance.discard!

      get route, **api_headers(admin_token)

      expect_gone
    end
  end

  it 'when archived will not be included in a list' do
    instance.discard!

    get index_route, **api_headers(admin_token)

    expect_success
    expect(api_result[:data].map(&:id)).not_to include(instance.id)
  end

  it 'allows access to archived records with a query string' do
    assert_archived_header do
      instance.discard!

      get "#{route}#{archived_param}", **api_headers(admin_token)

      expect_success
      expect_id_matches(instance)
    end
  end

  it 'allows access to archived records in a list with a query string' do
    instance.discard!

    get "#{index_route}#{archived_param}", **api_headers(admin_token)

    expect_success
    expect_has_ids(instance.id)
  end
end
