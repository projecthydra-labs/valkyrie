# frozen_string_literal: true
require 'rails_helper'
require 'valkyrie/specs/shared_specs'
include ActionDispatch::TestProcess

RSpec.describe ImageDerivativeService do
  it_behaves_like "a Valkyrie::DerivativeService"
  let(:derivative_service) { ImageDerivativeService::Factory.new(adapter, repository) }
  let(:adapter) { Valkyrie::Adapter.find(:indexing_persister) }
  let(:repository) { Valkyrie.config.storage_adapter }
  let(:persister) { adapter.persister }
  let(:query_service) { adapter.query_service }
  let(:file) { fixture_file_upload('files/example.tif', 'image/tiff') }
  let(:book) do
    persister.save(model: book_form)
  end
  let(:book_form) do
    BookForm.new(Book.new).tap do |form|
      form.files = [file]
    end
  end
  let(:book_members) { query_service.find_members(model: book) }
  let(:valid_file_set) { book_members.first }

  it "creates a thumbnail and attaches it to the fileset" do
    derivative_service.new(valid_file_set).create_derivatives

    reloaded = query_service.find_by(id: valid_file_set.id)
    members = query_service.find_members(model: reloaded)
    derivative = members.find { |x| x.use.include?("derivative") }

    expect(derivative).to be_present
    derivative_file = Valkyrie::FileRepository.find_by(id: derivative.file_identifiers.first)
    image = MiniMagick::Image.open(derivative_file.io.path)
    expect(image.width).to eq 105
    expect(image.height).to eq 150
  end
end
