module Admin
  class AnalysisJobsController < BaseController

    # GET /admin/analysis_jobs
    def index
      page = paging_params[:page].blank? ? 1 : paging_params[:page].to_i
      order_by = paging_params[:order_by].blank? ? :id : paging_params[:order_by].to_s.to_sym
      order_dir = paging_params[:order_dir].blank? ? :desc : paging_params[:order_dir].to_s.to_sym

      commit = (paging_params[:commit].blank? ? 'filter' : paging_params[:commit]).to_s

      fail 'Invalid order by.' unless [:id, :name, :started_at, :overall_status, :overall_status_modified_at].include?(order_by)
      fail 'Invalid order dir.' unless [:asc, :desc].include?(order_dir)

      redirect_to admin_analysis_jobs_path if commit.downcase == 'clear'

      @analysis_jobs_info = {
          order_by: order_by,
          order_dir: order_dir
      }

      query = AnalysisJob.includes(:script, :creator).all
      @analysis_jobs = query.order(order_by => order_dir).page(page)
    end

    # GET /admin/analysis_jobs/:id
    def show
      @analysis_job = AnalysisJob.find(params[:id])
    end

    private

    def paging_params
      params.permit(:page, :order_by, :order_dir)
    end

  end
end