module Admin
  class AudioRecordingsController < BaseController

    # GET /admin/audio_recordings
    def index
      page = paging_params[:page].blank? ? 1 : paging_params[:page].to_i
      order_by = paging_params[:order_by].blank? ? :id : paging_params[:order_by].to_s.to_sym
      order_dir = paging_params[:order_dir].blank? ? :desc : paging_params[:order_dir].to_s.to_sym

      commit = (paging_params[:commit].blank? ? 'filter' : paging_params[:commit]).to_s

      fail 'Invalid order by.' unless [:id, :site, :duration_seconds, :recorded_date, :created_at, :audio_event_count].include?(order_by)
      fail 'Invalid order dir.' unless [:asc, :desc].include?(order_dir)

      redirect_to admin_audio_recordings_path if commit.downcase == 'clear'

      @audio_recordings_info = {
          order_by: order_by,
          order_dir: order_dir
      }

      query = AudioRecording.includes(:site).all

      # need custom queries to order by site name and audio event count

      @audio_recordings = query.order(order_by => order_dir).page(page)
    end

    # GET /admin/audio_recordings/:id
    def show
      @audio_recording = AudioRecording.find(params[:id])
    end

    private

    def paging_params
      params.permit(:page, :order_by, :order_dir)
    end

  end
end