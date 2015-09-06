module Admin
  class TagsController < BaseController

    # GET /admin/tags(.:format)
    def index
      page = paging_params[:page].blank? ? 1 : paging_params[:page].to_i
      order_by = paging_params[:order_by].blank? ? :text : paging_params[:order_by].to_s.to_sym
      order_dir = paging_params[:order_dir].blank? ? :asc : paging_params[:order_dir].to_s.to_sym

      commit = (paging_params[:commit].blank? ? 'filter' : paging_params[:commit]).to_s

      filter = paging_params[:filter]

      fail 'Invalid order by.' unless [:text, :is_taxanomic, :type_of_tag, :retired, :updated_at, :updater_id].include?(order_by)
      fail 'Invalid order dir.' unless [:asc, :desc].include?(order_dir)

      redirect_to admin_tags_path if commit.downcase == 'clear'

      @tags_info = {
          order_by: order_by,
          order_dir: order_dir,
          filter: filter
      }

      query = Tag.includes(:updater).references(:users).all

      unless filter.blank?
        sanitized_value = filter.to_s.gsub(/[\\_%\|]/) { |x| "\\#{x}" }
        contains_value = "%#{sanitized_value}%"

        tag_table = Tag.arel_table
        text = tag_table[:text].matches(contains_value)
        type_of_tag = tag_table[:type_of_tag].matches(contains_value)
        notes = tag_table[:notes].matches(contains_value)
        user_name = User.arel_table[:user_name].matches(contains_value)

        query = query.where(text.or(type_of_tag).or(notes).or(user_name))
      end

      @tags = query.order(order_by => order_dir, :text => :asc).page(page)
    end

    # GEt /admin/tags/:id
    def show
      @tag = Tag.find(params[:id])
      redirect_to edit_admin_tag_path(@tag), notice: 'Redirected to edit tag.'
    end

    # GET /admin/tags/new
    def new
      @tag = Tag.new
    end

    # GET /admin/tags/:id/edit
    def edit
      @tag = Tag.find(params[:id])
    end

    # POST /admin/tags
    def create
      @tag = Tag.new(tag_params)

      respond_to do |format|
        if @tag.save
          format.html { redirect_to edit_admin_tag_path(@tag), notice: 'Tag was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    # PATCH|PUT /admin/tags/:id
    def update
      @tag = Tag.find(params[:id])

      respond_to do |format|
        if @tag.update(tag_params)
          format.html { redirect_to edit_admin_tag_path(@tag), notice: 'Tag was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    # DELETE /admin/tags/:id
    def destroy
      @tag = Tag.find(params[:id])

      @tag.destroy
      respond_to do |format|
        format.html { redirect_to admin_tags_path, notice: 'Tag was successfully destroyed.' }
      end
    end

    private

    def tag_params
      params.require(:tag).permit(:id, :text, :is_taxanomic, :type_of_tag, :retired, :notes)
    end

    def paging_params
      params.permit(:page, :order_by, :order_dir, :filter, :commit)
    end

  end
end