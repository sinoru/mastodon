require 'rails_helper'

RSpec.describe HomeFeed, type: :model do
  let(:account) { Fabricate(:account) }

  subject { described_class.new(account) }

  describe '#get' do
    before do
      Fabricate(:status, account: account, id: 1)
      Fabricate(:status, account: account, id: 2)
      Fabricate(:status, account: account, id: 3)
      Fabricate(:status, account: account, id: 10)
    end

    context 'when feed is generated' do
      before do
        Redis.current.zadd(
          FeedManager.instance.key(:home, account.id),
          [[4, 4], [3, 3], [2, 2], [1, 1]]
        )
      end

      it 'gets statuses with ids in the range from redis with database' do
        results = subject.get(3)

        expect(results.map(&:id)).to eq [3, 2, 1]
        expect(results.first.attributes.keys).to eq %w(id updated_at)
      end

      it 'with min_id present' do
        results = subject.get(3, nil, nil, 0)
        expect(results.map(&:id)).to eq [3, 2, 1]
      end
    end

    context 'when feed is being generated' do
      before do
        Redis.current.set("account:#{account.id}:regeneration", true)
      end

      it 'returns from database' do
        results = subject.get(3)

        expect(results.map(&:id)).to eq [10, 3, 2]
      end

      it 'with min_id present' do
        results = subject.get(3, nil, nil, 0)
        expect(results.map(&:id)).to eq [3, 2, 1]
      end
    end
  end
end
