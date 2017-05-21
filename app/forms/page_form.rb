# frozen_string_literal: true
class PageForm < Valkyrie::Form
  validate :title_not_empty
  self.fields = Page.fields - [:id]
  property :viewing_hint, multiple: false
  property :title, required: true

  private

    def title_not_empty
      return unless title && title.is_a?(Array) && title.select(&:present?).blank?
      errors.add(:title, "can not be blank.")
    end
end
