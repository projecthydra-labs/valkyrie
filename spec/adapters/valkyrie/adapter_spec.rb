# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Penguin::Adapter do
  describe ".register" do
    let(:adapter) { instance_double(described_class) }
    it "registers an adapter to a short name" do
      described_class.register adapter, :test_adapter

      expect(described_class.find(:test_adapter)).to eq adapter
    end
  end
end
