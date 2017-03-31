# frozen_string_literal: true
RSpec.shared_examples 'a Penguin query provider' do
  before do
    raise 'adapter must be set with `let(:adapter)`' unless
      defined? adapter
    raise 'resource_class must be set with `let(:resource_class)`' unless
      defined? resource_class
  end
  let(:query_service) { QueryService.new(adapter: adapter) }
  let(:persister) { Persister.new(adapter: adapter) }

  describe ".find_all" do
    it "returns all created resources" do
      resource1 = persister.save(resource_class.new)
      resource2 = persister.save(resource_class.new)

      expect(query_service.find_all.map(&:id)).to contain_exactly resource1.id, resource2.id
    end
  end

  describe ".find_by_id" do
    it "returns a resource by id" do
      resource = persister.save(resource_class.new)

      expect(query_service.find_by_id(resource.id).id).to eq resource.id
    end
    it "returns a ::Persister::ObjectNotFoundError for a non-found ID" do
      expect { query_service.find_by_id("123123123") }.to raise_error ::Persister::ObjectNotFoundError
    end
  end

  describe ".find_members" do
    it "returns all a resource's members in order" do
      child1 = persister.save(resource_class.new)
      child2 = persister.save(resource_class.new)
      parent = persister.save(resource_class.new(member_ids: [child2.id, child1.id]))

      expect(query_service.find_members(parent).map(&:id).to_a).to eq [child2.id, child1.id]
    end
  end
end
