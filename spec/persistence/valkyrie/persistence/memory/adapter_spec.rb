# frozen_string_literal: true
require 'rails_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::Memory::Adapter do
  let(:adapter) { described_class.new }
  it_behaves_like "a Valkyrie::Adapter"
end
