# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/sites_spec.rb.

[:shallow, :nested].each do |routing|
  describe "Site permissions (#{routing})" do
    create_audio_recordings_hierarchy

    let!(:other_project) { create(:project, creator: admin_user) }
    let!(:other_site) { create(:site, projects: [other_project], region: nil, creator: admin_user) }

    given_the_route(routing == :nested ? '/projects/{project_id}/sites' : '/sites') do
      { project_id: project.id, id: site.id }
    end

    send_create_body do
      [
        { site: { name: 'created site', project_ids: [project.id], region_id: region.id } },
        :json
      ]
    end
    send_update_body do
      [{ site: { name: 'updated site' } }, :json]
    end

    # Exercise the POST filter used by the acceptance cases, as well as GET.
    with_custom_action :filter_post, path: 'filter', verb: :post, expect: :list, body: [{}, :json]

    for_lists_expects do |user, _action|
      expected =
        case user
        when :admin
          routing == :nested ? [site] : [site, other_site]
        when :owner, :writer, :reader
          [site]
        else
          []
        end

      # The shared helper checks inclusion, not exclusion of inaccessible sites.
      expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
      expected
    end

    the_users :admin, :owner, can_do: everything
    the_users :writer, :reader, can_do: reading + [:filter_post]
    the_user :harvester, can_do: nothing
    the_user :invalid, can_do: nothing, fails_with: :unauthorized

    if routing == :nested
      the_user :no_access, can_do: [:new]
      the_user :anonymous, can_do: [:new], fails_with: :unauthorized
    else
      the_user :no_access, can_do: listing + [:filter_post]
      the_user :anonymous, can_do: listing + [:filter_post], fails_with: :unauthorized
    end
  end
end
