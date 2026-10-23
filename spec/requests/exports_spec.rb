# frozen_string_literal: true

describe 'Exports' do
  create_entire_hierarchy

  it 'can show an export' do
    export = create(:export, creator: owner_user)

    get "/exports/#{export.id}", params: nil, **api_headers(owner_token)

    expect(response).to have_http_status(:ok)
  end

  describe 'listing' do
    let!(:own_export) { create(:export, creator: owner_user, project:) }
    let!(:other_export) { create(:export, creator: writer_user, project:) }

    it 'index returns only the exports created by the current user' do
      get '/exports', params: nil, **api_headers(owner_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(own_export)
      expect_does_not_have_ids(other_export)
    end

    it 'filter returns only the exports created by the current user' do
      get '/exports/filter', params: nil, **api_headers(owner_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(own_export)
      expect_does_not_have_ids(other_export)
    end

    it 'filter with a body returns the matching export created by the current user' do
      body = { filter: { name: { eq: own_export.name } } }

      post '/exports/filter', params: body, **api_with_body_headers(owner_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(own_export)
    end

    it 'index returns every export to an admin' do
      get '/exports', params: nil, **api_headers(admin_token)

      expect(response).to have_http_status(:ok)
      expect_has_ids(own_export, other_export)
    end

    it 'index returns an empty list when not logged in' do
      get '/exports', params: nil, **api_headers(anonymous_token)

      expect(response).to have_http_status(:ok)
      expect_zero_items
    end

    it 'show responds with forbidden for an export created by a different user' do
      get "/exports/#{other_export.id}", params: nil, **api_headers(owner_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'destroy' do
    it 'deletes an export created by the current user' do
      export = create(:export, creator: owner_user, project:, status: 'ready')

      delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)

      expect_no_content
      expect(Export.exists?(export.id)).to be false
    end

    it 'deletes the attached file together with the export' do
      export = create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready')

      expect {
        delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)
      }.to change(ActiveStorage::Attachment, :count).by(-1)

      expect_no_content
      expect(Export.exists?(export.id)).to be false

      clear_pending_jobs
    end

    ['queued', 'working'].each do |status|
      it "responds with conflict and keeps the export when its status is #{status}" do
        export = create(:export, creator: owner_user, project:, status:)

        delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)

        expect_error(:conflict, "Cannot be deleted while `status` is `#{status}`")
        expect(Export.exists?(export.id)).to be true
      end
    end

    it 'responds with forbidden and keeps an export created by a different user' do
      export = create(:export, creator: writer_user, project:, status: 'ready')

      delete "/exports/#{export.id}", params: nil, **api_headers(owner_token)

      expect(response).to have_http_status(:forbidden)
      expect(Export.exists?(export.id)).to be true
    end
  end

  describe 'data package' do
    pause_all_jobs

    let(:params) do
      { export_type: 'camtrap_dp', name: 'Test Export', filter: {}, project_id: project.id }
    end

    it 'can request a data package export' do
      post '/exports', params: params, **api_with_body_headers(owner_token)

      expect(response).to have_http_status(:created)
      export = Export.find(api_data[:id])
      expect(api_data).to include(
        {
          id: export.id,
          status: 'queued',
          project_id: project.id,
          export_type: 'camtrap_dp',
          creator_id: owner_user.id,
          name: 'Test Export',
          filter: {},
          options: nil,
          token: be_a(String),
          exchange_url: "http://web:3000/exports/#{export.id}/download?token=#{api_data[:token]}",
          expires_at: export.expires_at
          # estimated_ready_at:
        }
      )
      clear_pending_jobs
    end

    describe 'download' do
      let(:export_attributes) { { status: 'ready' } }
      let(:export) do
        create(:export, :with_zip_file, creator: owner_user, project:, **export_attributes)
      end
      let(:token) { export.signed_id(purpose: :export_download) }
      let(:download_path) { "/exports/#{export.id}/download" }

      context 'when the export is ready' do
        it 'returns the export file when a valid token is given' do
          get download_path, params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq 'application/zip'
          expect(response).to be_same_file_as(Fixtures.zip_fixture)
        end

        it 'increases the download count by one when a valid token is given' do
          expect {
            get download_path, params: { token: }, **api_headers(anonymous_token)
          }.to change { export.reload.download_count }.from(0).to(1)
        end

        it 'rejects a token that was not signed for the export download purpose' do
          bad_token = export.signed_id(purpose: :something_else)

          get download_path, params: { token: bad_token }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:not_found)
          expect(export.reload.download_count).to eq 0
        end

        it 'rejects a token that was signed for a different export' do
          other_export = create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready')
          other_token = other_export.signed_id(purpose: :export_download)

          get download_path, params: { token: other_token }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:not_found)
          expect(export.reload.download_count).to eq 0
        end
      end

      ['pending', 'queued', 'working'].each do |status|
        context "when the export is #{status}" do
          let(:export_attributes) { { status: } }

          it 'responds with service unavailable when a valid token is given' do
            get download_path, params: { token: }, **api_headers(anonymous_token)

            expect(response).to have_http_status(:service_unavailable)
          end
        end
      end

      context 'when the export has failed' do
        let(:export_attributes) { { status: 'failed', error: 'The export could not be generated' } }

        it 'responds with unprocessable entity when a valid token is given' do
          get download_path, params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when the export has expired' do
        let(:export_attributes) { { status: 'ready', expires_at: 1.day.ago } }

        it 'responds with gone when a valid token is given' do
          get download_path, params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:gone)
          expect(export.reload.download_count).to eq 0
        end
      end

      context 'when the export file was purged' do
        before { export.purge! }

        it 'responds with gone when a valid token is given' do
          get download_path, params: { token: }, **api_headers(anonymous_token)

          expect(response).to have_http_status(:gone)
        end
      end

      context 'without a token' do
        it 'returns the export file to the user who created the export' do
          get download_path, **api_headers(owner_token)

          expect(response).to have_http_status(:ok)
          expect(response).to be_same_file_as(Fixtures.zip_fixture)
        end

        it 'responds with forbidden to a different logged-in user' do
          get download_path, **api_headers(writer_token)

          expect(response).to have_http_status(:forbidden)
        end

        it 'responds with unauthorized when not logged in' do
          get download_path, **api_headers(anonymous_token)

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
