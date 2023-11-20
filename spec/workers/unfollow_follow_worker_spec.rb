# frozen_string_literal: true

require 'rails_helper'

describe UnfollowFollowWorker do
  subject { described_class.new }

  let(:local_follower)   { Fabricate(:account) }
  let(:source_account)   { Fabricate(:account) }
  let(:target_account)   { Fabricate(:account) }
  let(:show_reblogs)     { true }
  let(:hide_from_home)   { false }

  before do
    local_follower.follow!(source_account, reblogs: show_reblogs, hide_from_home: hide_from_home)
  end

  context 'when show_reblogs is true' do
    let(:show_reblogs) { true }

    describe 'perform' do
      it 'unfollows source account and follows target account' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(local_follower.following?(source_account)).to be false
        expect(local_follower.following?(target_account)).to be true
      end

      it 'preserves show_reblogs' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(Follow.find_by(account: local_follower, target_account: target_account).show_reblogs?).to be show_reblogs
      end
    end
  end

  context 'when show_reblogs is false' do
    let(:show_reblogs) { false }

    describe 'perform' do
      it 'unfollows source account and follows target account' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(local_follower.following?(source_account)).to be false
        expect(local_follower.following?(target_account)).to be true
      end

      it 'preserves show_reblogs' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(Follow.find_by(account: local_follower, target_account: target_account).show_reblogs?).to be show_reblogs
      end
    end
  end

  context 'when hide_from_home is false' do
    let(:hide_from_home) { false }

    describe 'perform' do
      it 'unfollows source account and follows target account' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(local_follower.following?(source_account)).to be false
        expect(local_follower.following?(target_account)).to be true
      end

      it 'preserves hide_from_home' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(Follow.find_by(account: local_follower, target_account: target_account).hide_from_home?).to be hide_from_home
      end
    end
  end

  context 'when hide_from_home is true' do
    let(:hide_from_home) { true }

    describe 'perform' do
      it 'unfollows source account and follows target account' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(local_follower.following?(source_account)).to be false
        expect(local_follower.following?(target_account)).to be true
      end

      it 'preserves hide_from_home' do
        subject.perform(local_follower.id, source_account.id, target_account.id)
        expect(Follow.find_by(account: local_follower, target_account: target_account).hide_from_home?).to be hide_from_home
      end
    end
  end
end
