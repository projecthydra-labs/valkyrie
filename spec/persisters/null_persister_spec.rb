# frozen_string_literal: true
require 'rails_helper'

RSpec.describe NullPersister do
  let(:book) { instance_double(Book) }
  describe "#persist" do
    it "passes the model back" do
      expect(described_class.new(model: book).persist).to eq book
    end
    it "can take other arguments but disregards them" do
      expect(described_class.new(model: book, persister: "yo").persist).to eq book
    end
  end

  describe ".save" do
    it "returns the given object" do
      expect(described_class.save(book)).to eq book
    end
  end
end
