# frozen_string_literal: true

require 'rails_helper'

describe 'api-docs' do
  it 'is mounted at api_docs' do
    get '/api-docs'
  end

  it 'changes default host and scheme for localhost' do
    get '/api-docs/v2/swagger.yaml'

    expect_success
    expect(response.content_type).to eq('text/yaml')
    result = YAML.safe_load(response_body, symbolize_names: true)
    expect(result).to match(hash_including({
      openapi: an_instance_of(String),
      info: {
        title: 'Acoustic Workbench API',
        version: 'v2'
      },
      produces: an_instance_of(Array),
      consumes: an_instance_of(Array),
      paths: an_instance_of(Hash),
      servers: [
        {
          url: '{protocol}://{authority}',
          variables: {
            protocol: {
              enum: array_including(['http', 'https']),
              default: 'http'
            },
            authority: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      components: an_instance_of(Hash)
    }))
  end

  it '/changes default host and scheme for other hosts' do
    allow(Settings.host).to receive(:name).and_return('www.ecosounds.org')
    allow(Settings.host).to receive(:port).and_return('')
    allow(BawApp).to receive(:dev_or_test?).and_return(false)

    get '/api-docs/v2/swagger.yaml'

    expect_success
    expect(response.content_type).to eq('text/yaml')
    result = YAML.safe_load(response_body, symbolize_names: true)
    expect(result).to match(hash_including({
      openapi: an_instance_of(String),
      info: {
        title: 'Acoustic Workbench API',
        version: 'v2'
      },
      produces: an_instance_of(Array),
      consumes: an_instance_of(Array),
      paths: an_instance_of(Hash),
      servers: [
        {
          url: '{protocol}://{authority}',
          variables: {
            protocol: {
              enum: array_including(['http', 'https']),
              default: 'https'
            },
            authority: {
              default: 'www.ecosounds.org'
            }
          }
        }
      ],
      components: an_instance_of(Hash)
    }))
  end
end
