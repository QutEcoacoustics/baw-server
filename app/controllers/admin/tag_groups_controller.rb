module Admin
  class TagGroupsController < BaseController

    # GET /admin/tag_groups
    def index
      page = paging_params[:page].blank? ? 1 : paging_params[:page].to_i
      order_by = paging_params[:order_by].blank? ? :group_identifier : paging_params[:order_by].to_s.to_sym
      order_dir = paging_params[:order_dir].blank? ? :asc : paging_params[:order_dir].to_s.to_sym

      commit = (paging_params[:commit].blank? ? 'filter' : paging_params[:commit]).to_s

      filter = paging_params[:filter]

      fail 'Invalid order by.' unless [:tag_id, :group_identifier].include?(order_by)
      fail 'Invalid order dir.' unless [:asc, :desc].include?(order_dir)

      redirect_to admin_tag_groups_path if commit.downcase == 'clear'

      @tag_groups_info = {
          order_by: order_by,
          order_dir: order_dir,
          filter: filter
      }

      query = TagGroup.includes(:creator, :tag).references(:users).all

      unless filter.blank?
        sanitized_value = filter.to_s.gsub(/[\\_%\|]/) { |x| "\\#{x}" }
        contains_value = "%#{sanitized_value}%"

        tag_table = Tag.arel_table
        text = tag_table[:text].matches(contains_value)

        user_name = User.arel_table[:user_name].matches(contains_value)
        group_name = TagGroup.arel_table[:group_identifier].matches(contains_value)

        query = query.where(text.or(group_name).or(user_name))
      end

      @tag_groups_info[:collection] = query.order(order_by => order_dir).page(page)
    end

    # GEt /admin/tag_groups/:id
    def show
      @tag_group = TagGroup.find(params[:id])
      redirect_to edit_admin_tag_group_path(@tag_group), notice: 'Redirected to edit tag group.'
    end

    # GET /admin/tag_groups/new
    def new
      @tag_group = TagGroup.new
    end

    # GET /admin/tag_groups/:id/edit
    def edit
      @tag_group = TagGroup.find(params[:id])
    end

    # POST /admin/tag_groups
    def create
      @tag_group = TagGroup.new(tag_group_params)

      respond_to do |format|
        if @tag_group.save
          format.html { redirect_to edit_admin_tag_group_path(@tag_group), notice: 'Tag group was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    # PATCH|PUT /admin/tag_groups/:id
    def update
      @tag_group = TagGroup.find(params[:id])

      respond_to do |format|
        if @tag_group.update(tag_group_params)
          format.html { redirect_to edit_admin_tag_group_path(@tag_group), notice: 'Tag group was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    # DELETE /admin/tags/:id
    def destroy
      @tag_group = TagGroup.find(params[:id])

      @tag_group.destroy
      respond_to do |format|
        format.html { redirect_to admin_tag_groups_path, notice: 'Tag was successfully destroyed.' }
      end
    end

    private

    def tag_group_params
      values = params.require(:tag_group).permit(:id, :tag, :group_identifier)
      tag = Tag.where(text: values[:tag], id: params[:tag_group_tag_hidden]).first
      {tag: tag, group_identifier: values[:group_identifier]}
    end

    def paging_params
      params.permit(:page, :order_by, :order_dir, :filter, :commit)
    end

  end
end