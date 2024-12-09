# frozen_string_literal: true

# # frozen_string_literal: true

#
# NOTE: automatic recursive discarding is *hard*
#       I don't actually need it now, so I'll deal with it later
#       I'm thinking perhaps a declarative way to specify the relationships
#       that should be discarded will vastly simplify the logic but also
#       make it more flexible: i.e. slow and honors callbacks or fast and
#       doesn't honor callbacks.
#
#
describe Discardable do
  before do
    current_user = create(:user)
    Current.user = current_user

    Temping.create(:post) do
      with_columns do |t|
        t.datetime :deleted_at
        t.integer :deleter_id
        t.references :author
      end

      belongs_to :author
      has_many :comments
      has_many :reactions
      has_many :reaction_clicks, through: :reactions
      has_many :posts_labels
      has_and_belongs_to_many :labels, though: :posts_labels, join_table: :posts_labels

      acts_as_discardable
    end

    Temping.create(:comment) do
      with_columns do |t|
        t.references :post
        t.references :author
        t.datetime :deleted_at
        t.integer :deleter_id
      end

      acts_as_discardable

      belongs_to :post
      belongs_to :author
    end

    Temping.create(:reactions) do
      # not discardable
      with_columns do |t|
        t.references :post
      end

      belongs_to :post
      has_many :reaction_clicks
    end

    Temping.create(:reaction_clicks) do
      with_columns do |t|
        t.references :reaction
        t.datetime :deleted_at
        t.integer :deleter_id
      end

      acts_as_discardable

      belongs_to :reaction
    end

    Temping.create(:author) do
      with_columns do |t|
        t.datetime :deleted_at
        t.integer :deleter_id
      end

      acts_as_discardable
    end

    Temping.create(:label) do
      with_columns do |t|
        t.datetime :deleted_at
        t.integer :deleter_id
      end

      acts_as_discardable

      has_and_belongs_to_many :posts, though: :posts_labels, join_table: :posts_labels
    end

    Temping.create(:posts_labels) do
      with_columns do |t|
        t.references :post
        t.references :label
        t.datetime :deleted_at
        t.integer :deleter_id
      end

      acts_as_discardable

      belongs_to :label
      belongs_to :post
    end

    # declaring down here because there are circular dependencies with the
    # defined constants for the test setup
    Post.class_eval do
      also_discards :comments
      # skip a link in the chain
      also_discards :reaction_clicks
      also_discards :posts_labels, batch: true
    end

    PostsLabel.class_eval do
      also_discards :label
    end

    # now lets seed some data
    author = Author.create!
    post = Post.create!(author:)
    label1 = Label.create!
    label2 = Label.create!
    post.labels << label1
    post.labels << label2
    Comment.create!(post:, author:)
    Comment.create!(post:, author:)
    reaction = Reaction.create!(post:)
    ReactionClick.create!(reaction:)
    ReactionClick.create!(reaction:)
  end

  it 'asserts the basic setup' do
    expect(Post.count).to eq(1)
    expect(Comment.count).to eq(2)
    expect(Reaction.count).to eq(1)
    expect(ReactionClick.count).to eq(2)
    expect(Author.count).to eq(1)
    expect(Label.count).to eq(2)
    expect(PostsLabel.count).to eq(2)
  end

  stepwise 'when discarding a record' do
    step 'setup' do
      Post.first.discard!
    end

    step 'discards the record' do
      expect(Post.discarded.count).to eq(1)
    end

    step 'does not discard belongs_to records' do
      expect(Author.discarded.count).to eq(0)
    end

    step 'does discard has_many records' do
      expect(Comment.discarded.count).to eq(2)
    end

    step 'is a no-op for non-discardable records' do
      expect(Reaction.count).to eq(1)
    end

    step 'can travel through has_many records' do
      expect(ReactionClick.discarded.count).to eq(2)
    end

    step 'discards the joins of many to many records' do
      expect(PostsLabel.discarded.count).to eq(2)
    end

    step 'can discard the other side of the many to many records if asked to' do
      expect(Label.discarded.count).to eq(2)
    end
  end

  stepwise 'when undiscarding a record' do
    step 'setup' do
      post = Post.first
      post.discard!
      post.reload
      post.undiscard!
    end

    step 'undiscards the record' do
      expect(Post.discarded.count).to eq(0)
    end

    step 'does not undiscard belongs_to records' do
      expect(Author.discarded.count).to eq(0)
    end

    step 'does undiscard has_many records' do
      expect(Comment.discarded.count).to eq(0)
    end

    step 'is a no-op for non-discardable records' do
      expect(Reaction.count).to eq(1)
    end

    step 'can travel through has_many records' do
      expect(ReactionClick.discarded.count).to eq(0)
    end

    step 'undiscards the joins of many to many records' do
      expect(PostsLabel.discarded.count).to eq(0)
    end

    step 'does not undiscard the other side of the many to many records' do
      expect(Label.discarded.count).to eq(0)
    end
  end
end
