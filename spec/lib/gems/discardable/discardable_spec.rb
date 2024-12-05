# frozen_string_literal: true

describe Discardable do
  let(:this_application_record) do
    # rubocop:disable Rails/ApplicationRecord
    Class.new(ActiveRecord::Base) {
      self.abstract_class = true
      include Discardable
    }
  end

  let(:current_user) { create(:user) }

  before do
    Current.user = current_user

    Temping.create(:not_discardable, parent_class: this_application_record)

    Temping.create(:is_discardable, parent_class: this_application_record) do
      with_columns do |t|
        t.datetime :deleted_at
        t.integer :deleter_id
        t.string :name
      end

      acts_as_discardable

      before_discard :before_discard_callback
      before_undiscard :before_undiscard_callback

      def before_discard_callback
        self.name = "#{name || ''} discarded"
      end

      def before_undiscard_callback
        # noop
        self.name = "#{name || ''} undiscarded"
      end
    end
  end

  it 'has a discardable method on the class' do
    expect(IsDiscardable).to be_discardable
    expect(NotDiscardable).not_to be_discardable
  end

  it 'has a discardable method on the instance' do
    expect(IsDiscardable.new).to be_discardable
    expect(NotDiscardable.new).not_to be_discardable
  end

  it 'when discarded the model sets the discard column' do
    model = IsDiscardable.create!
    expect(model[IsDiscardable.discard_column]).to be_nil

    expect(model.discard).to be true

    model.reload

    expect(model[IsDiscardable.discard_column]).to be_present
    expect(model[IsDiscardable.discarder_id_column]).to eq current_user.id
  end

  it 'when undiscarded the model un-sets the discard column' do
    model = IsDiscardable.create!
    model.discard

    expect(model[IsDiscardable.discard_column]).to be_present

    model.undiscard

    model.reload

    expect(model[IsDiscardable.discard_column]).to be_nil
    expect(model[IsDiscardable.discarder_id_column]).to be_nil
  end

  it 'discarding twice does not change the discard column' do
    model = IsDiscardable.create!
    model.discard

    deleted_at = model[IsDiscardable.discard_column]
    expect(deleted_at).to be_present

    expect(model.discard).to be false

    model.reload

    expect(model[IsDiscardable.discard_column]).to be_present
    expect(model[IsDiscardable.discard_column]).to eq deleted_at
  end

  it 'undiscarding twice does not change the discard column' do
    model = IsDiscardable.create!
    model.discard

    model.undiscard

    expect(model[IsDiscardable.discard_column]).to be_nil

    expect(model.undiscard).to be false

    model.reload

    expect(model[IsDiscardable.discard_column]).to be_nil
  end

  it 'has a discard! method that raises an error if the record is not discarded' do
    model = IsDiscardable.create!
    expect(model.discard).to be true
    expect { model.discard! }.to raise_error(Discardable::RecordNotDiscarded)
  end

  it 'has a undiscard! method that raises an error if the record is not undiscarded' do
    model = IsDiscardable.create!
    expect { model.undiscard! }.to raise_error(Discardable::RecordNotUndiscarded)
  end

  it 'has a discarded and undiscarded predicate' do
    model = IsDiscardable.create!
    expect(model).not_to be_discarded
    expect(model).to be_undiscarded

    model.discard

    expect(model).to be_discarded
    expect(model).not_to be_undiscarded
  end

  context 'with scopes' do
    let(:a) { IsDiscardable.create!.tap(&:discard) }
    let(:b) { IsDiscardable.create! }

    it 'has a discarded scope' do
      expect(IsDiscardable.discarded).to eq([a])
    end

    it 'has a undiscarded scope' do
      expect(IsDiscardable.undiscarded).to eq([b])
    end

    it 'has a kept scope' do
      expect(IsDiscardable.kept).to eq([b])
    end

    it 'has a with_discarded scope' do
      expect(IsDiscardable.with_discarded).to eq([a, b])
      # it's an unscope call so it should undo previous scopes
      expect(IsDiscardable.kept.with_discarded).to eq([a, b])
    end

    it 'has a default kept scope for compatibility' do
      expect(IsDiscardable.all).to eq([b])
      expect(IsDiscardable.count).to eq(1)
    end
  end

  context 'with callbacks' do
    let(:model) { IsDiscardable.create! }

    it 'runs the discard callback' do
      allow(model).to receive(:before_discard_callback).and_call_original
      model.discard
      expect(model).to have_received(:before_discard_callback)
    end

    it 'runs the undiscard callback' do
      model.discard
      allow(model).to receive(:before_undiscard_callback).and_call_original
      model.undiscard
      expect(model).to have_received(:before_undiscard_callback)
    end

    it 'runs the discard! callback' do
      allow(model).to receive(:before_discard_callback).and_call_original
      model.discard!
      expect(model).to have_received(:before_discard_callback)
    end

    it 'runs the undiscard! callback' do
      model.discard
      allow(model).to receive(:before_undiscard_callback).and_call_original
      model.undiscard!
      expect(model).to have_received(:before_undiscard_callback)
    end

    it 'does not run the discard callback if the discard! callback is aborted' do
      allow(model).to receive(:before_discard_callback).and_throw(:abort)
      expect { model.discard! }.to raise_error(Discardable::RecordNotDiscarded)
    end

    it 'does not run the undiscard callback if the undiscard! callback is aborted' do
      model.discard
      allow(model).to receive(:before_undiscard_callback).and_throw(:abort)
      expect { model.undiscard! }.to raise_error(Discardable::RecordNotUndiscarded)
    end
  end

  context 'when using batch methods' do
    let!(:a) { IsDiscardable.create!(name: 'a') }
    let!(:b) { IsDiscardable.create!(name: 'b', deleted_at: Time.zone.now, deleter_id: current_user.id) }
    let!(:c) { IsDiscardable.create!(name: 'c') }
    let!(:d) { IsDiscardable.create!(name: 'd', deleted_at: Time.zone.now, deleter_id: current_user.id) }

    describe 'iterative batch methods' do
      def assert_callback_called(suffix, *models)
        models.each do |model|
          first_name = model.name
          model.reload
          expect(model.name).to eq("#{first_name} #{suffix}")
        end
      end

      def assert_callbacks_not_called(suffix, *models)
        models.each do |model|
          first_name = model.name
          model.reload
          expect(model.name).not_to eq("#{first_name} #{suffix}")
        end
      end

      it 'has a discard_each! method' do
        # callbacks are run and only on undiscarded records

        expect { IsDiscardable.discard_each! }.to(
             change { IsDiscardable.discarded.count }.from(2).to(4)
           )

        assert_callback_called('discarded', a, c)
        assert_callbacks_not_called('discarded', b, d)
      end

      it 'has a undiscard_each! method' do
        # callbacks are run and only on discarded records

        expect { IsDiscardable.undiscard_each! }.to(
            change { IsDiscardable.undiscarded.count }.from(2).to(4)
          )

        assert_callback_called('undiscarded', b, d)
        assert_callbacks_not_called('undiscarded', a, c)
      end

      it 'has a discard_each method' do
        # callbacks are run and only on undiscarded records

        expect { IsDiscardable.discard_each }.to(
            change { IsDiscardable.discarded.count }.from(2).to(4)
          )

        assert_callback_called('discarded', a, c)
        assert_callbacks_not_called('discarded', b, d)
      end

      it 'has a undiscard_each method' do
        # callbacks are run and only on discarded records

        expect { IsDiscardable.undiscard_each }.to(
            change { IsDiscardable.undiscarded.count }.from(2).to(4)
          )

        assert_callback_called('undiscarded', b, d)
        assert_callbacks_not_called('undiscarded', a, c)
      end
    end

    describe 'one statement batch methods' do
      def assert_callbacks_not_called
        allow(a).to receive(:before_discard_callback)
        allow(b).to receive(:before_discard_callback)
        allow(c).to receive(:before_discard_callback)
        allow(d).to receive(:before_discard_callback)

        yield

        expect(a).not_to have_received(:before_discard_callback)
        expect(b).not_to have_received(:before_discard_callback)
        expect(c).not_to have_received(:before_discard_callback)
        expect(d).not_to have_received(:before_discard_callback)
      end

      it 'has a discard_all method' do
        assert_callbacks_not_called do
          expect { IsDiscardable.discard_all }.to(
              change { IsDiscardable.discarded.count }.from(2).to(4)
            )
        end

        expect(a.reload.deleter_id).to eq(current_user.id)
        expect(c.reload.deleter_id).to eq(current_user.id)
      end

      it 'has a undiscard_all method' do
        assert_callbacks_not_called do
          expect { IsDiscardable.undiscard_all }.to(
              change { IsDiscardable.undiscarded.count }.from(2).to(4)
            )
        end

        expect(b.reload.deleter_id).to be_nil
        expect(d.reload.deleter_id).to be_nil
      end

      it 'sees the batch methods are available directly from the class' do
        expect(IsDiscardable.count).to eq(2)

        IsDiscardable.discard_all

        expect(IsDiscardable.discarded.count).to eq(4)

        IsDiscardable.undiscard_all

        expect(IsDiscardable.undiscarded.count).to eq(4)
      end

      it 'raises an error if the relation is not discardable' do
        expect { NotDiscardable.all.discard_all }.to raise_error(Discardable::NotDiscardableError)
        expect { NotDiscardable.all.undiscard_all }.to raise_error(Discardable::NotDiscardableError)
      end

      it 'maintains other scopes and criteria but overwrites any discardable scopes' do
        expect {
          IsDiscardable.where(id: a.id).kept.discarded.discard_all
        }.to change { IsDiscardable.discarded.count }.from(2).to(3)
      end
    end
  end
end
