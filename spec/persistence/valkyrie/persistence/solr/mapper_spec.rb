# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Penguin::Persistence::Solr::Mapper do
  subject { described_class.new(resource) }
  let(:resource) { instance_double(Book, id: "1", title: ["Test"], author: ["Author"], attributes: { title: nil, author: nil, id: nil }) }

  describe "#to_h" do
    it "maps all available properties to the solr record" do
      expect(subject.to_h).to eq(
        id: resource.id,
        title_ssim: ["Test"],
        title_tesim: ["Test"],
        author_ssim: ["Author"],
        author_tesim: ["Author"]
      )
    end
  end
end
