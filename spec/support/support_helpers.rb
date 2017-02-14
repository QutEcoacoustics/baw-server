# https://gist.github.com/3317023
module JsonHelpers
  def make_json_request(params)
    params = {format: 'json'}.merge(params)
    [:get, :put, :post, :delete].find do |method|
      path = params.delete(method) and send(method, path, params)
    end

    body = response.body.blank? ? nil : get_json(response.body)
    [response, body]
  end

  def get_json(str)
    symbolize_keys(JSON.parse(str))
  end

  private

  def symbolize_keys(o)
    case o
      when Hash then
        Hash[o.map { |k, v| [k.to_sym, symbolize_keys(v)] }]
      when Array then
        o.map { |e| symbolize_keys(e) }
      else
        o
    end
  end
end

RSpec.configure { |config| config.include JsonHelpers, :type => :controller }

module AudioHelpers
  # Add more helper methods to be used by all tests here...
  def self.get_source_audio_file_path(file_name)
    input_path = './test/fixtures/audio'
    File.join input_path, file_name
  end

  def self.get_temp_file_path(file_name)
    output_path = './tmp/testassests'
    FileUtils.makedirs(output_path)
    File.join output_path, file_name
  end

  def self.remove_temp_file_path()
    dir = File.expand_path('./tmp/testassests')
    if File.directory? dir
      FileUtils.rm_rf(dir)
    end
  end

  def self.delete_if_exists(file_path)

    file_name = file_path.chomp(File.extname(file_path))
    possible_paths = [file_path, file_name+'.webm', file_name+'.ogg']

    possible_paths.each { |file|
      if File.exists? file
        File.delete file
      end
    }
  end
end

RSpec.configure { |config| config.include AudioHelpers, :type => :model }

module CommonHelpers

  def convert_model(action, model_symbol, model, attributes_to_filter = [])

    attribute_filter = [:id, :created_at, :updated_at, :deleted_at, :creator_id, :updater_id, :deleter_id]
    attribute_filter.concat(attributes_to_filter.map { |item| item.to_s.to_sym })

    hash = {}

    if action == :create
      hash[:post] = :create
    elsif action == :update
      hash[:put] = :update
    end

    if model.blank?
      hash[model_symbol] = {}
    else
      hash[model_symbol] = model.attributes.clone.with_indifferent_access.except(*attribute_filter)
      hash[:id] = model.id if action == :update
    end

    hash
  end

  def convert_model_for_delete(model)
    hash = {delete: :destroy}

    unless model.empty?
      hash[:id] = model[:id]
    end

    hash
  end
end

RSpec.configure { |config| config.include CommonHelpers, :type => :controller }
