# frozen_string_literal: true

# OK: new paradigm
# We store results on disk per recording: analysis job id / uuid
# And we use virtual file systems to expose different structures.
class AnalysisJobsResultsController < ApplicationController
  include Api::ControllerHelper

  # GET|HEAD /analysis_jobs/:analysis_job_id/results[/:path]
  # Supports requests like /analysis_jobs/1/results/123456/Test1/Test2/test-CASE.csv
  def results
    common_action(:file_system_results)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/artifacts[/:path]
  # Supports requests like analysis_jobs/1/artifacts/3/3/2/2000/2000-03/20000328T070659Z_site-name-2_2.mp3/Test1/Test2
  #
  def artifacts
    common_action(:file_system_artifacts)
  end

  private

  # @param route_set [FileSystems::RouteSet]
  def common_action(route_set_name)
    # load analysis job
    analysis_job = AnalysisJobsItemsController.resolve_job_from_route_parameter(
      params[:analysis_job_id]
    )

    do_authorize_instance(:show, AnalysisJob)

    analysis_job_id = analysis_job.id
    path = params.fetch(:results_path, '')

    route_set = send(route_set_name, analysis_job)
    # We can't use our standard API filtering here because it assumes it is only
    # querying against the database. This action is querying against several
    # different file systems.
    opts = paging_only_params(params.slice(:analysis_job_id, :path).permit!)

    # this is a little crude. If multiple Accept headers are present,
    # we just take the first one.
    accept = request.accepts.first&.to_s || 'application/json'

    result = route_set.show(path, accept, opts, analysis_job_id:)
    send_filesystems_result(result, opts)
  end

  def base_query(analysis_job)
    Access::ByPermission.analysis_jobs_items(analysis_job, current_user)
  end

  AUDIO_RECORDING_VIRTUAL_DIRECTORY = FileSystems::Virtual::Directory.new(
    AudioRecording,
    AudioRecording::FRIENDLY_NAME_AREL,
    base_query_joins: :audio_recording,
    include_base_ids: true
  )

  SCRIPT_VIRTUAL_DIRECTORY = FileSystems::Virtual::Directory.new(
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
    base_query_joins: :script,
    include_base_ids: true
  )

  ITEMS_TO_PATHS = ->(items) { items.map(&:results_absolute_path) }

  def show_hidden
    can?(:show_hidden_files, AnalysisJobsItem)
  end

  # @return [FileSystems::RouteSet]
  def file_system_results(analysis_job)
    FileSystems::RouteSet.new(
      root: FileSystems::Root.new(
        url_for(only_path: true),
        base_query(analysis_job)
      ),
      virtual: FileSystems::Virtual.new(
        AUDIO_RECORDING_VIRTUAL_DIRECTORY,
        SCRIPT_VIRTUAL_DIRECTORY
      ),
      # represents a physical directory on disk
      # to advance to a container file system we differentiate on a container
      # being a directory if we request an API response (e.g. Accept: application/json)
      # or a container being a file if we request a file download (e.g. Accept: application/zip).
      physical: FileSystems::Physical.new(
        items_to_paths: ITEMS_TO_PATHS,
        show_hidden:
      ),
      # represents a sqlite database or any other container file (e.g. zip)
      container: FileSystems::Container.new
    )
  end

  # @return [FileSystems::RouteSet]
  def file_system_artifacts(analysis_job)
    FileSystems::RouteSet.new(
      root: FileSystems::Root.new(
        url_for(only_path: true),
        base_query(analysis_job)
      ),
      virtual: FileSystems::Virtual.new(
        FileSystems::Virtual::Directory.new(
          Project,
          :name,
          base_query_joins: { audio_recording: [site: [region: [:project]]] }
        ),
        # joins for all lower layers can be omitted since the join is already defined at the top layer
        FileSystems::Virtual::Directory.new(Region, :name),
        FileSystems::Virtual::Directory.new(Site, :name),
        FileSystems::Virtual::Directory.new(AudioRecording,
          FileSystems::Virtual::NamePath.new(
            name: AudioRecording::ArelExpressions::BY_YEAR_AREL,
            path: AudioRecording::ArelExpressions::BY_YEAR_AREL,
            coerce: FileSystems::Virtual::TO_S
          )),
        FileSystems::Virtual::Directory.new(AudioRecording,
          FileSystems::Virtual::NamePath.new(
            name: AudioRecording::ArelExpressions::BY_MONTH_AREL,
            path: AudioRecording::ArelExpressions::BY_MONTH_AREL,
            coerce: FileSystems::Virtual::TO_S
          )),
        AUDIO_RECORDING_VIRTUAL_DIRECTORY,
        SCRIPT_VIRTUAL_DIRECTORY
      ),
      physical: FileSystems::Physical.new(
        items_to_paths: ITEMS_TO_PATHS,
        show_hidden:
      ),
      container: FileSystems::Container.new
    )
  end
end
