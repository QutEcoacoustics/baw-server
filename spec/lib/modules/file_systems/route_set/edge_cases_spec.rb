# frozen_string_literal: true

require_relative 'route_set_context'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'edge cases' do
    let(:route_set) {
      FileSystems::RouteSet.new(
        root: FileSystems::Root.new(
          '/',
          AnalysisJobsItem.where(analysis_job_id:)
        ),
        virtual: FileSystems::Virtual.new(
          FileSystems::Virtual::Directory.new(AnalysisJobsItem)
        ),
        physical: FileSystems::Physical.new(
          items_to_paths: lambda { |items|
                            items.map(&:results_absolute_path)
                          }
        ),
        container: nil
      )
    }

    [
      '/.test',
      '/../',
      "\n",
      "/test.mp3\0",
      "/\0hhsfhsf",
      '/test/~',
      '/test/.hidden',
      "/test/\0x0007"
    ].each do |path|
      it "checks for illegal path segments: `#{path}`" do
        expect {
          route_set.show(path, nil, nil)
        }.to raise_error(CustomErrors::IllegalPathError)
      end
    end

    it 'can show hidden files if the option is set' do
      route_set.physical.instance_variable_set(:@show_hidden, true)

      result = route_set.show('/test/.hidden', nil, nil)
      expect(result).to be_a(FileSystems::Structs::FileWrapper)
    end

    it 'does not show hidden files by default' do
      expect {
        route_set.show('/test/.hidden', nil, nil)
      }.to raise_error(CustomErrors::IllegalPathError)
    end
  end
end
