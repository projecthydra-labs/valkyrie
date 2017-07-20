# frozen_string_literal: true
class ChangeSetPersister
  attr_reader :metadata_adapter, :storage_adapter
  delegate :persister, :query_service, :file_node_persister, to: :metadata_adapter
  def initialize(metadata_adapter:, storage_adapter:)
    @metadata_adapter = metadata_adapter
    @storage_adapter = storage_adapter
  end

  def save(change_set:)
    before_save(change_set: change_set)
    persister.save(model: change_set.model).tap do |output|
      after_save(change_set: change_set, updated_model: output)
    end
  end

  def delete(change_set:)
    before_delete(change_set: change_set)
    persister.delete(model: change_set.model)
  end

  def save_all(change_sets:)
    change_sets.map do |change_set|
      save(change_set: change_set)
    end
  end

  private

    def before_save(change_set:)
      create_files(change_set: change_set)
    end

    def after_save(change_set:, updated_model:)
      append(append_id: change_set.append_id, updated_model: updated_model) if change_set.append_id
    end

    def append(append_id:, updated_model:)
      parent_obj = query_service.find_by(id: append_id)
      parent_obj.member_ids = parent_obj.member_ids + [updated_model.id]
      persister.save(model: parent_obj)
    end

    def create_files(change_set:)
      appender = FileAppender.new(storage_adapter: storage_adapter,
                                  persister: persister,
                                  files: files(change_set: change_set),
                                  file_node_persister: file_node_persister)
      appender.append_to(change_set.model)
    end

    def files(change_set:)
      change_set.try(:files) || []
    end

    def before_delete(change_set:)
      parents = query_service.find_parents(model: change_set.model)
      parents.each do |parent|
        parent.member_ids -= [change_set.id]
        persister.save(model: parent)
      end
    end
end
