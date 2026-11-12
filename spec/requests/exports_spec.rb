# frozen_string_literal: true

describe 'Exports' do
  create_entire_hierarchy

  let(:current_user) { owner_user }
  let(:current_token) { owner_token }

  let!(:export) { create(:export, creator: owner_user, project:) }
  let!(:other_export) { create(:export, creator: writer_user, project:) }

  it 'can show an export' do
    get "/exports/#{export.id}", params: nil, **api_headers(owner_token)

    expect(response).to have_http_status(:ok)
  end

  describe 'listing' do
    it 'index returns only the exports created by the current user' do
      get '/exports', params: nil, **api_headers(current_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(export)
      expect_does_not_have_ids(other_export)
    end

    it 'filter returns only the exports created by the current user' do
      get '/exports/filter', params: nil, **api_headers(current_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(export)
      expect_does_not_have_ids(other_export)
    end

    it 'filter with a body returns the matching export created by the current user' do
      body = { filter: { name: { eq: export.name } } }

      post '/exports/filter', params: body, **api_with_body_headers(current_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(export)
    end

    it 'index returns every export to an admin' do
      get '/exports', params: nil, **api_headers(admin_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(export, other_export)
    end

    it 'index returns an empty list when not logged in' do
      get '/exports', params: nil, **api_headers(anonymous_token)

      expect(response).to have_http_status(:ok)
      expect_zero_items
    end

    it 'show responds with forbidden for an export created by a different user' do
      get "/exports/#{other_export.id}", params: nil, **api_headers(current_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'destroy' do
    let(:export) { create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready') }

    after { clear_pending_jobs }

    it 'deletes an export created by the current user' do
      delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)

      expect_no_content
      expect(Export.exists?(export.id)).to be false
    end

    it 'deletes the attached file together with the export' do
      expect { delete "/exports/#{export.id}", params: nil, **api_headers(owner_token) }
        .to change(ActiveStorage::Attachment, :count).by(-1)

      expect_no_content
      expect(Export.exists?(export.id)).to be false
    end

    ['queued', 'working'].each do |status|
      it "responds with conflict and keeps the export when its status is #{status}" do
        export.update!(status: status)

        delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)

        expect_error(:conflict, "Cannot be deleted while `status` is `#{status}`")
        expect(Export.exists?(export.id)).to be true
      end
    end

    it 'responds with forbidden and keeps an export created by a different user' do
      other_export.update!(status: 'ready')

      delete "/exports/#{other_export.id}", params: nil, **api_headers(owner_token)

      expect(response).to have_http_status(:forbidden)
      expect(Export.exists?(other_export.id)).to be true
    end
  end

  describe 'Export type camtrap_dp' do
    pause_all_jobs

    let(:params) do
      {
        export_type: 'camtrap_dp',
        name: 'Test Export',
        filter: {},
        project_id: project.id,
        options: {
          contributors: [{ title: 'Alice' }],
          project_capture_method: ['continuous'],
          project_sampling_design: 'systematicRandom'
        }
      }
    end

    it 'can request a new camtrap_dp export' do
      post '/exports', params: params, **api_with_body_headers(owner_token)
      export = Export.find(api_data[:id])

      expect(response).to have_http_status(:created)
      expect(api_data).to include(
        {
          id: export.id,
          status: 'queued',
          project_id: project.id,
          export_type: 'camtrap_dp',
          creator_id: owner_user.id,
          name: 'Test Export',
          filter: {},
          options: params[:options],
          token: be_a(String),
          exchange_url: "http://web:3000/exports/#{export.id}/download?token=#{api_data[:token]}",
          expires_at: export.expires_at
        }
      )
      clear_pending_jobs
    end

    it 'responds with unprocessable entity when project_id is missing' do
      params.delete(:project_id)
      post '/exports', params: params, **api_with_body_headers(owner_token)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    describe 'download' do
      let(:export) { create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready') }
      let(:token) { export.signed_id(purpose: :export_download) }

      context 'when the export is ready' do
        it 'when a valid token is given, it returns the export file' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq 'application/zip'
          expect(response).to be_same_file_as(Fixtures.zip_fixture)
        end

        it 'when a valid token is given, it increases the download count by one' do
          expect {
            get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)
          }.to change { export.reload.download_count }.from(0).to(1)
        end

        it 'when a token was not signed for purpose :export_download, it rejects it' do
          bad_token = export.signed_id(purpose: :something_else)

          get "/exports/#{export.id}/download", params: { token: bad_token }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:not_found)
          expect(export.reload.download_count).to eq 0
        end

        it 'rejects a valid token that belongs to a different export than the one being requested' do
          other_export = create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready')
          other_token = other_export.signed_id(purpose: :export_download)

          get "/exports/#{export.id}/download", params: { token: other_token }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:not_found)
          expect(export.reload.download_count).to eq 0
        end
      end

      ['pending', 'queued', 'working'].each do |status|
        context "when the export is #{status}" do
          it 'responds with service unavailable when a valid token is given' do
            export.update!(status: status)

            get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

            expect(response).to have_http_status(:service_unavailable)
          end
        end
      end

      context 'when the export has failed' do
        before { export.update!(status: 'failed', error: 'The export could not be generated') }

        it 'responds with unprocessable entity when a valid token is given' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when the export has expired' do
        before { export.update!(status: 'ready', expires_at: 1.day.ago) }

        it 'responds with gone when a valid token is given' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:gone)
          expect(export.reload.download_count).to eq 0
        end
      end

      context 'when the export file was purged' do
        before { export.purge! }

        it 'responds with gone when a valid token is given' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:gone)
        end
      end

      context 'when the creator is a reader' do
        let!(:export) do
          create(:export, :with_zip_file, creator: reader_user, project:, status: 'ready', obfuscate_locations: true)
        end

        it 'using the token allows downloading the export file' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:ok)
        end

        it 'using the token, it denies access if the creator has lost access to the project' do
          reader_permission.destroy!

          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:unauthorized)
          expect(export.reload.download_count).to eq 0
        end

        it 'as the creator, it responds with forbidden if the creator has lost access to the project' do
          reader_permission.destroy!

          get "/exports/#{export.id}/download", **api_headers(reader_token)

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the export does not obfuscate locations' do
        let!(:export) do
          create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready', obfuscate_locations: false)
        end

        it 'using the token allows downloading the export file' do
          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:ok)
        end

        it 'using the token, it denies access if the creator is no longer an owner' do
          owner_permission.update!(level: 'writer')

          get "/exports/#{export.id}/download", params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:unauthorized)
          expect(export.reload.download_count).to eq 0
        end
      end

      context 'without a token' do
        it 'returns the export file to the user who created the export' do
          get "/exports/#{export.id}/download", **api_headers(owner_token)

          expect(response).to have_http_status(:ok)
          expect(response).to be_same_file_as(Fixtures.zip_fixture)
        end

        it 'responds with forbidden to a different logged-in user' do
          get "/exports/#{export.id}/download", **api_headers(writer_token)

          expect(response).to have_http_status(:forbidden)
        end

        it 'responds with unauthorized when not logged in' do
          get "/exports/#{export.id}/download", **api_headers(anonymous_token)

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
