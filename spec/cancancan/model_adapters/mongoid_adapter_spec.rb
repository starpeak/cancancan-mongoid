require 'spec_helper'

RSpec.describe CanCan::ModelAdapters::MongoidAdapter do
  context 'Mongoid defined' do
    before(:each) do
      (@ability = double).extend(CanCan::Ability)
    end

    after(:each) do
      if Mongoid::VERSION >= '5.0'
        Mongoid.default_client.collections.reject do |collection|
          collection.name =~ /system/
        end.each(&:drop)
      else
        Mongoid.default_session.drop
      end
    end

    it 'is for only Mongoid classes' do
      expect(CanCan::ModelAdapters::MongoidAdapter).not_to be_for_class(Object)
      expect(CanCan::ModelAdapters::MongoidAdapter).to be_for_class(MongoidProject)
      expect(CanCan::ModelAdapters::AbstractAdapter.adapter_class(MongoidProject))
        .to eq(CanCan::ModelAdapters::MongoidAdapter)
    end

    it 'finds record' do
      project = MongoidProject.create
      expect(CanCan::ModelAdapters::MongoidAdapter.find(MongoidProject, project.id)).to eq(project)
    end

    it 'compares properties on mongoid documents with the conditions hash' do
      model = MongoidProject.new
      @ability.can :read, MongoidProject, id: model.id
      expect(@ability).to be_able_to(:read, model)
    end

    it 'is able to read hashes when field is array' do
      one_to_three = MongoidProject.create(numbers: %w[one two three])
      two_to_five = MongoidProject.create(numbers: %w[two three four five])

      @ability.can :foo, MongoidProject, numbers: 'one'
      expect(@ability).to be_able_to(:foo, one_to_three)
      expect(@ability).not_to be_able_to(:foo, two_to_five)
    end

    it 'returns [] when no ability is defined so no records are found' do
      MongoidProject.create(title: 'Sir')
      MongoidProject.create(title: 'Lord')
      MongoidProject.create(title: 'Dude')

      expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([])
    end

    context 'when records based on the defined ability' do
      let!(:sir) { MongoidProject.create(title: 'Sir') }

      before do
        @ability.can :read, MongoidProject, title: 'Sir'
        MongoidProject.create(title: 'Lord')
        MongoidProject.create(title: 'Dude')
      end

      it 'returns the correct records' do
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([sir])
      end

      context 'when model has scope' do
        it 'returns empty array' do
          expect(MongoidProject.where(title: 'Lord').accessible_by(@ability, :read).to_a).to eq([])
        end
      end
    end

    it 'returns the correct records when a mix of can and cannot rules in defined ability' do
      @ability.can :manage, MongoidProject, title: 'Sir'
      @ability.cannot :destroy, MongoidProject

      sir = MongoidProject.create(title: 'Sir')
      MongoidProject.create(title: 'Lord')
      MongoidProject.create(title: 'Dude')

      expect(MongoidProject.accessible_by(@ability, :destroy).to_a).to eq([sir])
    end

    it 'is able to mix empty conditions and hashes' do
      @ability.can :read, MongoidProject
      @ability.can :read, MongoidProject, title: 'Sir'
      MongoidProject.create(title: 'Sir')
      MongoidProject.create(title: 'Lord')

      expect(MongoidProject.accessible_by(@ability, :read).count).to eq(2)
    end

    it 'returns everything when the defined ability is access all' do
      @ability.can :manage, :all
      sir = MongoidProject.create(title: 'Sir')
      lord = MongoidProject.create(title: 'Lord')
      dude = MongoidProject.create(title: 'Dude')

      expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([sir, lord, dude])
    end

    it 'allows a scope for conditions' do
      @ability.can :read, MongoidProject, MongoidProject.where(title: 'Sir')
      sir = MongoidProject.create(title: 'Sir')
      MongoidProject.create(title: 'Lord')
      MongoidProject.create(title: 'Dude')

      expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([sir])
    end

    describe 'Mongoid::Criteria where clause Symbol extensions using MongoDB expressions' do
      it 'handles :field.in' do
        obj = MongoidProject.create(title: 'Sir')
        @ability.can :read, MongoidProject, :title.in => %w[Sir Madam]
        expect(@ability.can?(:read, obj)).to eq(true)
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])

        obj2 = MongoidProject.create(title: 'Lord')
        expect(@ability.can?(:read, obj2)).to be(false)
      end

      describe 'activates only when there are Criteria in the hash' do
        it 'Calls where on the model class when there are criteria' do
          obj = MongoidProject.create(title: 'Bird')
          @conditions = { :title.nin => %w[Fork Spoon] }

          @ability.can :read, MongoidProject, @conditions
          expect(@ability).to be_able_to(:read, obj)
        end
        it 'Calls the base version if there are no mongoid criteria' do
          obj = MongoidProject.new(title: 'Bird')
          @conditions = { id: obj.id }
          @ability.can :read, MongoidProject, @conditions
          expect(@ability).to be_able_to(:read, obj)
        end
      end

      it 'handles :field.nin' do
        obj = MongoidProject.create(title: 'Sir')
        @ability.can :read, MongoidProject, :title.nin => %w[Lord Madam]
        expect(@ability.can?(:read, obj)).to eq(true)
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])

        obj2 = MongoidProject.create(title: 'Lord')
        expect(@ability.can?(:read, obj2)).to be(false)
      end

      it 'handles :field.count' do
        obj = MongoidProject.create(titles: %w[Palatin Margrave])
        @ability.can :read, MongoidProject, titles: { :$size => 2 }
        expect(@ability.can?(:read, obj)).to eq(true)
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])

        obj2 = MongoidProject.create(titles: %w[Palatin Margrave Marquis])
        expect(@ability.can?(:read, obj2)).to be(false)
      end

      it 'handles :field.exists' do
        obj = MongoidProject.create(titles: %w[Palatin Margrave])
        @ability.can :read, MongoidProject, :titles.exists => true
        expect(@ability.can?(:read, obj)).to eq(true)
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])

        obj2 = MongoidProject.create
        expect(@ability.can?(:read, obj2)).to be(false)
      end

      it 'handles :field.gt' do
        obj = MongoidProject.create(age: 50)
        @ability.can :read, MongoidProject, :age.gt => 45
        expect(@ability.can?(:read, obj)).to eq(true)
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])

        obj2 = MongoidProject.create(age: 40)
        expect(@ability.can?(:read, obj2)).to be(false)
      end

      it 'handles instance not saved to database' do
        obj = MongoidProject.new(title: 'Sir')
        @ability.can :read, MongoidProject, :title.in => %w[Sir Madam]
        expect(@ability.can?(:read, obj)).to eq(true)

        # accessible_by only returns saved records
        expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([])

        obj2 = MongoidProject.new(title: 'Lord')
        expect(@ability.can?(:read, obj2)).to be(false)
      end
    end

    it 'calls where with matching ability conditions' do
      obj = MongoidProject.create(foo: { bar: 1 })
      @ability.can :read, MongoidProject, foo: { bar: 1 }
      expect(MongoidProject.accessible_by(@ability, :read).to_a.first).to eq(obj)
    end

    it 'excludes from the result if set to cannot' do
      obj = MongoidProject.create(bar: 1)
      MongoidProject.create(bar: 2)
      @ability.can :read, MongoidProject
      @ability.cannot :read, MongoidProject, bar: 2
      expect(MongoidProject.accessible_by(@ability, :read).to_a).to eq([obj])
    end

    it 'combines the rules' do
      obj = MongoidProject.create(bar: 1)
      obj2 = MongoidProject.create(bar: 2)
      MongoidProject.create(bar: 3)
      @ability.can :read, MongoidProject, bar: 1
      @ability.can :read, MongoidProject, bar: 2
      expect(MongoidProject.accessible_by(@ability, :read).to_a).to match_array([obj, obj2])
    end

    it 'does not allow to fetch records when ability with just block present' do
      @ability.can :read, MongoidProject do
        false
      end
      expect do
        MongoidProject.accessible_by(@ability)
      end.to raise_error(CanCan::Error)
    end

    it 'can handle nested associated queries for accessible_by' do
      @ability.can :read, MongoidSubProject, mongoid_project: { mongoid_category: { name: 'allowed' } }
      cat1 = MongoidCategory.create name: 'notallowed'
      proj1 = cat1.mongoid_projects.create name: 'Proj1'
      proj1.mongoid_sub_projects.create name: 'Sub1'
      cat2 = MongoidCategory.create name: 'allowed'
      proj2 = cat2.mongoid_projects.create name: 'Proj2'
      sub2 = proj2.mongoid_sub_projects.create name: 'Sub2'
      expect(MongoidSubProject.accessible_by(@ability).to_a).to match_array([sub2])
    end

    it 'can handle nested embedded queries for accessible_by' do
      @ability.can :read, MongoidPost, "mongoid_comments" => { name: 'allowed' }
      post1 = MongoidPost.create
      proj1 = post1.mongoid_comments.create name: 'notallowed'
      post2 = MongoidPost.create
      proj2 = post2.mongoid_comments.create name: 'allowed'
      expect(MongoidPost.accessible_by(@ability).to_a).to match_array([post2])
    end

    it 'can handle nested embedded queries for accessible_by with class_name' do
      @ability.can :read, MongoidPost, "tags" => { name: 'allowed' }
      post1 = MongoidPost.create
      proj1 = post1.tags.create name: 'notallowed'
      post2 = MongoidPost.create
      proj2 = post2.tags.create name: 'allowed'
      expect(MongoidPost.accessible_by(@ability).to_a).to match_array([post2])
    end

    it 'can handle nested embedded queries for accessible_by with array values' do
      @ability.can :read, MongoidPost, "mongoid_comments" => { :name.in => ['allowed', 'public'] }
      post1 = MongoidPost.create
      proj1 = post1.mongoid_comments.create name: 'notallowed'
      post2 = MongoidPost.create
      proj2 = post2.mongoid_comments.create name: 'allowed'
      expect(MongoidPost.accessible_by(@ability).to_a).to match_array([post2])
    end

    it 'can handle nested embedded queries for accessible_by with class_name' do
      @ability.can :read, MongoidPost, "tags" => { key: 'public', :name.in => ['allowed', 'yes'] }
      post1 = MongoidPost.create
      proj1 = post1.tags.create key: 'private', name: 'allowed'
      post2 = MongoidPost.create
      proj2 = post2.tags.create key: 'public', name: 'allowed'
      post3 = MongoidPost.create
      proj3 = post2.tags.create key: 'public', name: 'notallowed'

      expect(MongoidPost.accessible_by(@ability).to_a).to match_array([post2])
    end

  end
end
