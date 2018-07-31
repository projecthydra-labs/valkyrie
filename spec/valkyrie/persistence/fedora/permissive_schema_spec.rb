# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Valkyrie::Persistence::Fedora::PermissiveSchema do
  describe ".references" do
    it "returns the expected temporary URI" do
      expect(described_class.references).to eq RDF::URI("http://example.com/predicate/references")
    end
  end

  describe ".alternate_ids" do
    it "returns the expected temporary URI" do
      expect(described_class.alternate_ids).to eq RDF::URI("http://example.com/predicate/alternate_ids")
    end
  end

  describe ".member_ids" do
    it "returns the expected temporary URI" do
      expect(described_class.member_ids).to eq RDF::URI("http://example.com/predicate/member_ids")
    end
  end
end
