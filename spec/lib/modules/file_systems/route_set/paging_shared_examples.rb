# frozen_string_literal: true

PageableOptions = Data.define(:route, :count, :create, :test_total) {
  def initialize(route:, count:, create:, test_total: 25)
    super(route:, count:, create:, test_total:)

    def max_page
      (test_total / limit.to_f).ceil
    end

    def limit
      5
    end
  end
}

# assumes `route_set` and `analysis_job_id` is defined
# @param [PageableOptions] options
# @option options [String] :route
# @option options [Proc] :count
# @option options [Proc] :create
RSpec.shared_examples 'a pageable resource' do |options|
  raise 'options must be a PageableOptions' unless options.is_a?(PageableOptions)

  let(:options) { options }

  def paging(page: 1, disable_paging: false)
    {
      offset: (page - 1) * options.limit,
      limit: options.limit,
      disable_paging:
    }
  end

  let(:route) {
    next options.route if options.route.is_a?(String)

    instance_exec(&options.route)
  }

  let(:test_total) {
    options.test_total
  }

  stepwise 'the given route can be paged' do
    step 'get a count of current items' do
      @count = instance_exec(&options.count)
    end

    step 'generate an appropriate set of extra items' do
      i = 0
      while instance_exec(&options.count) < test_total
        i += 1
        instance_exec(i, &options.create)

        raise 'too many iterations' if i > 100
      end
    end

    step "assert count is now #{options.test_total}" do
      expect(instance_exec(&options.count)).to eq(test_total)
    end

    (1..options.max_page).map do |i|
      step "page through all of the results, page #{i}" do
        page = paging(page: i)
        result = route_set.show(route, 'application/json', page, analysis_job_id:)

        (@pages ||= []) << result
      end
    end

    step 'all the pages should be directory wrappers' do
      expect(@pages).to all(be_a(FileSystems::Structs::DirectoryWrapper))
    end

    step 'all the pages should have the total count' do
      expect(@pages).to all(have_attributes(total_count: test_total))
    end

    step 'each page should have the correct number of items, and there should be no duplicates' do
      previous_children = []

      # page count should be the limit unless it is the last page
      @pages.each_with_index do |page, i|
        expect(page.children.size).to eq(
          (i + 1) == @pages.count ? test_total / options.limit : options.limit
        )
        expect(page.children).to all(be_a(FileSystems::Structs::Entry))
        paths = page.children.map(&:path)

        expect(paths).to match paths.uniq
        expect(paths.intersection(previous_children)).to be_empty

        previous_children += paths
      end
    end

    step 'we can also disable paging and get the whole result set' do
      page = paging(disable_paging: true)
      result = route_set.show(route, 'application/json', page, analysis_job_id:)
      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.total_count).to eq(test_total)
      expect(result.children.size).to eq(test_total)
    end
  end
end
