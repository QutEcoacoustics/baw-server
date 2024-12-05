# frozen_string_literal: true

require_relative 'route_set_context'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'alternate paths' do
    def base_route_path(*other_segments)
      initial = "/analysis_jobs/#{analysis_job_id}/results"

      return initial if other_segments.blank?

      other_segments = other_segments.map(&:to_s).join('/')
      "#{initial}/#{other_segments}"
    end

    let(:route_set) {
      FileSystems::RouteSet.new(
        root: FileSystems::Root.new(
          base_route_path,
          AnalysisJobsItem.where(analysis_job_id:)
        ),
        virtual: FileSystems::Virtual.new(
          FileSystems::Virtual::Directory.new(
            AudioRecording,
            FileSystems::Virtual::NamePath.new(
              name: AudioRecording::FRIENDLY_NAME_AREL,
              path: AudioRecording.arel_table[:id]
            ),
            base_query_joins: :audio_recording
          ),
          FileSystems::Virtual::Directory.new(
            Script,
            [
              # name: AP Indices (1.2.3), path: /1
              FileSystems::Virtual::NamePath.new(
                name: Script.name_and_version_arel,
                path: Script.arel_table[:id]
              ),
              # name: AP Indices (1.2.3), path: /ap-indices_1.2.3
              FileSystems::Virtual::NamePath.new(
                name: Script.name_and_version_arel,
                path: Script.analysis_identifier_and_version_arel,
                coerce: FileSystems::Virtual::TO_S
              ),
              # name: AP Indices (latest), path: /ap-indices_latest
              FileSystems::Virtual::NamePath.new(
                name: Script.latest_version_case_statement_arel(Script.name_and_latest_version_arel),
                path: Script.latest_version_case_statement_arel(Script.analysis_identifier_and_latest_version_arel),
                coerce: FileSystems::Virtual::TO_S,
                condition: lambda { |route_param|
                             Script.latest_version_case_statement_arel(
                                Script.analysis_identifier_and_latest_version_arel
                              ).eq(route_param)
                           }
              )
            ],
            base_query_joins: :script
          )
        ),
        # represents a physical directory on disk
        # to advance to a container file system we differentiate on a container
        # being a directory if we request an API response (e.g. Accept: application/json)
        # or a container being a file if we request a file download (e.g. Accept: application/zip).
        physical: FileSystems::Physical.new(
          items_to_paths: lambda { |items|
                            items.map(&:results_absolute_path)
                          }
        ),
        # represents a sqlite database or any other container file (e.g. zip)
        container: nil #FileSystems::Container.new(:path)
      )
    }
    # this should be exactly the same as the one_virtual_layer_spec.rb
    # but that is the test... that nothing changes when we add a virtual layer
    # with alternate paths

    let(:script_one_id) { script_one.id }
    let(:script_one_name) { Script.where(id: script_one.id).pick(Script.name_and_version_arel) }
    let(:script_one_identifier) { Script.where(id: script_one.id).pick(Script.analysis_identifier_and_version_arel) }

    let(:script_two_id) { script_two.id }
    let(:script_two_name) { Script.where(id: script_two.id).pick(Script.name_and_version_arel) }
    let(:script_two_name_latest) { Script.where(id: script_two.id).pick(Script.name_and_latest_version_arel) }
    let(:script_two_identifier) { Script.where(id: script_two.id).pick(Script.analysis_identifier_and_version_arel) }
    let(:script_two_identifier_latest) {
      Script.where(id: script_two.id).pick(Script.analysis_identifier_and_latest_version_arel)
    }

    before do
      create_analysis_result_file(item_one, Pathname('a.txt'), content: 'eat, sleep, code, repeat')
      create_analysis_result_file(item_two, Pathname('b.txt'), content: 'sleep, code, repeat, eat')

      script_one.update!(analysis_identifier: 'ap-indices', name: 'AP Indices')
      script_one.provenance.update!(version: '1.2.3')
      script_two.update!(analysis_identifier: 'ap-indices', name: 'AP Indices', group_id: script_one.group_id)
      script_two.provenance.update!(version: '2.3.4')
    end

    it 'can list audio recordings' do
      result = route_set.show('/', 'application/json', nil,
        analysis_job_id:)
      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path,
        name: '',
        analysis_job_id:,
        total_count: 2,
        children: [
          {
            path: base_route_path(recording_one.id),
            name: recording_one.friendly_name,
            has_children: true,
            link: "/audio_recordings/#{recording_one.id}"
          },
          {
            path: base_route_path(recording_two.id),
            name: recording_two.friendly_name,
            has_children: true,
            link: "/audio_recordings/#{recording_two.id}"
          }
        ]
      )
    end

    it 'can list scripts with alternate names' do
      result = route_set.show("/#{recording_one.id}", 'application/json', nil, analysis_job_id:)
      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_one.id),
        name: recording_one.friendly_name,
        analysis_job_id:,
        analysis_jobs_item_ids: item_ids_for(recording_one),
        link: "/audio_recordings/#{recording_one.id}",
        total_count: 2,
        children: [
          # name: AP Indices (1.2.3), path: /1
          # name: AP Indices (1.2.3), path: /ap-indices_1.2.3
          # but not latest! because script two has the latest
          {
            path: [
              base_route_path(recording_one.id, script_one_id),
              base_route_path(recording_one.id, script_one_identifier)
            ],
            name: [
              script_one_name,
              script_one_name
            ],
            has_children: true,
            link: "/scripts/#{script_one_id}"
          },
          # name: AP Indices (2.3.4), path: /1
          # name: AP Indices (2.3.4), path: /ap-indices_2.3.4
          # name: AP Indices (latest), path: /ap-indices_latest
          {
            path: [
              base_route_path(recording_one.id, script_two_id),
              base_route_path(recording_one.id, script_two_identifier),
              base_route_path(recording_one.id, script_two_identifier_latest)
            ],
            name: [
              script_two_name,
              script_two_name,
              script_two_name_latest
            ],
            has_children: true,
            link: "/scripts/#{script_two_id}"
          }
        ]
      )
    end

    [
      ['(1) id and name', :script_one, :script_one_id, :script_one_name],
      ['(1) identifier and name', :script_one, :script_one_identifier, :script_one_name],
      ['(2) id and name', :script_two, :script_two_id, :script_two_name],
      ['(2) identifier and name', :script_two, :script_two_identifier, :script_two_name],
      ['(2) latest and name', :script_two, :script_two_identifier_latest, :script_two_name_latest]
    ].each do |name, script_symbol, path_symbol, name_symbol|
      it "shows the correct alternate name based off of the path used for #{name}" do
        script = send(script_symbol)
        path = send(path_symbol)
        name = send(name_symbol)
        full_path = "/#{recording_one.id}/#{path}"

        result = route_set.show(full_path, 'application/json', nil, analysis_job_id:)

        expected_file = script_symbol == :script_one ? 'a.txt' : 'b.txt'

        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.to_h).to match(
          path: base_route_path(recording_one.id, path),
          name:,
          analysis_job_id:,
          analysis_jobs_item_ids: item_ids_for(recording_one, script),
          total_count: script_symbol == :script_one ? 5 : 3,
          link: "/scripts/#{script.id}",
          children: a_collection_including(
            {
              path: base_route_path(recording_one.id, path, expected_file),
              name: expected_file,
              size: 24,
              mime: 'text/plain'
            }
          )
        )
      end
    end
  end
end
