require 'spec_helper'
require 'support/active_record'

describe Repository do
  include Support::ActiveRecord

  describe 'validates' do
    it 'uniqueness of :owner_name/:name' do
      existing = Factory(:repository)
      repository = Repository.new(existing.attributes)
      repository.should_not be_valid
      repository.errors['name'].should == ['has already been taken']
    end
  end

  describe 'class methods' do
    describe 'find_by' do
      let(:minimal) { Factory(:repository) }

      it "should find a repository by it's id" do
        Repository.find_by(:id => minimal.id).id.should == minimal.id
      end

      it "should find a repository by it's name and owner_name" do
        repository = Repository.find_by(:name => minimal.name, :owner_name => minimal.owner_name)
        repository.owner_name.should == minimal.owner_name
        repository.name.should == minimal.name
      end
    end

    describe 'timeline' do
      it 'sorts the most repository with the most recent build to the top' do
        repository_1 = Factory(:repository, :name => 'repository_1', :last_build_started_at => '2011-11-11')
        repository_2 = Factory(:repository, :name => 'repository_2', :last_build_started_at => '2011-11-12')

        repositories = Repository.timeline.all
        repositories.first.id.should == repository_2.id
        repositories.last.id.should == repository_1.id
      end
    end

    describe 'search' do
      before(:each) do
        Factory(:repository, :name => 'repository_1', :last_build_started_at => '2011-11-11')
        Factory(:repository, :name => 'repository_2', :last_build_started_at => '2011-11-12')
      end

      it 'performs searches case-insensitive' do
        Repository.search('ePoS').count.should == 2
      end

      it 'performs searches with / entered' do
        Repository.search('fuchs/').count.should == 2
      end

      it 'performs searches with \ entered' do
        Repository.search('fuchs\\').count.should == 2
      end
    end
  end

  it "last_build returns the most recent build" do
    repository = Factory(:repository)
    attributes = { :repository => repository, :state => 'finished' }
    Factory(:build, attributes)
    Factory(:build, attributes)
    build = Factory(:build, attributes)

    repository.last_build.id.should == build.id
  end

  describe 'last_build_status' do
    let(:build)      { Factory(:build, :state => 'finished', :config => { 'rvm' => ['1.8.7', '1.9.2'], 'env' => ['DB=sqlite3', 'DB=postgresql'] }) }
    let(:repository) { build.repository }

    it 'returns the last_build_status attribute if no params have been passed' do
      repository.update_attributes(:last_build_status => 0)
      repository.reload.last_build_status.should == 0
    end

    it 'returns 0 (passing) if all specified builds are passing' do
      build.matrix.each { |job| job.update_attribute(:status, job.config[:rvm] == '1.8.7' ? 0 : 1) }
      repository.last_build_status('rvm' => '1.8.7').should == 0
    end

    it 'returns 1 (failing) if at least one specified build is failing' do
      build.matrix.each_with_index { |build, ix| build.update_attribute(:status, ix == 0 ? 1 : 0) }
      repository.last_build_status('rvm' => '1.8.7').should == 1
    end
  end

  describe "keys" do
    let(:repository) { Factory(:repository) }

    it "should return the public key" do
      repository.public_key.should eql(repository.key.public_key)
    end

    it "should create a new key" do
      SslKey.delete_all
      lambda do
        repository.key
      end.should change(SslKey, :count).by(1)
    end

    it "should retrieve the existing key" do
      key = repository.key
      repository.reload # reload so the @key is reseted
      lambda do
        repository.key.id.should eql(key.id)
      end.should change(SslKey, :count).by(0)
    end
  end

  describe 'branches' do
    let(:repository) { Factory(:repository) }

    it 'retrieves branches only from last 25 builds' do
      old_build = Factory(:build, :repository => repository, :commit => Factory(:commit, :branch => 'old-branch'))
      24.times { Factory(:build, :repository => repository) }
      Factory(:build, :repository => repository, :commit => Factory(:commit, :branch => 'production'))
      repository.branches.size.should eql 2
      repository.branches.should include("master")
      repository.branches.should include("production")
      repository.branches.should_not include("old-branch")
    end

    it 'is empty for empty repository' do
      repository.branches.should eql []
    end
  end

  describe 'last_finished_builds_by_branches' do
    let(:repository) { Factory(:repository) }

    it 'retrieves last builds on all branches' do
      old_build = Factory(:build, :repository => repository, :state => 'finished', :commit => Factory(:commit, :branch => 'master'))
      production_build = Factory(:build, :repository => repository, :state => 'finished', :commit => Factory(:commit, :branch => 'production'))
      master_build = Factory(:build, :repository => repository, :state => 'finished', :commit => Factory(:commit, :branch => 'master'))
      builds = repository.last_finished_builds_by_branches

      builds.size.should == 2
      builds.should include(master_build)
      builds.should include(production_build)
    end
  end

end
