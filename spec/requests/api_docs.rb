# frozen_string_literal: true



describe 'api-docs' do
  it 'the OpenAPI UI is mounted at api_docs' do
    request = get '/api-docs'
    expect(request).to redirect_to('/api-docs/index.html')
  end

  it 'the OpenAPI UI contains the endpoint to the spec' do
    get '/api-docs/index.html'

    expect_success
    expect(response_body).to include('{"urls":[{"url":"/api-docs/v2/swagger.yaml","name":"API V2 Docs"}]}')
  end

  def expect_openapi_doc
    get '/api-docs/v2/swagger.yaml'

    expect_success
    expect(response.content_type).to eq('text/yaml')
    YAML.safe_load(response_body, symbolize_names: true)
  end

  it 'can return the OpenAPI document' do
    result = expect_openapi_doc
    expect(result).to match(hash_including({
      openapi: an_instance_of(String),
      info: {
        title: 'Acoustic Workbench API',
        version: 'v2'
      },
      produces: an_instance_of(Array),
      consumes: an_instance_of(Array),
      paths: an_instance_of(Hash),
      servers: an_instance_of(Array),
      components: an_instance_of(Hash)
    }))
  end

  it 'changes default host and scheme for localhost' do
    result = expect_openapi_doc
    expect(result).to match(hash_including({
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
      ]
    }))
  end

  it 'changes default host and scheme for other hosts' do
    allow(Settings.host).to receive(:name).and_return('www.ecosounds.org')
    allow(Settings.host).to receive(:port).and_return('')
    allow(BawApp).to receive(:dev_or_test?).and_return(false)

    result = expect_openapi_doc
    expect(result).to match(hash_including({
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
      ]
    }))
  end
end
